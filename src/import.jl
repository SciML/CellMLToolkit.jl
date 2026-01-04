sym(x) = Symbol(x)

function populate_dependency!(doc, comp)
    empty!(comp.deps)
    for x in list_encapsulation(doc, comp)
        push!(comp.deps, sym(x["component"]))
    end
    return
end

function add_component!(doc, name, node, populate = true)
    comp = Component(name, node, Set{Symbol}())
    populate && populate_dependency!(doc, comp)
    push!(doc.comps, comp)
    return comp
end

function add_connection!(doc, c1, c2, vars)
    conn = Connection(c1, c2, vars)
    push!(doc.conns, conn)
    return conn
end

"""
    load_cellml loads a CellML file and populates a Document structures with
    the components and connections.

    If resolve = true, load_cellml also resolve the imported components.
"""
function load_cellml(path; resolve = true)
    xml = readxml(path)
    doc = Document(path, [xml], Component[], Connection[])

    for c in list_components(xml)
        add_component!(doc, sym(c["name"]), c)
    end

    for conn in list_connections(xml)
        c1, c2 = sym.(components_of(get_connection_component(conn)))
        vars = [
            make_var(c1, v1) => make_var(c2, v2)
                for (v1, v2) in variables_of.(list_connection_variables(conn))
        ]
        add_connection!(doc, c1, c2, vars)
    end

    resolve && resolve_imports!(doc)

    return doc
end

"""
    find_component finds a component by name
"""
function find_component(comps::Array{Component}, name)
    i = findfirst(x -> x.name == Symbol(name), comps)
    return i == nothing ? nothing : comps[i]
end

find_component(doc::Document, name) = find_component(doc.comps, name)

# implicit_name(sym) = Symbol("$(string(sym))_$(randstring(6))")
implicit_name(sym) = Symbol("$(string(sym))")

"""
    resolve_imports recursively resolves the imported components of doc.
"""
function resolve_imports!(doc::Document)
    for ϵ in list_imports(doc)  # εισαγωγή == import
        href = ϵ["xlink:href"]
        @info "importing $href"
        path = joinpath(splitdir(doc.path)[1], href)
        child = load_cellml(path)
        append!(doc.xmls, child.xmls)

        L = Dict{Symbol, Symbol}()      # L keeps the import names of components
        D = Set{Symbol}()               # D is the set of imported dependencies
        C = Set{Symbol}()

        # first, import explicitly imported component
        for σ in list_import_components(ϵ)  # συστατικό == component
            old_name = sym(σ["component_ref"])
            new_name = sym(σ["name"])
            old_comp = find_component(child, old_name)

            add_component!(doc, new_name, old_comp.node)

            D = D ∪ old_comp.deps
            L[old_name] = new_name
            push!(C, old_name)
        end

        # second, import implicitly imported component, as defined by closure
        #for c in find_closure(child, collect(keys(L)))
        for old_name in D
            if old_name ∉ C
                old_comp = find_component(child, old_name)
                new_name = implicit_name(old_name) # generates a name with a random suffix to prevent name collision
                add_component!(doc, new_name, old_comp.node, false)
                L[old_name] = new_name
            end
        end

        # third, we also need to import connections from the child CellML file
        for conn in connections(child)
            c1, c2 = components(conn)
            if haskey(L, c1) && haskey(L, c2)
                d1, d2 = L[c1], L[c2]
                vars = [Var(d1, v1.var) => Var(d2, v2.var) for (v1, v2) in conn.vars]
                add_connection!(doc, d1, d2, vars)
            end
        end
    end
    return
end

"""
    find_closure finds the transitive closure of a list of components (l) minus
    the list itself, i.e., it returns the list of components in doc which are
    reachable through a chain of connections starting from any component in l.
"""
function find_closure(doc::Document, l)
    n = copy(l)

    done = false
    while !done
        done = true
        for (c1, c2) in components.(connections(doc))
            if c1 ∈ n && c2 ∉ n
                push!(n, c2)
                done = false
            elseif c1 ∉ n && c2 ∈ n
                push!(n, c1)
                done = false
            end
        end
    end

    return [x for x in n if x ∉ l]
end

"""
Given a path to a directory containing multiple CellML files.

Returns the top level files.

Used as a helper function with the CellML Physiome Model repositories.
"""
function list_top_cellml_files(dir)
    files = filter(f -> endswith(f, ".cellml"), readdir(dir))

    if length(files) == 1
        return joinpath.(dir, files)
    end

    imported = Set{String}()
    for f in files
        xml = readxml(joinpath(dir, f))
        for n in list_imports(xml)
            push!(imported, n["xlink:href"])
        end
    end

    if !isempty(imported)
        printstyled("imported files are $imported\n"; color = :yellow)
    end

    return joinpath.(dir, [f for f in files if f ∉ imported])
end
