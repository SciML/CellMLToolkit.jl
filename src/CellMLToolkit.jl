module CellMLToolkit

using EzXML: EzXML, elements, namespace, nodecontent, parentnode, readxml, root
using MathML: extract_mathml, parse_node
using Memoize: @memoize
using ModelingToolkit: @parameters, @variables, Differential,
                       Equation, ODEProblem, ODESystem,
                       Symbolics, equations, parameters, structural_simplify,
                       substitute, unknowns
using Setfield: @set!

include("structures.jl")
include("accessors.jl")
include("components.jl")
include("import.jl")

function read_cellml(path::AbstractString, tspan)
    @warn "read_cellml is deprecated, please use CellModel"
    ml = CellModel(path)
    ODEProblem(ml, tspan)
end

##############################################################################

export CellModel, ODEProblem
export read_cellml
export list_params, list_states
export readxml, getsys
export update_list!

getsys(ml::CellModel) = ml.sys

"""
    constructs a CellModel struct for the CellML model defined in path
"""
function CellModel(path::AbstractString)
    doc = load_cellml(path)
    CellModel(doc, process_components(doc))
end

list_params(ml::CellModel) = find_sys_p(ml.doc, ml.sys)
list_states(ml::CellModel) = find_sys_u0(ml.doc, ml.sys)

import ModelingToolkit.ODEProblem

"""
    ODEProblem constructs an ODEProblem from a CellModel
"""
function ODEProblem(ml::CellModel, tspan;
        jac = false, level = 1, p = last.(list_params(ml)),
        u0 = last.(list_states(ml)))
    ODEProblem(ml.sys, u0, tspan, p; jac = jac)
end

function update_list!(l, sym, val)
    i = findfirst(isequal(sym), Symbol.(first.(l)))
    if i != nothing
        l[i] = (first(l[i]) => val)
    else
        @warn "symbol $sym not found"
    end
end

end # module
