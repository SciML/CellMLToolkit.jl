const cellml_ns(xml) = namespace(root(xml))
const mathml_ns = "http://www.w3.org/1998/Math/MathML"

create_var(x) = Num(Variable(Symbol(x))).val
# create_var(x, iv) = Num(Sym{FnType{Tuple{Real}}}(Symbol(x))(Variable(Symbol(iv)))).val
create_var(x, iv) = Num(Variable{Symbolics.FnType{Tuple{Any},Real}}(Symbol(x)))(Variable(Symbol(iv))).val
create_param(x) = Num(Sym{ModelingToolkit.Parameter{Real}}(Symbol(x))).val

global iv_currying = Dict{EzXML.Document, String}()

"""
    find_iv finds the unique independent variable

    Note: We assume iv is stable and use Currying to cache the result.
          However, xml is potentially mutable. Be careful!
"""
function find_iv(xml)
    if haskey(iv_currying, xml)
        return iv_currying[xml]
    end
    nodes = findall("//x:math//x:bvar/x:ci", root(xml), ["x"=>mathml_ns])
    ivs = unique(strip.(nodecontent.(nodes)))
    if length(ivs) > 1
        error("Only one independent variable (iv) is acceptable")
    elseif length(ivs) == 0
        @warn("Deficient XML Model! No ODE is defined.")
    end

    iv = ivs[1]
    iv_currying[xml] = iv
    return iv
end

###############################################################################

# A CellML Variable
struct Var
    comp::Symbol
    var::Symbol
end

to_symbol(x::Symbol) = x
to_symbol(x::AbstractString) = Symbol(x)
to_symbol(x::EzXML.Node) = Symbol(x["name"])

make_var(c, v) = Var(to_symbol(c), to_symbol(v))

names_to_varset(comp, l) = Set([make_var(comp, x) for x in l])

"""
    list_component_lhs returns a set of Var composed of all variables in component
    comp that occur on the left-hand-side of an ODE or algebraic equation
"""
function list_component_lhs(xml::EzXML.Document, comp)
    names_to_varset(comp, list_state_names(xml, comp)) ∪ names_to_varset(comp, find_alg_names(xml, comp))
end

"""
    list_component_lhs returns a set of Var composed of all variables anywhere in
    the xml document that occur on the left-hand-side of an ODE or algebraic equation
"""
list_all_lhs(xml::EzXML.Document) = ∪([list_component_lhs(xml, c) for c in list_components(xml)]...)



global equivalnce_currying = Dict{EzXML.Document, Dict{Var, Set{Var}}}()

"""
    find_equivalence_groups categorizes all the variables in the xml document
    based on the connections into equivalnce groups
    it returns a Dictionary of Var to groups (Set of Vars)
"""
function find_equivalence_groups(xml::EzXML.Document)
    if haskey(equivalnce_currying, xml)
        return equivalnce_currying[xml]
    end
    groups = Dict{Var, Set{Var}}()

    # phase 1: each variable belongs to only one set composed of the variable itself
    for c in list_components(xml)
        for v in get_component_variables(xml, c)
            u = make_var(c, v)
            groups[u] = Set([u])
        end
    end

    # phase 2: equivalence groups (sets) are merged according to the connections
    for k in list_connections(xml)
        c1, c2 = get_connection_components(xml, k)
        for (v1,v2) in get_connection_variables(xml, k)
            u1 = make_var(c1, v1)
            u2 = make_var(c2, v2)
            s = groups[u1] ∪ groups[u2]
            for x in s
                groups[x] = s
            end
        end
    end

    equivalnce_currying[xml] = groups
    return groups
end

"""
    classify_variables divides all the variables in the xml document into
    two categorizes and returns a Dict from Var to Bool:
        true: Var is a left-hand-side variable
        false: Var is not a left-hand-side variable (should be a parameter)
"""
function classify_variables(xml::EzXML.Document)
    groups = find_equivalence_groups(xml)
    lhs = list_all_lhs(xml)
    Dict{Var, Bool}(first(g) => (length(last(g) ∩ lhs) == 1) for g in groups)
end

