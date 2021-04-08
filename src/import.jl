using Random

component_sym(x) = Symbol(x)

"""
    load_cellml loads a CellML file and populates a Document structures with
    the components and connections.

    If resolve = true, load_cellml also resolve the imported components.
"""
function load_cellml(path; resolve=true)
    xml = readxml(path)

    comps = [Component(component_sym(c["name"]), c) for c in list_components(xml)]

    conns = Connection[]
    for conn in list_connections(xml)
        c1, c2 = component_sym.(components_of(get_connection_component(conn)))
        vars = [make_var(c1,v1) => make_var(c2,v2)
                for (v1,v2) in variables_of.(list_connection_variables(conn))]
        push!(conns, Connection(c1, c2, vars))
    end

    doc = Document(path, [xml], comps, conns)

    if resolve
        resolve_imports(doc)
    end

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

implicit_name(sym) = Symbol("$(string(sym))_$(randstring(6))")

"""
    resolve_imports recursivelly resolves the imported components of doc.
"""
function resolve_imports(doc::Document)
    for ϵ in list_imports(doc)  # εισαγωγή == import
        href = ϵ["xlink:href"]
        @info "importing $href"
        path = joinpath(splitdir(doc.path)[1], href)
        child = load_cellml(path)
        append!(doc.xmls, child.xmls)

        L = Dict{Symbol, Symbol}()    # L keeps the import names of components

        # first, import explicitly imported component
        for σ in list_import_components(ϵ)  # συστατικό == component
            name = component_sym(σ["component_ref"])
            comp = find_component(child, name)
            push!(doc.comps, Component(component_sym(σ["name"]), comp.node))
            L[name] = component_sym(σ["name"])
        end

        # second, import implicitly imported component, as defined by closure
        for c in find_closure(child, collect(keys(L)))
            comp = find_component(child, c)
            name = implicit_name(c) # generates a name with a random suffix to prevent name collision
            push!(doc.comps, Component(name, comp.node))
            L[c] = name
        end

        # third, we also need to import connections from the child CellML file
        for conn in connections(child)
            c1, c2 = components(conn)
            if haskey(L,c1) || haskey(L,c2)
                d1, d2 = L[c1], L[c2]
                vars = [Var(d1,v1.var) => Var(d2,v2.var) for (v1,v2) in conn.vars]
                push!(doc.conns, Connection(d1, d2, vars))
            end
        end
    end
end

"""
    find_closure finds the transitive closure of a list of componenets (l) minus
    the list itself, i.e., it returns the list of components in doc which are
    reachable through a chain of connections starting from any component in l.
"""
function find_closure(doc::Document, l)
    n = copy(l)

    done = false
    while !done
        done = true
        for (c1,c2) in components.(connections(doc))
            if c1 ∈ n && c2 ∉ n
                push!(n, c2)
                done = false
            elseif c1 ∉ n && c2 ∈ n
                push!(n, c1)
                done = false
            end
        end
    end

    [x for x in n if x ∉ l]
end
