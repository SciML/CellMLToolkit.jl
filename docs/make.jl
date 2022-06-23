using Documenter

makedocs(sitename = "CellMLToolkit",
         doctest = false,
         strict = false,
         pages = [
             "Home" => "index.md",
             "Tutorial" => "tutorial.md",
         ])
