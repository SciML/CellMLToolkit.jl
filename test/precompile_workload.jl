using CellMLToolkit, ModelingToolkit, Test

@testset "Precompile workload API" begin
    model_path = joinpath(pkgdir(CellMLToolkit), "models", "lorenz.cellml.xml")
    model = CellModel(model_path)
    problem = ModelingToolkit.ODEProblem(model, (0.0, 1.0))
    @test problem.f.sys === getsys(model)
    @test !isempty(list_states(model))
    @test !isempty(list_params(model))
end
