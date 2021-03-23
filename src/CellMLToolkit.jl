module CellMLToolkit

using MathML

using SymbolicUtils: FnType, Sym, operation, arguments
using ModelingToolkit
using EzXML

include("utils.jl")
export curl_exposures

include("cellml.jl")

"""
    reads a CellML path or io and returns an ODESystem
"""
function read_cellml(path, tspan)
    xml = readxml(path)
    ml = CellModel(xml, process_cellml_xml(xml))
    ODEProblem(ml, tspan)
end

"""
    parses a CellML XML string and returns an ODESystem
"""
function parse_cellml(xmlstr::AbstractString, tspan)
    xml = parsexml(xmlstr)
    ml = CellModel(xml, process_cellml_xml(xml))
    ODEProblem(ml, tspan)
end

##############################################################################

export CellModel, ODEProblem
export read_cellml, parse_cellml
export list_params, list_initial_conditions, list_states, update_list!
export eval_string, readxml

struct CellModel
    xml::EzXML.Document
    sys::ODESystem
end

getxml(ml::CellModel) = ml.xml
getsys(ml::CellModel) = ml.sys

"""
    constructs a CellModel struct for the CellML model defined in path
"""
function CellModel(path::AbstractString; dependency=true)
    xml = readxml(path)
    CellModel(xml, process_cellml_xml(xml))

    # fall-back option:
    # s = eval_string(xml)
    # eval(Meta.parse(s))
    # sys = ODESystem(eqs)
    # CellModel(xml, sys)
end

list_states(ml::CellModel) = getsys(ml).states
list_params(ml::CellModel) = list_params(getxml(ml))

"""
    extracts the initial conditions from ml.xml and sorts them
    according to ml.sys.states
"""
function list_initial_conditions(ml::CellModel)
    states = list_states(ml)
    u0 = list_initial_conditions(getxml(ml))
    map(x -> value_of(x, u0), states)
end

function value_of(x, u0)
    name = string(x)
    i = findfirst(x -> string(first(x)) == name, u0)
    if i == nothing
        @warn "param $name not found"
        return 0
    else
        return last(u0[i])
    end
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
    for (i, x) in enumerate(l)
        if first(x).name == sym
            l[i] = (first(x) => val)
            return
        end
    end
    parse_error(e, "param not found: $name")
end

update_list!(l, name::AbstractString, val) = update_list!(l, Symbol(name), val)

end # module
