using CellMLToolkit, BenchmarkTools

const SUITE = BenchmarkGroup()

models_dir = joinpath(@__DIR__, "..", "models")

# =============================================================================
# CellML model loading / ODE system generation
# =============================================================================

SUITE["load"] = BenchmarkGroup()

SUITE["load"]["beeler_reuter"] = @benchmarkable CellModel(
    joinpath($models_dir, "beeler_reuter_1977.cellml.xml")
)
SUITE["load"]["lorenz"] = @benchmarkable CellModel(
    joinpath($models_dir, "lorenz.cellml.xml")
)

ml = CellModel(joinpath(models_dir, "lorenz.cellml.xml"))
ml_beeler = CellModel(joinpath(models_dir, "beeler_reuter_1977.cellml.xml"))

SUITE["load"]["getsys"] = @benchmarkable getsys($ml)
SUITE["load"]["list_states"] = @benchmarkable list_states($ml_beeler)
SUITE["load"]["list_params"] = @benchmarkable list_params($ml_beeler)
