const cellml_ns(xml::EzXML.Document) = namespace(root(xml))
const cellml_ns(node::EzXML.Node) = namespace(node)
const mathml_ns = "http://www.w3.org/1998/Math/MathML"

create_var(x) = Num(Variable(Symbol(x))).val
create_var(x, iv) = Num(Variable{Symbolics.FnType{Tuple{Any},Real}}(Symbol(x)))(iv).val
create_param(x) = Num(Sym{ModelingToolkit.Parameter{Real}}(Symbol(x))).val

to_symbol(x::Symbol) = x
to_symbol(x::AbstractString) = Symbol(x)
to_symbol(x::EzXML.Node) = Symbol(x["name"])

"""
    find_iv finds the unique independent variable

    Note: We assume iv is stable and use Currying to cache the result.
          However, doc is potentially mutable. Be careful!
"""
find_iv(doc::Document) = infer_iv(doc)[:β]

function find_iv(doc::Document, comp)
    d = infer_iv(doc)
    haskey(d, to_symbol(comp)) ? d[to_symbol(comp)] : d[:β]
end

get_ivₚ(doc::Document) = create_param(find_iv(doc))

function find_components_iv(doc::Document)
    dv = Dict{Symbol, Symbol}()
    nv = Symbol[]

    for comp in list_components(doc)
        nodes = findall(".//y:math//y:bvar/y:ci", comp, ["y"=>mathml_ns])
        ivs = unique(strip.(nodecontent.(nodes)))
        sym = to_symbol(comp)

        if length(ivs) == 1
            dv[sym] = Symbol(ivs[1])
        elseif length(ivs) == 0
            push!(nv, sym)
        else
            error("component $sym has more than two independent variables")
        end
    end
    return dv, nv
end

@memoize function infer_iv(doc::Document)
    # phase 1, find direct component ivs
    dv, dn = find_components_iv(doc)
    syms = unique(collect(values(dv)))

    if isempty(syms)
        error("no independent variable is inferred")
    end

    if isempty(dn) && length(syms) == 1
        return Dict(:β => syms[1])
    end

    groups = find_equivalence_groups(doc)
    V = ∪([groups[Var(first(x),last(x))] for x in dv]...)
    syms = unique([v.var for v in V])

    if length(syms) == 1
        return Dict(:β => syms[1])
    end

    @warn "more than one name is identified for the independent variable. It is changed to :τ."

    d = Dict(:β => :τ)
    for v in V
        d[v.comp] = v.var
    end
    return d
end

###############################################################################

# A CellML Variable
struct Var
    comp::Symbol
    var::Symbol
end

make_var(c, v) = Var(to_symbol(c), to_symbol(v))

names_to_varset(comp, l) = Set([make_var(comp, x) for x in l])

"""
    list_component_lhs returns a set of Var composed of all variables in component
    comp that occur on the left-hand-side of an ODE or algebraic equation
"""
function list_component_lhs(comp)
    names_to_varset(comp, find_state_names(comp)) ∪ names_to_varset(comp, find_alg_names(comp))
end

"""
    list_component_lhs returns a set of Var composed of all variables anywhere in
    the doc document that occur on the left-hand-side of an ODE or algebraic equation
"""
list_all_lhs(doc::Document) = ∪([list_component_lhs(c) for c in list_components(doc)]...)

"""
    find_equivalence_groups categorizes all the variables in the doc document
    based on the connections into equivalnce groups
    it returns a Dictionary of Var to groups (Set of Vars)
"""
@memoize function find_equivalence_groups(doc::Document)
    groups = Dict{Var, Set{Var}}()

    # phase 1: each variable belongs to only one set composed of the variable itself
    for c in list_components(doc)
        for v in list_component_variables(c)
            u = make_var(c, v)
            groups[u] = Set([u])
        end
    end

    # phase 2: equivalence groups (sets) are merged according to the connections
    for k in list_connections(doc)
        c1, c2 = components_of(get_connection_component(k))
        for (v1,v2) in variables_of.(list_connection_variables(k))
            u1 = make_var(c1, v1)
            u2 = make_var(c2, v2)
            s = groups[u1] ∪ groups[u2]
            for x in s
                groups[x] = s
            end
        end
    end

    return groups
end

"""
    classify_variables divides all the variables in the doc document into
    two categorizes and returns a Dict from Var to Bool:
        true: Var is a left-hand-side variable
        false: Var is not a left-hand-side variable (should be a parameter)
"""
@memoize function classify_variables(doc::Document)
    groups = find_equivalence_groups(doc)
    lhs = list_all_lhs(doc)
    Dict{Var, Bool}(first(g) => (length(last(g) ∩ lhs) == 1) for g in groups)
end

