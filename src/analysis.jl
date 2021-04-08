"""
    A collection of analytic tools to evaluate CellML models
"""

function simplify_systems(systems)
    for x in systems
        sys = last(x)
        print("simplifying $(sys.name)")
        try
            sys = structural_simplify(sys)
            k = max(1, 50-length(string(sys.name)))
            printstyled(repeat(" ", k) * "OK!"; color=:green)
            println()
        catch e
            println(e)
        end

    end
end