"""
    translate_connections translates the list of MathML connections to
    a list of ModelingToolkit equations
"""
function translate_connections(xml::EzXML.Document, systems, class)
    a = []
    for k in list_connections(xml)
        c1, c2 = Symbol.(get_connection_components(xml, k))
        sys1 = systems[c1]
        sys2 = systems[c2]
        for w in get_connection_variables(xml, k)
            v1, v2 = Symbol.(w)
            if class[Var(c1,v1)] && class[Var(c2,v2)] && Symbol(sys1.iv) != v1
                var1 = getproperty(sys1, v1)
                var2 = getproperty(sys2, v2)
                push!(a, var1 ~ var2)
            end
        end
    end
    return a
end

"""
    pre_substitution generates the substitution rules to be applied to
    individual systems before structural_simplify merges them together

    it morphes variables and parameters to their correct form for ModelingToolkit
    based on the global CellML xml information
"""
function pre_substitution(xml::EzXML.Document, comp, class)
    iv=find_iv(xml)
    vars = get_component_variables(xml, comp)
    states = [create_var(x) => create_var(x, iv) for x in vars if class[make_var(comp,x)]]
    params = [create_var(x) => create_param(x) for x in vars if !class[make_var(comp,x)]]

    return states ∪ params
end

"""
    post_substitution generates the substitution rules to be applied to
    the merged system after structural_simplify is applied

    if changes the names of the indepedent variable (iv) in each system
    to the global iv name

    TODO: this function assumes the basic iv name is the same among all systems
"""
function post_substitution(xml, systems)
    iv=find_iv(xml)
    ivp = create_var(iv)
    [create_param(string(s) * "₊" * iv) => ivp for s in keys(systems)]
end

##############################################################################

substitute_eqs(eqs, s) = [substitute(eq.lhs, s) ~ substitute(eq.rhs, s) for eq in eqs]

"""
    process_components is the main entry point
    it processes an xml document and returns a merged ODESystem

    use simplify=false only for debugging purposes!
"""
function process_components(xml::EzXML.Document; simplify=true)
    extract_mathml(xml)     # this is called here for the side-effect of disambiguiting equals
    class = classify_variables(xml)
    systems = subsystems(xml, class)
    post_sub = post_substitution(xml, systems)

    sys = ODESystem(
        translate_connections(xml, systems, class),
        create_var(find_iv(xml)),
        systems=collect(values(systems))
    )

    if simplify
        sys = structural_simplify(sys)
        sys = ODESystem(substitute_eqs(sys.eqs, post_sub), sys.iv, sys.states, sys.ps)
    end

    return sys
end

"""
    subsystems returns a Dict of the subsystems (keys are Symbols), each one
    based on one CellML component of the xml document.

    class is the output of classify_variables
"""
function subsystems(xml::EzXML.Document, class)
    Dict{Symbol,ODESystem}(
        Symbol(comp) => process_component(xml, comp, class)
        for comp in list_components(xml)
    )
end

"""
    process_component converts a single CellML component to an ODESystem

    comp in the name of the component
    class is the output of classify_variables
"""
function process_component(xml::EzXML.Document, comp, class)
    math = list_component_math(xml, comp)
    pre_sub = pre_substitution(xml, comp, class)

    if length(math) == 0
        eqs = Equation[]
    else
        eqs = vcat(parse_node.(math)...)
        eqs = substitute_eqs(eqs, pre_sub)
    end

    iv = find_iv(xml)
    ivp = create_var(iv)
    ps = [last(x) for x in values(pre_sub) if last(x) isa Sym && Symbol(first(x)) != Symbol(iv)]
    states = [last(x) for x in values(pre_sub) if !(last(x) isa Sym)]

    ODESystem(eqs, ivp, states, ps; name=Symbol(comp))
end

###############################################################################

function collect_initiated_values(xml::EzXML.Document)
    Dict{Var, Float64}(
        make_var(parentnode(v), v) => Float64(Meta.parse(v["initial_value"]))
        for v in list_initiated_variables(xml)
    )
end

function split_sym(sym)
    # # remove dependency, e.g., (time) from the end
    s = replace(string(sym), r"\([^\)]*\)" => "")
    make_var(split(s, "₊")...)
end

find_sys_p(xml::EzXML.Document, sys) = find_list_value(xml, parameters(sys))
find_sys_u0(xml::EzXML.Document, sys) = find_list_value(xml, states(sys))

function find_list_value(xml::EzXML.Document, a)
    c = collect_initiated_values(xml)
    d = collect(keys(c))
    groups = find_equivalence_groups(xml)

    val = []
    for x in a
        var = [x for x in groups[split_sym(x)] ∩ d][1]
        push!(val, x => c[var])
    end
    return val
end
