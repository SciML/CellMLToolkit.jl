using BenchmarkTools
using CellMLToolkit

const SUITE = BenchmarkGroup()

# Path to models directory
const MODELS_DIR = joinpath(@__DIR__, "..", "models")

# Helper function to clear memoization caches for fresh benchmarks
function clear_caches!()
    # Access the internal memoization caches created by Memoize.jl
    # These are named with the pattern ##<func_name>_memoized_cache
    empty!(CellMLToolkit.var"##infer_iv_memoized_cache")
    empty!(CellMLToolkit.var"##find_equivalence_groups_memoized_cache")
    empty!(CellMLToolkit.var"##classify_variables_memoized_cache")
end

# Define model paths and their categories
const MODELS = Dict(
    "lorenz" => (
        path = joinpath(MODELS_DIR, "lorenz.cellml.xml"),
        category = :small,
        description = "Lorenz equations (3 states)"
    ),
    "beeler_reuter" => (
        path = joinpath(MODELS_DIR, "beeler_reuter_1977.cellml.xml"),
        category = :medium,
        description = "Beeler-Reuter 1977 cardiac model (8 states)"
    ),
    "tentusscher" => (
        path = joinpath(MODELS_DIR, "tentusscher_noble_noble_panfilov_2004_a.cellml.xml"),
        category = :medium,
        description = "Ten Tusscher et al. 2004 cardiac model (17 states)"
    ),
    "ohara_rudy" => (
        path = joinpath(MODELS_DIR, "ohara_rudy_cipa_v1_2017.cellml.xml"),
        category = :large,
        description = "O'Hara-Rudy CiPA 2017 cardiac model (49 states)"
    ),
    "noble_1962" => (
        path = joinpath(MODELS_DIR, "noble_1962", "Noble_1962.cellml"),
        category = :small,
        description = "Noble 1962 multi-file model (4 states)"
    )
)

# Benchmark groups for different stages of the lowering process
SUITE["lowering"] = BenchmarkGroup()

# Benchmark CellModel construction (the complete lowering process)
for (name, info) in MODELS
    if isfile(info.path)
        SUITE["lowering"][name] = @benchmarkable begin
            clear_caches!()
            CellModel($info.path)
        end samples=5 evals=1 seconds=120
    end
end

# Category-based benchmark groups
SUITE["by_category"] = BenchmarkGroup()
SUITE["by_category"]["small"] = BenchmarkGroup()
SUITE["by_category"]["medium"] = BenchmarkGroup()
SUITE["by_category"]["large"] = BenchmarkGroup()

for (name, info) in MODELS
    if isfile(info.path)
        cat = info.category
        SUITE["by_category"][string(cat)][name] = @benchmarkable begin
            clear_caches!()
            CellModel($info.path)
        end samples=5 evals=1 seconds=120
    end
end
