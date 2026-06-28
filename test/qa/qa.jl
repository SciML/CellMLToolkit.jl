using SciMLTesting, CellMLToolkit, Test

run_qa(
    CellMLToolkit;
    explicit_imports = true,
    aqua_kwargs = (; ambiguities = (; recursive = false)),
    ei_kwargs = (;
        all_qualified_accesses_via_owners = (;
            ignore = (
                :isparameter,   # owner ModelingToolkitBase, re-exported by ModelingToolkit
                :unwrap,        # owner SymbolicUtils, re-exported by Symbolics
            ),
        ),
        all_qualified_accesses_are_public = (;
            ignore = (
                :Document,      # EzXML (not declared public)
                :Node,          # EzXML (not declared public)
            ),
        ),
    ),
)
