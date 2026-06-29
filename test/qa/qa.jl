using SciMLTesting, CellMLToolkit, Test

run_qa(
    CellMLToolkit;
    explicit_imports = true,
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
