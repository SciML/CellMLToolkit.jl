module CellMLToolkit

export CellModel, ODEProblem
export load_cellml, cellml_to_sys
export parse_file, process_doc
export find_adjacency_matrix, find_V
export list_params, list_initial_conditions, list_states, update_list!

using LightXML
using ModelingToolkit
using ModelingToolkit: Symbolic, operation, FnType, arguments

import Base.floor, Base.ceil

const T = Float64

# The Heavide function
𝐻(x) = (x >= zero(x) ? one(x) : zero(x))    # 1 / (1 + exp(-10000*x))
ModelingToolkit.@register 𝐻(x)
const σ = T(1e-4)
ModelingToolkit.derivative(::typeof(𝐻), args::NTuple{1,Any}, ::Val{1}) = 1/(sqrt(2π)*σ)*exp(-args[1]^2/(2σ)^2)  # Dirac δ

ModelingToolkit.@register floor(x)
ModelingToolkit.@register ceil(x)
ModelingToolkit.derivative(::typeof(floor), args::NTuple{1,Any}, ::Val{1}) = zero(args[1])
ModelingToolkit.derivative(::typeof(ceil), args::NTuple{1,Any}, ::Val{1}) = zero(args[1])

# children(c) = collect(child_elements(c))
# first_child(c) = first(child_elements(c))

parent = Dict{XMLElement, XMLElement}()

function children(e)
    l = collect(child_elements(e))
    for c in l
        parent[c] = e
    end
    return l
end

function first_child(e)
    c = first(child_elements(e))
    parent[c] = e
    return c
end

function print_history(e)
    println("XML context")
    level = 1
    while haskey(parent, e) && level < 3
        println(level, ": ----------------------------------------------")
        println(e)
        e = parent[e]
        level += 1
    end
end

function parse_error(e, msg)
    print_history(e)
    error(msg)
end

#############################################################################

mutable struct CellModel
    vars::Dict   # the list of model variables
    inits::Dict{String, T}          # the initialization list
    eqs::Array{Equation}            # the list of ODE equations
    alg::Array{Equation}            # the algebraic equations
    iv   # the independent variable
    units::Dict  # the variable units

    function CellModel()
        return new(
            Dict(),
            Dict{String,T}(),
            Equation[],
            Equation[],
            nothing,
            Dict()
        )
    end
end

CellModel(doc::XMLDocument; dependency=true) = process_doc(doc; dependency=dependency)
CellModel(s::AbstractString; dependency=true) = process_doc(parse_file(s); dependency=dependency)

"""
    load_cellml(data; dependency=true, kwargs...) 

where data is XMLDocument or a path. returns ODESystem.
Kwargs are passed to ODESystem constructor, for use with `@named`
"""
function load_cellml end

load_cellml(doc::XMLDocument; dependency=true, kwargs...) = cellml_to_sys(CellModel(doc; dependency=dependency); kwargs...)
load_cellml(s::AbstractString; dependency=true, kwargs...) = cellml_to_sys(CellModel(s; dependency=dependency); kwargs...)

"""
    cellml_to_sys constructs an ODESystem from a CellModel
"""
function cellml_to_sys(ml::CellModel;
        jac=false, level=1, p=list_params(ml), u0=list_initial_conditions(ml), kwargs...)
    eqs, vs = flat_equations(ml; level=level)
    sys = ODESystem(eqs, ml.iv, vs, p; default_u0=u0, kwargs...)
    return sys
end

########################### Basic Utility Functions ##########################

function get_var(ml::CellModel, tag)
    if haskey(ml.vars, tag)
        return ml.vars[tag]
    else
        v = Variable(Symbol(tag))
        ml.vars[tag] = v
        return v
    end
end

function list_states(ml::CellModel)
    states = Set()
    for eq in ml.eqs
        if operation(eq.lhs) isa Sym
            push!(states, eq.lhs)
        else
            push!(states, arguments(eq.lhs)[1])
        end
    end
    return states
end

