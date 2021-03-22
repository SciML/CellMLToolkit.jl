using Test
using CellMLToolkit
using OrdinaryDiffEq
using JSON3, Base.Threads
using ModelingToolkit


@testset "CellMLToolkit.jl" begin
   @testset "beeler.jl" begin include("beeler.jl") end
   @testset "physiome.jl" begin include("physiome.jl") end
end
