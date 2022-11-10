using Documenter

cp("./docs/Manifest.toml", "./docs/src/assets/Manifest.toml", force = true)
cp("./docs/Project.toml", "./docs/src/assets/Project.toml", force = true)

mathengine = MathJax3(Dict(:loader => Dict("load" => ["[tex]/require", "[tex]/mathtools"]),
                           :tex => Dict("inlineMath" => [["\$", "\$"], ["\\(", "\\)"]],
                                        "packages" => [
                                            "base",
                                            "ams",
                                            "autoload",
                                            "mathtools",
                                            "require",
                                        ])))

makedocs(sitename = "CellMLToolkit.jl",
         authors = "Chris Rackauckas",
         modules = Module[],
         clean = true, doctest = false,
         strict = [
             :doctest,
             :linkcheck,
             :parse_error,
             :example_block,
             # Other available options are
             # :autodocs_block, :cross_references, :docs_block, :eval_block, :example_block, :footnote, :meta_block, :missing_docs, :setup_block
         ],
         format = Documenter.HTML(; analytics = "UA-90474609-3",
                                  assets = ["assets/favicon.ico"],
                                  mathengine,
                                  canonical = "https://docs.sciml.ai/CellMLToolkit/stable/",
                                  prettyurls = (get(ENV, "CI", nothing) == "true")),
         pages = [
             "Home" => "index.md",
             "Tutorial" => "tutorial.md",
         ])

deploydocs(repo = "github.com/SciML/CellMLToolkit.jl.git";
           push_preview = true)