################### Utility Functions for Adjacency Matrix ####################

function find_dependency_list(u)
    if u isa Sym
        v = Set([u])
    else
        v = Set()
        for w in arguments(u)
            if w isa Symbolic
                v = union(v, find_dependency_list(w))
            end
        end
    end
    return v
end

function find_adjacency_matrix(ml::CellModel; level=1)
    eqs, vs = flat_equations(ml; level=level)
    n = length(vs)
    a = zeros(Int, (n,n))

    for i = 1:n
        l = find_dependency_list(eqs[i].rhs)
        for j = 1:n
            if vs[j] ∈ l
                a[j,i] = 1
            end
        end
    end

    return a, vs
end

"""
    A heuristic algorithm to find the state variable corresponding to
    the transmembrane potential: it should occured on the dependency
    list more than any other state variable
"""
function find_V(ml::CellModel)
    a, vs = find_adjacency_matrix(ml)
    u = vec(sum(a, dims=1))
    V = vs[findmax(u)[2]]
    return V
end

################################# Tree Traversal ##############################

"""
    the entry point
"""
function process_doc(doc; dependency=true)
    ml = CellModel()
    empty!(parent)

    for e in get_elements_by_tagname(root(doc), "component")
        process_component(ml, e)
    end

    if dependency
        states = collect(list_states(ml))
        map(v -> Sym{FnType{Tuple{Real},Real}}(nameof(v))(ml.iv), states)
    end

    return ml
end

function process_component(ml::CellModel, e)
    name = attribute(e, "name")

    for c in get_elements_by_tagname(e, "variable")
        process_variable(ml, c)
    end

    for c in get_elements_by_tagname(e, "math")
        process_math(ml, c)
    end
end

function process_variable(ml::CellModel, e)
    s = strip(attribute(e, "name"))

    if has_attribute(e, "public_interface")
        u = strip(attribute(e, "units"))
        v = get_var(ml, s)
        ml.units[v] = u
    end

    if has_attribute(e, "initial_value") && !haskey(ml.inits, s)
        val = T(parse(Float64, attribute(e, "initial_value")))
        ml.inits[s] = val
    end
end

function process_math(ml::CellModel, e)
    for c in get_elements_by_tagname(e, "apply")
        process_math_element(ml, c)
    end
end

function process_math_element(ml::CellModel, e)
    if name(e) != "apply"
        parse_error(e, "a math clause should be a list of applies")
    end

    l = children(e)

    if name(l[1]) != "eq"
        parse_error(e, "a math clause should be an assignment")
    end

    if name(l[2]) == "ci"
        tag = strip(content(l[2]))
        lhs = get_var(ml, tag)
        rhs = convert_term(ml, l[3])
        eq = lhs ~ rhs
        push!(ml.alg, eq)
    elseif name(l[2]) == "apply"
        h = children(l[2])

        if name(h[1]) != "diff"
            parse_error(e, "expected diff")
        end

        if name(h[2]) == "bvar"
            x_tag = strip(content(first_child(h[2])))
        else
            x_tag = strip(content(h[2]))
        end

        y_tag = strip(content(h[3]))
        X = Variable(Symbol(x_tag))
        if ml.iv == nothing
            ml.iv = X
        elseif !isequal(ml.iv, X)
            parse_error(e, "only can define one independent variable")
        end
        Y = get_var(ml, y_tag)
        D = Differential(X)
        lhs = D(Y)
        rhs = convert_term(ml, l[3])
        eq = lhs ~ rhs
        push!(ml.eqs, eq)
    else
        parse_error(e, "expected an arithmetic or differential assignment")
    end
end

function convert_term(ml::CellModel, e)
    s = strip(name(e))

    if s == "apply"
        return convert_apply(ml, e)
    elseif s == "ci"
        tag = strip(content(e))
        return get_var(ml, tag)
    elseif s == "cn"
        return process_cn(e)
    elseif s == "piecewise"
        return convert_piecewise(ml, e)
    elseif s == "bvar"
        parse_error(e, "derivatives are unsupported on the right hand side of equations, please use algebraic equations instead: $e")
    else
        x = convert_math_constants(e)
        if x == nothing
            parse_error(e, "unrecognized term $s: $e")
        end
        return x
    end
