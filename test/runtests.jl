using Test
using CellMLToolkit
using OrdinaryDiffEq
using ModelingToolkit

@testset "CellMLToolkit.jl" begin
    @testset "beeler.jl" begin include("beeler.jl") end
end