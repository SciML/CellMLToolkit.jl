using Test
using CellMLToolkit
using OrdinaryDiffEq
using JSON3, Base.Threads
using ModelingToolkit

@testset "CellMLToolkit.jl" begin
    @testset "beeler.jl" begin include("beeler.jl") end

    # mainly a used as a bin/ don't want to test every PR
    # @testset "physiome.jl" begin include("test_physiome.jl") end
end