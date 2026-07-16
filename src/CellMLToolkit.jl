module CellMLToolkit

using EzXML: EzXML, elements, namespace, nodecontent, parentnode, readxml, root
using MathML: extract_mathml, parse_node
using Memoize: @memoize
using SymbolicUtils: SymbolicUtils, operation, unwrap
using ModelingToolkit: ModelingToolkit, @parameters, @variables, Differential,
    Equation, ODEProblem, System,
    equations, parameters, mtkcompile,
    substitute, unknowns, initial_conditions
using ModelingToolkitBase: isparameter
using Setfield: @set!

include("structures.jl")
include("accessors.jl")
include("components.jl")
include("import.jl")

"""
    read_cellml(path::AbstractString, tspan)

Deprecated alias for `ODEProblem(CellModel(path), tspan)`.

Use `CellModel(path)` and `ODEProblem(ml, tspan)` directly in new code.
"""
function read_cellml(path::AbstractString, tspan)
    Base.depwarn("`read_cellml` is deprecated, use `CellModel` instead.", :read_cellml)
    ml = CellModel(path)
    return ODEProblem(ml, tspan)
end

##############################################################################

export CellModel, ODEProblem
export read_cellml
export list_params, list_states
export readxml, getsys
export update_list!

"""
    getsys(ml::CellModel)

Return the ModelingToolkit system generated for `ml`.
"""
getsys(ml::CellModel) = ml.sys

"""
    CellModel(path::AbstractString)

Read the CellML model at `path`, resolve imports, and generate a `CellModel`.

# Arguments

  - `path`: Path to a CellML XML file.
"""
function CellModel(path::AbstractString)
    doc = load_cellml(path)
    return CellModel(doc, process_components(doc))
end

"""
    list_params(ml::CellModel)

Return the parameter default assignments for `ml`.

The returned vector contains `parameter => value` pairs ordered to match the
parameters in `getsys(ml)`.
"""
list_params(ml::CellModel) = find_sys_p(ml.doc, ml.sys)

"""
    list_states(ml::CellModel)

Return the initial state assignments for `ml`.

The returned vector contains `state => value` pairs ordered to match the
unknowns in `getsys(ml)`.
"""
list_states(ml::CellModel) = find_sys_u0(ml.doc, ml.sys)

import ModelingToolkit.ODEProblem

"""
    ODEProblem(ml::CellModel, tspan; jac = false, level = 1,
        p = last.(list_params(ml)), u0 = last.(list_states(ml)))

Construct an `ODEProblem` from a `CellModel`.

# Arguments

  - `ml`: Parsed CellML model.
  - `tspan`: Time span passed to the generated ODE problem.

# Keywords

  - `jac`: Whether to request Jacobian generation.
  - `level`: Accepted for compatibility.
  - `p`: Parameter values ordered like `list_params(ml)`.
  - `u0`: Initial state values ordered like `list_states(ml)`.
"""
function ODEProblem(
        ml::CellModel, tspan;
        jac = false, level = 1, p = last.(list_params(ml)),
        u0 = last.(list_states(ml))
    )
    return ODEProblem(ml.sys, Pair[unknowns(ml.sys) .=> u0; parameters(ml.sys) .=> p], tspan; jac = jac)
end

"""
    update_list!(l, sym, val)

Replace the value paired with `sym` in `l`.

# Arguments

  - `l`: Vector of `variable => value` pairs, such as the output of `list_params`
    or `list_states`.
  - `sym`: Symbol identifying the variable to update.
  - `val`: Replacement value.
"""
function update_list!(l, sym, val)
    i = findfirst(isequal(sym), Symbol.(first.(l)))
    return if i !== nothing
        l[i] = (first(l[i]) => val)
    else
        @warn "symbol $sym not found"
    end
end

end # module
