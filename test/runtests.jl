using SafeTestsets, Test

const GROUP = get(ENV, "GROUP", "All")

if GROUP == "All" || GROUP == "QA"
  @time @safetestset "Quality Assurance" include("qa.jl")
end

if GROUP == "All" || GROUP == "Core"
  @time @safetestset "beeler.jl" include("beeler.jl")
  @time @safetestset "noble_1962.jl" include("noble_1962.jl")
end
