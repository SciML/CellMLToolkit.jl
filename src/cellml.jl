const cellml_ns = "http://www.cellml.org/cellml/1.0#"
const mathml_ns = "http://www.w3.org/1998/Math/MathML"

create_var(x) = Num(Variable(Symbol(x))).val
create_var(x, iv) = Num(Sym{FnType{Tuple{Real}}}(Symbol(x))(Variable(Symbol(iv)))).val
create_param(x) = Num(Sym{ModelingToolkit.Parameter{Real}}(Symbol(x))).val

# list the name of the CellML initialized variables, i.e., state variables
# and parameters with an initial_value tag
function find_initialized_variables(xml)
    return findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns])
end

# list the name of the state variables, i.e., variables that occur on the left
# hand side of an assignment
function find_state_names(xml)
    # nodes = findall("//x:math//x:eq/following-sibling::x:apply[1]/x:ci", root(xml), ["x"=>mathml_ns])
    # vars = nodecontent.(nodes)
    nodes = findall("//x:math//x:apply/x:diff", root(xml), ["x"=>mathml_ns])
    vars = [nodecontent(lastelement(parentnode(n))) for n in nodes]
    return unique(vars)
end

# find the unique independent variable
function find_iv(xml)
    nodes = findall("//x:math//x:bvar/x:ci", root(xml), ["x"=>mathml_ns])
    ivs = unique(nodecontent.(nodes))
    if length(ivs) > 1
        error("Only one independent variable (iv) is acceptable")
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
    # nodes = findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns])
    # vars = map(x -> x["name"], nodes)
    # states = find_state_names(xml)
    # Dict(create_var(x) => x ∈ states ? create_var(x, iv) : create_param(x) for x in vars)
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

function flatten_equations(eqs)
    eqs, alg = split_equations(eqs)
    s = Dict(eq.lhs => eq.rhs for eq in alg)

    # alg = [eq.lhs ~ substitute(eq.rhs, s) for eq in alg]
    for (i,eq) in enumerate(alg)
        eq = eq.lhs ~ substitute(eq.rhs, s)
        s[eq.lhs] = eq.rhs
        alg[i] = eq
    end

    # s = Dict(a.lhs => a.rhs for a in alg)
    eqs = [eq.lhs ~ substitute(eq.rhs, s) for eq in eqs]

    return eqs
end

function process_cellml_xml(xml::EzXML.Document)
    ml = extract_mathml(xml)
    eqs = vcat(parse_node.(ml)...)
    eqs = flatten_equations(eqs)
    iv = find_iv(xml)
    s = list_substitution(xml, iv)
    eqs = [substitute(eq.lhs, s) ~ substitute(eq.rhs, s) for eq in eqs]
    sys = ODESystem(eqs, create_var(iv))
    return sys
end

function test_cellml(xml::EzXML.Document)
    ml = extract_mathml(xml)
    iv = find_iv(xml)

    for (i, m) in enumerate(ml)
        println(i, "  ****************************************")
        eqs = parse_node(m)
        for eq in eqs
            println(eq)
            #eq = flatten_equations(eq)
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
