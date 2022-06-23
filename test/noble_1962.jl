path = @__DIR__
ml = CellModel(path * "/../models/noble_1962/Noble_1962.cellml")

prob = ODEProblem(ml, (0, 10000.0))
sol1 = solve(prob, Euler(), dt = 0.01, saveat = 1.0)
sol2 = solve(prob, TRBDF2(), dtmax = 0.5, saveat = 1.0)
V1 = map(x -> x[2], sol1.u)
V2 = map(x -> x[2], sol2.u)
err = sum(abs.(V1 .- V2)) / length(V1)
@test err < 1.0
