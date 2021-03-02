using Test
using CellMLToolkit
using ModelingToolkit
using OrdinaryDiffEq

path = @__DIR__
ml = CellModel(path * "/../models/beeler_reuter_1977.cellml.xml")
sys = load_cellml(path * "/../models/beeler_reuter_1977.cellml.xml")

@test length(equations(sys)) == 8 == length(ml.eqs)
@test nameof(independent_variable(sys)) == :time
@test nameof(ml.iv) == :time

eqs, vs = CellMLToolkit.flat_equations(ml)
@test length(states(sys)) == 8 == length(vs)

@test nameof(find_V(ml)) == :V # todo replace all the dep graph code with mtk equiv

sys_u0 = ModelingToolkit.get_default_u0(sys)
sys_ps = ModelingToolkit.parameters(sys)

# would like to just pass sys_u0::Dict{Sym{Real}, Float64}
prob_sys = ODEProblem(sys, collect(values(sys_u0)), (0, 10.)) 
prob_sys2 = ODEProblem(sys, Pair[], (0, 10.)) 
@test_broken prob_sys.u0 == prob_sys2.u0 

prob_ml = ODEProblem(ml, (0,10000.0))
@test_broken prob_sys == prob_ml 
@test_broken prob_sys.u0 == prob_ml.u0 
@test_broken prob_sys.p == prob_ml.p # here prob_ml.p is a list, not a pair vec 

sol1 = solve(prob_sys, Euler(), dt=0.01, saveat=1.0)
sol2 = solve(prob_sys, TRBDF2(), dtmax=0.5, saveat=1.0)
V1 = map(x -> x[1], sol1.u)
V2 = map(x -> x[1], sol2.u)
err = sum(abs.(V1 .- V2)) / length(V1)
@test err < 0.1

sol3 = solve(prob_sys, TRBDF2(), dtmax=0.5, saveat=1.0)
V3 = map(x -> x[1], sol2.u)
err = sum(abs.(V1 .- V3)) / length(V1)
@test err < 0.1

p = list_params(ml)
update_list!(p, "IstimPeriod", 280.0)
prob = ODEProblem(ml, (0,10000.0); jac=false, p=p)
sol4 = solve(prob, TRBDF2(), dtmax=0.5, saveat=1.0)
V4 = map(x -> x[1], sol2.u)
err = sum(abs.(V1[1:250] .- V4[1:250])) / 250
@test err < 0.1
