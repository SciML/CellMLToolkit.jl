using Test
using CellMLToolkit
using OrdinaryDiffEq
using ModelingToolkit

@testset "CellMLToolkit.jl" begin
    @testset "beeler.jl" begin include("beeler.jl") end
    @testset "noble_1962.jl" begin include("noble_1962.jl") end
end
