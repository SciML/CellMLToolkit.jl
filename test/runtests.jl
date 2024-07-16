using SafeTestsets, Test

@time @safetestset "Quality Assurance" include("qa.jl")
@time @safetestset "beeler.jl" include("beeler.jl")
@time @safetestset "noble_1962.jl" include("noble_1962.jl")
