module CellMLToolkit

using EzXML: EzXML, elements, hasroot, namespace, nodecontent, parentnode, readxml, root
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

Deprecated alias for `ModelingToolkit.ODEProblem(CellModel(path), tspan)`.

Use `CellModel(path)` and `ModelingToolkit.ODEProblem(ml, tspan)` directly in
new code.

# Arguments

  - `path`: Path to a CellML XML file.
  - `tspan`: Two-element time span for the generated ODE problem.

# Returns

The `ODEProblem` constructed from the parsed CellML model.
"""
function read_cellml(path::AbstractString, tspan)
    Base.depwarn("`read_cellml` is deprecated, use `CellModel` instead.", :read_cellml)
    ml = CellModel(path)
    return ODEProblem(ml, tspan)
end

##############################################################################

export CellModel
export read_cellml
export list_params, list_states
export getsys
export update_list!

"""
    getsys(ml::CellModel)

Return the ModelingToolkit system generated for `ml`.

# Arguments

  - `ml`: A parsed CellML model.

# Returns

The `ModelingToolkit.System` generated from the CellML components in `ml`.
"""
getsys(ml::CellModel) = ml.sys

"""
    CellModel(path::AbstractString)

Read the CellML model at `path`, resolve imports, and generate a `CellModel`.

# Arguments

  - `path`: Path to a CellML XML file.

# Returns

A `CellModel` containing the parsed CellML document and generated
`ModelingToolkit.System`.

# Examples

```jldoctest; setup = :(using CellMLToolkit)
julia> model_path = joinpath(pkgdir(CellMLToolkit), "models", "lorenz.cellml.xml");

julia> model = CellModel(model_path);

julia> !isempty(list_states(model))
true
```
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

# Arguments

  - `ml`: A parsed CellML model.

# Returns

A vector of `parameter => value` pairs.
"""
list_params(ml::CellModel) = find_sys_p(ml.doc, ml.sys)

"""
    list_states(ml::CellModel)

Return the initial state assignments for `ml`.

The returned vector contains `state => value` pairs ordered to match the
unknowns in `getsys(ml)`.

# Arguments

  - `ml`: A parsed CellML model.

# Returns

A vector of `state => value` pairs.
"""
list_states(ml::CellModel) = find_sys_u0(ml.doc, ml.sys)

import ModelingToolkit.ODEProblem

"""
    ModelingToolkit.ODEProblem(ml::CellModel, tspan; jac = false, level = 1,
        p = last.(list_params(ml)), u0 = last.(list_states(ml)))

Construct a ModelingToolkit ODE problem from a `CellModel`.

This method extends the public `ModelingToolkit.ODEProblem` interface. Call it
through `ModelingToolkit.ODEProblem`; CellMLToolkit does not reexport that
generic function. The method preserves the CellML model's parameter and state
ordering unless `p` or `u0` is supplied.

# Arguments

  - `ml`: Parsed CellML model.
  - `tspan`: Two-element time span passed to the generated ODE problem.

# Keywords

  - `jac`: Whether to request Jacobian generation from ModelingToolkit.
  - `level`: Retained for backward compatibility and otherwise ignored.
  - `p`: Parameter values ordered like `list_params(ml)`.
  - `u0`: Initial state values ordered like `list_states(ml)`.

# Returns

An `ODEProblem` whose system is `getsys(ml)`.

# Examples

```jldoctest; setup = :(using CellMLToolkit, ModelingToolkit)
julia> model = CellModel(joinpath(pkgdir(CellMLToolkit), "models", "lorenz.cellml.xml"));

julia> problem = ModelingToolkit.ODEProblem(model, (0.0, 1.0));

julia> problem.f.sys === getsys(model)
true
```
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

  - `l`: Mutable vector of `variable => value` pairs, such as the output of
    `list_params` or `list_states`.
  - `sym`: Symbol identifying the variable to update.
  - `val`: Replacement value.

# Returns

The updated pair when `sym` is present in `l`; otherwise emits a warning and
returns `nothing`.
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
