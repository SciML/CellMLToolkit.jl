using EzXML, Symbolics, Statistics
using Symbolics: FnType, Sym


include("parse.jl")
include("utils.jl")

const cellml_ns = "http://www.cellml.org/cellml/1.0#"
const mathml_ns = "http://www.w3.org/1998/Math/MathML"

create_sym(x) = Num(Variable(Symbol(x)))
create_sym(x, iv) = Num(Sym{FnType{Tuple{Real}}}(Symbol(x))(Variable(Symbol(iv))))

# list the name of the CellML variables (state variables + parameters)
function list_variables(xml)
    nodes = findall("//x:variable/@name", root(xml), ["x"=>cellml_ns])
    vars = nodecontent.(nodes)
    return unique(vars)
end

# list the name of the state variables, i.e., variables that occur on the left
# hand side of an assignment
function list_state_variables(xml)
    nodes = findall("//x:math//x:eq/following-sibling::x:apply[1]/x:ci", root(xml), ["x"=>mathml_ns])
    vars = nodecontent.(nodes)
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

# list the name of all the parameters
function list_parameters(xml)
    vars = list_variables(xml)
    states = list_state_variables(xml)
    iv = find_iv(xml)
    params = filter(x -> x ∉ states && x != iv, vars)
    return params
end

# create_sym(x::AbstractString) = Num(Variable(Symbol(x)))
# create_sym(x::AbstractString, iv::AbstractString) = Sym{FnType{Tuple{Real}}}(Symbol(x))(Symbol(iv))

function list_p(xml)
    vars = findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns])
    params = list_parameters(xml)
    p = map(x -> (create_sym(x["name"]) => x["initial_value"]), filter(x -> x["name"] ∈ params, vars))
    return p
end

function list_u0(xml)
    vars = findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns])
    states = list_state_variables(xml)
    iv = find_iv(xml)
    # u0 = map(x -> (create_sym(x["name"], iv) => x["initial_value"]), filter(x -> x["name"] ∈ states, vars))
    u0 = map(x -> (create_sym(x["name"]) => x["initial_value"]), filter(x -> x["name"] ∈ states, vars))
    return u0
end

function list_substitution(xml)
    vars = findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns])
    states = list_state_variables(xml)
    iv = find_iv(xml)
    u0 = map(x -> (create_sym(x["name"]) => create_sym(x["name"], iv)), filter(x -> x["name"] ∈ states, vars))
    return u0
end
