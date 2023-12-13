using CellMLToolkit, Aqua
@testset "Aqua" begin
    Aqua.find_persistent_tasks_deps(CellMLToolkit)
    Aqua.test_ambiguities(CellMLToolkit, recursive = false)
    Aqua.test_deps_compat(CellMLToolkit)
    Aqua.test_piracies(CellMLToolkit,
        treat_as_own = [])
    Aqua.test_project_extras(CellMLToolkit)
    Aqua.test_stale_deps(CellMLToolkit)
    Aqua.test_unbound_args(CellMLToolkit)
    Aqua.test_undefined_exports(CellMLToolkit)
end
