using Test
using CellMLToolkit
using DifferentialEquations, Plots
using JSON3, Base.Threads
using ModelingToolkit
using DataFrames, CSV 
# todo lighten test deps, remove de, plots, dataframes, maybe csv 


@testset "CellMLToolkit.jl" begin
   @testset "beeler.jl" begin include("beeler.jl") end
   @testset "physiome.jl" begin include("physiome.jl") end
end
