using Test
using CellMLToolkit
using DifferentialEquations, Plots

path = @__DIR__
ml = CellModel(path * "/../models/beeler_reuter_1977.cellml.xml")

# @test length(ml.eqs) == 8
# @test ml.iv.op.name == :time

# eqs, vs = CellMLToolkit.flat_equations(ml)
# @test length(vs) == 8

# @test find_V(ml).op.name == :V

prob = ODEProblem(ml, (0,10000.0))
sol1 = solve(prob, Euler(), dt=0.01, saveat=1.0)
sol2 = solve(prob, TRBDF2(), dtmax=0.5, saveat=1.0)
V1 = map(x -> x[1], sol1.u)
V2 = map(x -> x[1], sol2.u)
err = sum(abs.(V1 .- V2)) / length(V1)
@test err < 0.1

# prob = ODEProblem(ml, (0,10000.0); jac=true)
# sol3 = solve(prob, TRBDF2(), dtmax=0.5, saveat=1.0)
# V3 = map(x -> x[1], sol2.u)
# err = sum(abs.(V1 .- V3)) / length(V1)
# @test err < 0.1

p = list_params(ml)
update_list!(p, "IstimPeriod", 280.0)
prob = ODEProblem(ml, (0,10000.0); jac=false, p=p)
sol4 = solve(prob, TRBDF2(), dtmax=0.5, saveat=1.0)
V4 = map(x -> x[1], sol2.u)
err = sum(abs.(V1[1:250] .- V4[1:250])) / 250
@test err < 0.1


##############################################################################

function test_plot()
    ml = CellModel(path * "/../models/beeler_reuter_1977.cellml.xml")
    tspan = (0, 5000.0)
    prob = ODEProblem(ml, tspan)
    sol = solve(prob, TRBDF2(), dtmax=0.5)
    x = Array(sol)
    plot(x[1,:])
end
