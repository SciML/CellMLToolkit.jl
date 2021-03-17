module CellMLToolkit

using EzXML #, Symbolics, SymbolicUtils
using SymbolicUtils: FnType, Sym, operation

#using MathML
using Statistics
include("parse.jl")
include("utils.jl")

using ModelingToolkit

include("cellml.jl")

"""
    reads a CellML path or io and returns an ODESystem
"""
function read_cellml(path)
    xml = readxml(path)
    return read_cellml(xml)
end

"""
    parses a CellML XML string and returns an ODESystem
"""
function parse_cellml(xmlstr::AbstractString)
    xml = parsexml(xmlstr)
    return read_cellmL(xml)
end

##############################################################################

export CellModel, ODEProblem
export read_cellml, parse_cellml
export list_params, list_initial_conditions, list_states, update_list!
export eval_cellml, eval_string, readxml

struct CellModel
    xml::EzXML.Document
    sys::ODESystem
end

"""
    constructs a CellModel struct for the CellML model defined in path
"""
function CellModel(path::AbstractString; dependency=true)
    xml = readxml(path)
    CellModel(xml, read_cellml(xml))

    # fall-back option:
    # s = eval_string(xml)
    # eval(Meta.parse(s))
    # sys = ODESystem(eqs)
    # CellModel(xml, sys)
end

list_states(ml::CellModel) = list_states(ml.xml)
list_params(ml::CellModel) = list_params(ml.xml)
# list_initial_conditions(ml::CellModel) = list_initial_conditions(ml.xml)

# extracts the initial conditions from ml.xml and sorts them
# according to ml.sys.states
function list_initial_conditions(ml::CellModel)
    states = ml.sys.states
    u0 = list_initial_conditions(ml.xml)
    # map(x -> (x => value_of(x, u0)), states)
    map(x -> value_of(x, u0), states)
end

function value_of(x, u0)
    name = string(x)
    i = findfirst(x -> string(first(x)) == name, u0)
    return last(u0[i])
end


import ModelingToolkit.ODEProblem

"""
    ODEProblem constructs an ODEProblem from a CellModel
"""
function ODEProblem(ml::CellModel, tspan;
        jac=false, level=1, p=list_params(ml), u0=list_initial_conditions(ml))
    ODEProblem(ml.sys, u0, tspan, p; jac=jac)
end

"""
    update_list! updates the value of an item in an initial value list (either p or u0)
    l is the list
    sym is a Symbol pointing to the variable (we also pass a string)
    val is the new value
"""
function update_list!(l, sym::Symbol, val)
    for (i,x) in enumerate(l)
        if first(x).name == sym
            l[i] = first(x) => val
            return
        end
    end
    parse_error(e, "param not found: $name")
end

update_list!(l, name::AbstractString, val) = update_list!(l, Symbol(name), val)

end # module
