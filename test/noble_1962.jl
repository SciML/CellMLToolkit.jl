using CellMLToolkit
using OrdinaryDiffEq
using ModelingToolkit
path = @__DIR__
ml = CellModel(path * "/../models/noble_1962/Noble_1962.cellml")

prob = ODEProblem(ml, (0, 10000.0))
sol1 = solve(prob, Euler(), dt = 0.01, saveat = 1.0)
sol2 = solve(prob, TRBDF2(), dtmax = 0.5, saveat = 1.0, reltol = 1e-8, abstol = 1e-8)
V1 = map(x -> x[2], sol1.u)
V2 = map(x -> x[2], sol2.u)
err1 = sum(abs.(V1 .- V2)) / length(V1)
@test err1 < 1.0

# Ensure defaults are set and that generating an `ODEProblem` directly from the
# `ODESystem` is equivalent to doing so from a `CellModel`
@test length(ModelingToolkit.defaults(ml.sys)) > 0
sys_prob = ODEProblem(ml.sys; tspan = (0, 10000.0))
sol3 = solve(prob, Euler(), dt = 0.01, saveat = 1.0)
V3 = map(x -> x[2], sol3.u)
err2 = sum(abs.(V1 .- V3)) / length(V1)
@test err2 ≈ 0
