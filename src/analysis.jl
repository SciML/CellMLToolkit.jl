"""
    A collection of analytic tools to evaluate CellML models
"""

function simplify_systems(systems)
    for x in systems
        sys = last(x)
        print("simplifying $(nameof(sys))")
        try
            sys = mtkcompile(sys)
            k = max(1, 50 - length(string(nameof(sys))))
            printstyled(repeat(" ", k) * "OK!"; color = :green)
            println()
        catch e
            println(e)
        end
    end
    return
end
