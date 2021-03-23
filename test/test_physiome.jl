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
a
"""
function main(dir="data/")
    tspan = (0., 1.)
    fns = readdir(dir; join=true)
    names = [:filename, :to_system, :to_problem, :to_solve, :states, :parameters, :error]
    n = length(names)
    mat = Array{Any,2}(nothing, length(fns), n)
    test_cellmls!(mat, fns)
    replace!(mat, nothing => missing)
    names .=> eachcol(mat) # used with DataFrame()
    # CSV.write("aggregate_stats.csv", df)
    # print(df)
end

function json_to_cellml_links()
    s = read("cellml.json", String);
    j = JSON3.read(s);
    x = j.collection.links
    map(x -> x.href[1:end - 5], x) # remove `/view` from urls 
end

ls = json_to_cellml_links(curl_exposures())
@test length(ls) == 2379
CellMLToolkit.grab(ls[1:10])
df = main()
@test eltype(df) == Pair
