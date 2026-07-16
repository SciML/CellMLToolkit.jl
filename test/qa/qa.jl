using SciMLTesting, CellMLToolkit, Test

run_qa(
    CellMLToolkit;
    explicit_imports = true,
    api_docs_kwargs = (; rendered = true, rendered_ignore = (:ODEProblem, :readxml)),
    aqua_kwargs = (; ambiguities = (; recursive = false)),
    ei_kwargs = (;
        all_qualified_accesses_are_public = (;
            ignore = (
                :Document,      # EzXML (not declared public)
                :Node,          # EzXML (not declared public)
            ),
        ),
    ),
)