"""
    translate_connections translates the list of MathML connections to
    a list of ModelingToolkit equations
"""
function translate_connections(doc::Document, systems, class)
    a = []
    for k in list_connections(doc)
        c1, c2 = Symbol.(components_of(get_connection_component(k)))
        sys1 = systems[c1]
        sys2 = systems[c2]
        for w in variables_of.(list_connection_variables(k))
            v1, v2 = Symbol.(w)
            if class[make_var(c1,v1)] && class[make_var(c2,v2)] && Symbol(sys1.iv) != v1
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
    based on the global CellML doc information
"""
function pre_substitution(doc::Document, comp, class)
    ivₚ = get_ivₚ(doc)
    ivₘ = find_iv(doc, comp)

    vars = to_symbol.(list_component_variables(comp))

    states = [create_var(x) => create_var(x, ivₚ) for x in vars if class[make_var(comp,x)]]
    params = [create_var(x) => create_param(x) for x in vars if !class[make_var(comp,x)] && x != ivₘ]
    ivsub =  [create_var(ivₘ) => ivₚ]

    return states ∪ params ∪ ivsub
end

function remove_rhs_diff(eqs)
    [eq.lhs => eq.rhs for eq in eqs if operation(eq.lhs) isa Differential]
end

"""
    post_substitution generates the substitution rules to be applied to
    the merged system after structural_simplify is applied

    if changes the names of the indepedent variable (iv) in each system
    to the global iv name

    TODO: this function assumes the basic iv name is the same among all systems
"""
function post_substitution(doc, systems)
    iv = find_iv(doc)
    ivₚ = get_ivₚ(doc)
    [create_param(string(s) * "₊" * string(iv)) => ivₚ for s in keys(systems)]
end

##############################################################################

substitute_eqs(eqs, s) = [substitute(eq.lhs, s) ~ substitute(eq.rhs, s) for eq in eqs]

"""
    process_components is the main entry point
    it processes an doc document and returns a merged ODESystem

    use simplify=false only for debugging purposes!
"""
function process_components(doc::Document; simplify=true)
    extract_mathml(doc.xmls[1])     # this is called here for the side-effect of disambiguiting equals
    infer_iv(doc)

    class = classify_variables(doc)
    systems = subsystems(doc, class)
    post_sub = post_substitution(doc, systems)

    sys = ODESystem(
        translate_connections(doc, systems, class),
        get_ivₚ(doc),
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
    based on one CellML component of the doc document.

    class is the output of classify_variables
"""
function subsystems(doc::Document, class)
    Dict{Symbol,ODESystem}(
        to_symbol(comp) => process_component(doc, comp, class)
        for comp in list_components(doc)
    )
end

function simplify_systems(systems)
    for x in systems
        sys = last(x)
        print("simplifying $(sys.name)")
        try
            sys = structural_simplify(sys)
            k = max(1, 50-length(string(sys.name)))
            printstyled(repeat(" ", k) * "OK!"; color=:green)
            println()
        catch e
            println(e)
        end

    end
end

"""
    process_component converts a single CellML component to an ODESystem

    comp in the name of the component
    class is the output of classify_variables
"""
function process_component(doc::Document, comp, class)
    math = list_component_math(comp)
    pre_sub = pre_substitution(doc, comp, class)

    if length(math) == 0
        eqs = Equation[]
    else
        eqs = vcat(parse_node.(math)...)
        eqs = substitute_eqs(eqs, pre_sub)
        sub_rhs = remove_rhs_diff(eqs)
        eqs = [eq.lhs ~ substitute(eq.rhs, sub_rhs) for eq in eqs]
    end

    ivₚ = get_ivₚ(doc)
    ps = [last(x) for x in values(pre_sub) if last(x) isa Sym && last(x) != ivₚ]
    states = [last(x) for x in values(pre_sub) if !(last(x) isa Sym)]

    ODESystem(eqs, ivₚ, states, ps; name=to_symbol(comp))
end

###############################################################################

function collect_initiated_values(doc::Document)
    Dict{Var, Float64}(
        make_var(parentnode(v), v) => Float64(Meta.parse(v["initial_value"]))
        for v in list_initiated_variables(doc)
    )
end

function split_sym(sym)
    # # remove dependency, e.g., (time) from the end
    s = replace(string(sym), r"\([^\)]*\)" => "")
    make_var(split(s, "₊")...)
end

find_sys_p(doc::Document, sys) = find_list_value(doc, parameters(sys))
find_sys_u0(doc::Document, sys) = find_list_value(doc, states(sys))

function find_list_value(doc::Document, a)
    c = collect_initiated_values(doc)
    iv = find_iv(doc)

    d = collect(keys(c))
    groups = find_equivalence_groups(doc)

    val = []
    for x in a
        var = [x for x in groups[split_sym(x)] ∩ d]
        if length(var) == 0
            error("value of $x in not found")
        end
        push!(val, x => c[var[1]])

    end
    return val
end
