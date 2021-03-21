"
in place modifies a matrix with data about how far to `solve`
we get for a given set of cellml files

uses @threads
"
function test_cellmls!(mat, fns)
    @sync Threads.@threads for i in eachindex(fns)
        @show i fns[i]
        mat[i, :] = test_cellml!(mat[i, :], fns[i])
    end
    mat
end

"
in place modifies a row with data about how far to `solve`
we get for a given cellml file
"
function test_cellml!(row, fn)
    row[1] = fn
    try
        ml = CellModel(fn)
        sys = ml.sys
        row[2] = true
        row[5] = length(states(sys))
        row[6] = length(parameters(sys))
        prob = ODEProblem(ml, tspan)
        row[3] = true
        sol = solve(prob)
        row[4] = true
    catch e 
        row[end] = e
    end
    row
end

"""

grabs the cellml model repo

"""
function main(dir="data/")
    tspan = (0., 1.)
    grab(generate_cellml_links())
    
    # @test ispath("data")
    # @test length(readdir("data")) == 2379

    fns = readdir(dir; join=true)
    names = [:filename, :to_system, :to_problem, :to_solve, :states, :parameters, :error]
    n = length(names)
    mat = Array{Any,2}(nothing, length(fns), n)
    test_cellmls!(mat, fns)
    replace!(mat, nothing => missing)
    df = DataFrame(names .=> eachcol(mat))
    CSV.write("aggregate_stats.csv", df)
    print(df)
    df
end

# df = main()
