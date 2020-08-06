push!(LOAD_PATH,"../src/")

using Documenter, CellMLToolkit

makedocs(
    sitename= "CellMLToolkit",    
    doctest = false,
    strict = false,
    pages = [
        "Home" => "index.md",
        "Tutorial" => "tutorial.md"
    ]
)
