const cellml_ns(xml) = namespace(root(xml))
const mathml_ns = "http://www.w3.org/1998/Math/MathML"

create_var(x) = Num(Variable(Symbol(x))).val
create_var(x, iv) = Num(Sym{FnType{Tuple{Real}}}(Symbol(x))(Variable(Symbol(iv)))).val
create_param(x) = Num(Sym{ModelingToolkit.Parameter{Real}}(Symbol(x))).val

# list the name of the CellML initialized variables, i.e., state variables
# and parameters with an initial_value tag
function find_initialized_variables(xml)
    return findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns(xml)])
end

# list the name of the state variables, i.e., variables that occur on the left
# hand side of an assignment
function find_state_names(xml)
    # nodes = findall("//x:math//x:eq/following-sibling::x:apply[1]/x:ci", root(xml), ["x"=>mathml_ns])
    # vars = nodecontent.(nodes)
    nodes = findall("//x:math//x:apply/x:diff", root(xml), ["x"=>mathml_ns])
    vars = [strip(nodecontent(lastelement(parentnode(n)))) for n in nodes]
    return unique(vars)
end

# find the unique independent variable
function find_iv(xml)
    nodes = findall("//x:math//x:bvar/x:ci", root(xml), ["x"=>mathml_ns])
    ivs = unique(strip.(nodecontent.(nodes)))
    if length(ivs) > 1
        error("Only one independent variable (iv) is acceptable")
    elseif length(ivs) == 0
        error("Deficient XML Model! No ODE is defined.")
    end
    return ivs[1]
end

function list_params(xml, iv=find_iv(xml))
    vars = find_initialized_variables(xml)
    states = find_state_names(xml)
    p = filter(x -> x["name"] ∉ states && x["name"] != iv, vars)
    map(x -> (create_param(x["name"]) => parse(Float64, x["initial_value"])), p)
end

function list_initial_conditions(xml, iv=find_iv(xml))
    vars = find_initialized_variables(xml)
    states = find_state_names(xml)
    u0 = filter(x -> x["name"] ∈ states, vars)
    map(x -> (create_var(x["name"], iv) => parse(Float64, x["initial_value"])), u0)
end

function list_states(xml)
    states = find_state_names(xml)
    map(x -> (create_param(x)), states)
end

function list_substitution(xml, iv=find_iv(xml))
    states = first.(list_initial_conditions(xml, iv))
    params = first.(list_params(xml, iv))
    u0_dict = Dict(create_var(operation(x).name) => x for x in states)
    p_dict = Dict(create_var(x.name) => x for x in params)
    union(u0_dict, p_dict)
end

function split_equations(eqs)
    alg = filter(eq -> eq.lhs isa Sym, eqs)
    eqs = filter(!(eq -> eq.lhs isa Sym), eqs)
    return eqs, alg
end

function left_hand_side(eqs, alg)
    lq = [arguments(eq.lhs)[1] for eq in eqs]
    la = [eq.lhs for eq in alg]
    union(lq, la)
end

function connections(xml, eqs, alg)
    a = []
    p = map(x -> string(first(x)), list_params(xml))
    l = string.(left_hand_side(eqs, alg))
    maps = findall("//x:map_variables", root(xml), ["x"=>cellml_ns(xml)])
    for m in maps
        var1 = m["variable_1"]
        var2 = m["variable_2"]
        if var1 != var2
            if var1 ∈ l && var2 ∉ l
                push!(a, create_var(var2) ~ create_var(var1))
                @info "accept connection: $var2 ~ $var1"
            elseif var1 ∉ l && var2 ∈ l
                push!(a, create_var(var1) ~ create_var(var2))
                @info "accept connection: $var1 ~ $var2"
            elseif var1 ∈ l && var2 ∈ l
                @warn "frustrated connection: $var1 ~ $var2"
            else
                if var1 ∈ p
                    push!(a, create_var(var2) ~ create_var(var1))
                    @info "accept connection: $var2 ~ param($var1)"
                elseif var2 ∈ p
                    push!(a, create_var(var1) ~ create_var(var2))
                    @info "accept connection: $var1 ~ param($var2)"
                else
                    @warn "dangling connection: $var1 ~ $var2"
                end
            end
        end
    end
    return a
