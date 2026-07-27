using CellMLToolkit, ModelingToolkit, Test

@testset "CellModel ModelingToolkit interface" begin
    model_path = joinpath(pkgdir(CellMLToolkit), "models", "lorenz.cellml.xml")
    model = CellMLToolkit.CellModel(model_path)

    # Exercise the CellModel extension only through ModelingToolkit's public generic.
    problem = ModelingToolkit.ODEProblem(model, (0.0, 1.0))

    @test problem.f.sys === CellMLToolkit.getsys(model)
    @test !isempty(CellMLToolkit.list_states(model))
    @test !isempty(CellMLToolkit.list_params(model))
end
