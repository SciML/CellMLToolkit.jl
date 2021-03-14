using EzXML, Symbolics, Statistics
using Symbolics: FnType, Sym

include("parse.jl")
include("utils.jl")

const cellml_ns = "http://www.cellml.org/cellml/1.0#"
const mathml_ns = "http://www.w3.org/1998/Math/MathML"

create_var(x) = Num(Variable(Symbol(x))).val
create_var(x, iv) = Num(Sym{FnType{Tuple{Real}}}(Symbol(x))(Variable(Symbol(iv)))).val
create_param(x) = Num(Sym{ModelingToolkit.Parameter{Real}}(Symbol(x))).val

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

# create_var(x::AbstractString) = Num(Variable(Symbol(x)))
# create_var(x::AbstractString, iv::AbstractString) = Sym{FnType{Tuple{Real}}}(Symbol(x))(Symbol(iv))

function list_p(xml)
    vars = findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns])
    params = list_parameters(xml)
    p = map(x -> (create_param(x["name"]) => parse(Float64, x["initial_value"])),
            filter(x -> x["name"] ∈ params, vars))
    return p
end

function list_u0(xml, iv=find_iv(xml))
    vars = findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns])
    states = list_state_variables(xml)
    u0 = map(x -> (create_var(x["name"], iv) => parse(Float64, x["initial_value"])),
             filter(x -> x["name"] ∈ states, vars))
    return u0
end

function list_substitution(xml, iv=find_iv(xml))
    nodes = findall("//x:variable[@initial_value]", root(xml), ["x"=>cellml_ns])
    vars = map(x -> x["name"], nodes)
    states = list_state_variables(xml)
    Dict(create_var(x) => x ∈ states ? create_var(x, iv) : create_param(x) for x in vars)
end

function generate_prob(xml, eqs, tspan)
    iv = find_iv(xml)
    s = list_substitution(xml, iv)
    eqs = [substitute(eq.lhs, s) ~ substitute(eq.rhs, s) for eq in eqs]
    sys = ODESystem(eqs)
    p = list_p(xml)
    u0 = list_u0(xml, iv)
    prob = ODEProblem(sys, u0, tspan, p)
    return prob
end

# function generate_eval_string(xml, eqs)
#     iv = find_iv(xml)
#     params = "@parameters " * join(list_parameters(xml), " ") * " " * iv
#     l = ["$x($iv)" for x in list_state_variables(xml)]
#     vars = "@variables " * join(l, " ")
#
#     return params * ";" * vars * ";sys = ODESystem(" * string(eqs) * ");"
# end

using DifferentialEquations, Plots

function test()
    xml = readxml("models/lorenz.cellml.xml")
    ml = extract_mathml(xml)
    eqs = parse_node(ml[1])
    prob = generate_prob(xml, eqs, (0, 100.0))
    sol = solve(prob)
    x = Array(sol)
    plot(x[1,:], x[3,:])
end
