# Script to run benchmarks and optionally compare against a baseline
#
# Usage:
#   julia --project=benchmark benchmark/runbenchmarks.jl                    # Run benchmarks
#   julia --project=benchmark benchmark/runbenchmarks.jl --compare master   # Compare against master branch
#   julia --project=benchmark benchmark/runbenchmarks.jl --save baseline    # Save results as baseline
#
# Environment variables:
#   CELLML_BENCH_SAMPLES: Number of benchmark samples (default: 5)
#   CELLML_BENCH_SECONDS: Maximum seconds per benchmark (default: 120)

using Pkg
Pkg.develop(path=dirname(@__DIR__))
Pkg.instantiate()

using PkgBenchmark
using CellMLToolkit

function main()
    args = ARGS

    if "--help" in args || "-h" in args
        println("""
        CellMLToolkit Benchmark Runner

        Usage:
          julia --project=benchmark benchmark/runbenchmarks.jl [options]

        Options:
          --compare <ref>   Compare current version against git reference (e.g., master, v2.14.0)
          --save <name>     Save benchmark results to benchmark/results/<name>.json
          --help, -h        Show this help message

        Examples:
          julia --project=benchmark benchmark/runbenchmarks.jl
          julia --project=benchmark benchmark/runbenchmarks.jl --compare master
          julia --project=benchmark benchmark/runbenchmarks.jl --compare v2.14.0
          julia --project=benchmark benchmark/runbenchmarks.jl --save baseline
        """)
        return
    end

    pkg_path = dirname(@__DIR__)

    # Check for comparison mode
    compare_idx = findfirst(==("--compare"), args)
    if compare_idx !== nothing && compare_idx < length(args)
        baseline_ref = args[compare_idx + 1]
        println("Comparing current version against $baseline_ref...")

        # Run comparison benchmarks
        results = judge(pkg_path, baseline_ref)

        println("\n" * "="^80)
        println("BENCHMARK COMPARISON RESULTS")
        println("="^80)
        println("\nBaseline: $baseline_ref")
        println("Target: HEAD\n")

        show(stdout, MIME("text/plain"), results)

        # Export comparison report
        results_dir = joinpath(@__DIR__, "results")
        mkpath(results_dir)
        export_markdown(joinpath(results_dir, "comparison_$(baseline_ref)_to_HEAD.md"), results)
        println("\n\nComparison report saved to benchmark/results/comparison_$(baseline_ref)_to_HEAD.md")

        return results
    end

    # Run benchmarks
    println("Running benchmarks...")
    results = benchmarkpkg(pkg_path)

    println("\n" * "="^80)
    println("BENCHMARK RESULTS")
    println("="^80)
    show(stdout, MIME("text/plain"), results)

    # Check for save option
    save_idx = findfirst(==("--save"), args)
    if save_idx !== nothing && save_idx < length(args)
        save_name = args[save_idx + 1]
        results_dir = joinpath(@__DIR__, "results")
        mkpath(results_dir)

        # Export results
        writeresults(joinpath(results_dir, "$(save_name).json"), results)
        export_markdown(joinpath(results_dir, "$(save_name).md"), results)
        println("\n\nResults saved to:")
        println("  - benchmark/results/$(save_name).json")
        println("  - benchmark/results/$(save_name).md")
    end

    return results
end

main()