end

function convert_apply(ml::CellModel, e)
    n = length(children(e))

    if n == 2
        return convert_unary_apply(ml, e)
    elseif n == 3
        return convert_binary_apply(ml, e)
    else
        return convert_nary_apply(ml, e)
    end
end

function convert_unary_apply(ml::CellModel, e)
    l = children(e)
    s = name(l[1])
    t = convert_term(ml, l[2])

    if s == "plus"
        return t
    elseif s == "minus"
        return -t
    elseif s == "ln"
        return log(t)
    elseif s == "log"
        return log10(t)
    elseif s == "sin"
        return sin(t)
    elseif s == "cos"
        return cos(t)
    elseif s == "tan"
        return tan(t)
    elseif s == "arcsin"
        return asin(t)
    elseif s == "arccos"
        return acos(t)
    elseif s == "arctan"
        return atan(t)
    elseif s == "sinh"
        return sinh(t)
    elseif s == "cosh"
        return cosh(t)
    elseif s == "tanh"
        return tanh(t)
    elseif s == "arcsinh"
        return asinh(t)
    elseif s == "arccosh"
        return acosh(t)
    elseif s == "arctanh"
        return atanh(t)
    elseif s == "exp"
        return exp(t)
    elseif s == "root"
        return sqrt(t)
    elseif s == "abs"
        return abs(t)
    elseif s == "floor"
        return floor(t)
    elseif s == "ceiling"
        return ceil(t)
    elseif s == "not"
        return one(t) - t
    else
        parse_error(e, "unrecognized unary operator: $s")
    end
end

function convert_binary_apply(ml::CellModel, e)
    l = children(e)
    s = name(l[1])
    t1 = convert_term(ml, l[2])
    t2 = convert_term(ml, l[3])

    if s == "diff"
        return Differential(t1)(t2)
    end

    if s == "min"
        return min(t1, t2)
    elseif s == "max"
        return max(t1, t2)
    elseif s == "plus"
        return t1 + t2
    elseif s == "minus"
        return t1 - t2
    elseif s == "times"
        return t1 * t2
    elseif s == "divide"
        return t1 / t2
    elseif s == "rem"
        return t1 % t2
    elseif s == "power"
        return t1 ^ t2
    elseif s == "and"
        return t1 * t2
    elseif s == "or"
        return t1 + t2 - t1 * t2
    elseif s == "xor"
        return abs(t1 - t2)
    elseif s == "leq"
        return 𝐻(t2 - t1)
    elseif s == "geq"
        return 𝐻(t1 - t2)
    elseif s == "lt"
        return 𝐻(t2 - t1 - eps(T))
    elseif s == "gt"
        return 𝐻(t1 - t2 - eps(T))
    elseif s == "eq"
        return 𝐻(t1 - t2) * 𝐻(t2 - t1)
    elseif s == "neq"
        return 1 - 𝐻(t1 - t2) * 𝐻(t2 - t1)
    else
        parse_error(e, "unrecognized binary operator: $s")
    end
end

function apply_nary_boolean(s, ts, e)
    if length(ts) == 1
        return ts[1]
    elseif s == "and"
        return ts[1] * apply_nary_boolean(s, ts[2:end], e)
    elseif s == "or"
        tail = apply_nary_boolean(s, ts[2:end], e)
        return ts[1] + tail - ts[1] * tail
    else
        parse_error(e, "unrecognized nary operator: $s")
    end
end

function convert_nary_apply(ml::CellModel, e)
    l = children(e)
    s = name(l[1])
    ts = [convert_term(ml, c) for c in l[2:end]]

    if s == "plus"
        return Term{Real}(+, ts)
    elseif s == "times"
        return Term{Real}(*, ts)
    else
        return apply_nary_boolean(s, ts, e)
    end
