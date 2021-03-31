using OrdinaryDiffEq
using Sundials

"
in place modifies a matrix with data about how far to `solve`
we get for a given set of cellml files
uses @threads
"
function test_cellmls!(mat, fns)
    @sync Threads.@threads for i in eachindex(fns)
        print(i, ": ", fns[i])
        mat[i, :] = test_cellml!(mat[i, :], fns[i])
        printstyled(mat[i, :]; color=:green)
        println()
    end
    mat
end

"
in place modifies a row with data about how far to `solve`
we get for a given cellml file
"
function test_cellml!(row, fn)
    tspan = (0.0, 1000.0)
    row[1] = fn
    try
        ml = CellModel(fn)
        row[2] = true
        row[5] = length(list_states(ml))
        row[6] = length(list_params(ml))
        prob = ODEProblem(ml, tspan)
        row[3] = true
        sol = solve(prob, CVODE_BDF(), dtmax=0.1)
        row[4] = true
    catch e
        printstyled(e; color=:red)
        println()
        row[end] = e
    end
    row
end

"""
a
"""
function main(dir="data/")
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

# ls = json_to_cellml_links()
# println(length(ls))
# CellMLToolkit.grab(ls[1:10])
# df = main()
# @test eltype(df) == Pair

using CSV

function clone()
    r = CSV.Rows("../cellml_repos.csv")

    for x in r
        url = x[3]
        try
            run(`git clone $url`)
        catch e
            println(e)
        end
    end
end

function run_all_repos(root; skip=0)
    res = Int[]
    n = 0
    for d in readdir(root)
        path = joinpath(root, d)
        if isdir(path)
            n += run_repo(path, res; dry_run=n<skip)
        end
    end
end

function run_repo(repo, res; file_limit=500000, dry_run=false)
    printstyled("processing repo $repo\n"; color=:blue)
    files = list_top_cellml_files(repo)
    n = 0
    for f in files
        l = filesize(f)
        if l > file_limit
            printstyled("\tfile $f ($l bytes) is too big and is skipped\n"; color=:red)
        else
            n += 1
            if dry_run
                printstyled("\tskipping file $f ($l bytes)\n"; color=:blue)
            else
                printstyled("\tprocessing file $f ($l bytes)\n"; color=:blue)
                k = 0
                try
                    ml = CellModel(f)
                    k = 1
                    prob  = ODEProblem(ml, (0,1000.0))
                    k = 2
                    sol = solve(prob, TRBDF2(), dtmax=0.5)
                    k = 3
                catch e
                    println(e)
                finally
                    push!(res, k)
                    n0 = length(res)
                    n1 = sum(res .== 1)
                    n2 = sum(res .== 2)
                    n3 = sum(res .== 3)
                    printstyled("$f done with a code $k:\t$n0\t$n1\t$n2\t$n3\n"; color=:green)
                end
            end
        end
    end

    return n
end

function list_top_cellml_files(repo)
    files = [f for f in readdir(repo) if endswith(f,".cellml")]

    if length(files) == 1
        return joinpath.(repo, files)
    end

    imported = Set{String}()
    for f in files
        xml = readxml(joinpath(repo, f))
        for n in list_import_nodes(xml)
            push!(imported, n["xlink:href"])
        end
    end

    if !isempty(imported)
        printstyled("imported files are $imported\n"; color=:yellow)
    end

    joinpath.(repo, [f for f in files if f ∉ imported])
end