end

function flatten_equations(xml, eqs)
    eqs, alg = split_equations(eqs)

    a = connections(xml, eqs, alg)
    append!(alg, a)

    s = Dict{Sym{Real,Nothing}, Any}(eq.lhs => eq.rhs for eq in alg)
    # Any is needed to take care of possible Float values

    b = true
    while b
        b = false
        for (i,eq) in enumerate(alg)
            eq = (eq.lhs ~ substitute(eq.rhs, s))
            b = b || !isequal(eq, alg[i])            
            s[eq.lhs] = eq.rhs
            alg[i] = eq
        end
    end

    eqs = [eq.lhs ~ substitute(eq.rhs, s) for eq in eqs]
    return eqs
end

function process_cellml_xml(xml::EzXML.Document)
    ml = extract_mathml(xml)
    eqs = vcat(parse_node.(ml)...)
    eqs = flatten_equations(xml, eqs)
    # append!(eqs, connections(xml, split_equations(eqs)...))
    iv = find_iv(xml)
    s = list_substitution(xml, iv)
    eqs = [substitute(eq.lhs, s) ~ substitute(eq.rhs, s) for eq in eqs]
    sys = ODESystem(eqs, create_var(iv))
    # sys = structural_simplify(sys)
    return sys
end

function find_component_names(xml::EzXML.Document)
    c = findall("//x:component", root(xml), ["x"=>cellml_ns(xml)])
    map(x -> x["name"], c)
end

function process_components(xml::EzXML.Document)
    names = find_component_names(xml)

    cs = []
    for c in names
        sys = process_component(xml, c)
        if sys != nothing
            push!(cs, sys)
        end
    end

    return cs
end

function process_component(xml::EzXML.Document, component)
    math = findfirst("//x:component[@name='$component']/y:math", root(xml), ["x"=>cellml_ns(xml), "y"=>mathml_ns])
    if math == nothing
        return nothing
    end
    eqs = parse_node(math)
    # eqs = flatten_equations(eqs)
    iv = find_iv(xml)
    s = list_substitution(xml, iv)
    eqs = [substitute(eq.lhs, s) ~ substitute(eq.rhs, s) for eq in eqs]
    println(eqs)
    sys = ODESystem(eqs, create_var(iv); name=Symbol(component))
    return sys
end

##############################################################################

function test_cellml(xml::EzXML.Document)
    ml = extract_mathml(xml)
    iv = find_iv(xml)

    for (i, m) in enumerate(ml)
        println(i, "  ****************************************")
        eqs = parse_node(m)
        for eq in eqs
            println(eq)
            eq = flatten_equations(eq)
            s = list_substitution(xml, iv)
            eq = substitute(eq.lhs, s) ~ substitute(eq.rhs, s)
            try
                sys = ODESystem(eq)
            catch e
            end
        end
    end
end

# This is the fall-back option in case of breaking changes in
# ModelingToolkit and/or SymbolicUtils
function eval_string(xml::EzXML.Document)
    iv = find_iv(xml)
    p = list_params(xml, iv)
    u0 = list_initial_conditions(xml, iv)

    states = [string(operation(first(x)).name) for x in u0]
    params = [string(first(x).name) for x in p]

    s = "@parameters " * join(params, " ") * " " * iv * ";"
    s *= "iv_global = " * iv * ";"

    d = "(" * iv * ") "
    s *= "@variables " * join(states, d) * d * ";"

    ml = extract_mathml(xml)
    eqs = vcat(parse_node.(ml)...)
    s *= "eqs = " * string(eqs) * ";"

    s *= "p_global = [" * join(string.(p), ",") *"];"
    s *= "u0_global = [" * join([string(operation(first(x)).name) * " => " * string(last(x)) for x in u0], ", ") * "];"

    return s
end