end

const constants = Dict(
    "pi" => T(π),
    "exponentiale" => T(ℯ),
    "notanumber" => NaN,
    "infinity" => Inf,
    "true" => true,
    "false" => false
)

function convert_math_constants(e)
    try
        return constants[name(e)]
    catch
        return nothing
    end
end

function process_cn(e)
    if has_attribute(e, "type")
        l = collect(child_nodes(e))
        if name(l[2]) != "sep"
            parse_error(e, "An e-notation number should have <sep>")
        end
        s = strip(content(l[1])) * "e" * strip(content(l[3]))
    else
        s = content(e)
    end
    return parse(T, s)
end

function convert_piecewise(ml::CellModel, e)
    l = []
    for c in children(e)
        s = name(c)
        h = children(c)
        if s == "piece"
            push!(l, convert_term(ml, h[1]))
            push!(l, convert_term(ml, h[2]))
        elseif s == "otherwise"
            push!(l, convert_term(ml, h[1]))
        end
    end

    return generate_piecewise(l)
end

function generate_piecewise(l)
    if length(l) == 1
        return l[1]
    else
        # l[2] should be an H expression
        return l[2]*l[1] + (one(l[2])-l[2])*generate_piecewise(l[3:end])
    end
end

#############################################################################

"""
    flat_equations flattens the equation list by substituting algebraic
    equations in the differential equations
"""
function flat_equations(ml::CellModel; level=1)
    alg = [a.lhs => a.rhs for a in ml.alg]
    for i = 1:level
        alg = [first(a) => substitute(last(a), alg) for a in alg]
    end
    eqs = [eq.lhs ~ substitute(eq.rhs, alg) for eq in ml.eqs]
    vs = [arguments(eq.lhs)[1] for eq in eqs]
    return eqs, vs
end

"""
    get_init_list returns a list of variable => initial value pairs

    ml is a CellModel
    if select_params == true, it returns a list of parameters (p in ODEProblem)
    if select_params == false, it returns a list of state variables (u0 in ODEProblem)
"""
function get_init_list(ml::CellModel, select_params=false)
    l = Pair[]
    states = list_states(ml)

    for v in values(ml.vars)
        s = repr(v)
        if haskey(ml.inits, s) && (v ∈ states) != select_params
            push!(l, v => ml.inits[s])
        end
    end

    return map(identity, l)
end

"""
    list_initial_conditions returns a list of state variable => initial value pairs
    u0 in ODEProblem
"""
list_initial_conditions(ml::CellModel) = get_init_list(ml, false)

"""
    list_params returns a list of params => initial value pairs
    p in ODEProblem
"""
list_params(ml::CellModel) = get_init_list(ml, true)

"""
    update_list! updates the value of an item in an initial value list (either p or u0)
    l is the list
    sym is a Symbol pointing to the variable (we also pass a string or a Symbolic)
    val is the new value
"""
function update_list!(l::Array{<:Pair}, sym::Symbol, val)
    for (i,x) in enumerate(l)
        if nameof(first(x)) == sym
            l[i] = first(x) => T(val)
            return
        end
    end
    parse_error(e, "param not found: $sym")
end

update_list!(l::Array{<:Pair}, name::AbstractString, val) =
        update_list!(l, Symbol(name), val)

update_list!(l::Array{<:Pair}, v::Number, val) =
        update_list!(l, v.op, val)

import ModelingToolkit.ODEProblem

"""
    ODEProblem constructs an ODEProblem from a CellModel
"""
function ODEProblem(ml::CellModel, tspan;
        jac=false, level=1, p=list_params(ml), u0=list_initial_conditions(ml))
    eqs, vs = flat_equations(ml; level=level)
    ps = map(first, p)
    sys = ODESystem(eqs, ml.iv, vs, ps)
    prob = ODEProblem(sys, u0, tspan, p; jac=jac)
    return prob
end

include("generator.jl")

end # module
