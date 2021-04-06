using HTTP

is_url(path) = length(path) > 7 && path[1:7] ∈ ["http://", "https:/", "HTTP://", "HTTPS:/"]

"""
    read_full_xml reads a CellML XML file or URL and applies the imports
    if applicable to generate a single XML document
"""
function read_full_xml(path)
    Document(read_and_import_xml(path))
end

function read_and_import_xml(path)
    if is_url(path)
        r = HTTP.request(:GET, path)
        str = String(r.body)
        xml = parsexml(str)
    else
        xml = readxml(path)
    end

    xmls = [xml]
    model = get_model(xml)

    for x in list_imports(xml)
        href = x["xlink:href"]
        if !is_url(href)
            href = joinpath(splitdir(path)[1], href)
        end

        for y in list_import_components(x)
            child = read_full_xml(href)
            append!(xmls, child.xmls)
            c = get_component(child, y["component_ref"])
            # @info("adding sub-component: $(c["name"])")
            if c != nothing
                unlink!(c)
                c["name"] = y["name"]
                link!(model, c)
            end
        end
    end

    return xmls
end



function load_cellml(path; resolve=true)
    xml = readxml(path)

    comps = [Component(Symbol(c["name"]), c) for c in list_components(xml)]

    conns = Connection[]
    for conn in list_connections(xml)
        vars = Pair{Var}[]
        c1, c2 = Symbol.(components_of(get_connection_component(conn)))
        for (v1,v2) in variables_of.(list_connection_variables(conn))
            push!(vars, make_var(c1,v1) => make_var(c2,v2))
        end
        push!(conns, Connection(c1, c2, vars))
    end

    doc = Document(path, [xml], comps, conns)

    if resolve
        resolve_imports(doc)
    end

    return doc
end

function find_component(doc::Document, name)
    i = findfirst(x -> x.name == Symbol(name), doc.comps)
    return i == nothing ? nothing : doc.comps[i]
end

implicit_name(sym, k) = Symbol("$(string(sym))_$k")

function resolve_imports(doc::Document)
    k = 1
    for ϵ in list_imports(doc)  # εισαγωγή == import
        href = ϵ["xlink:href"]
        path = joinpath(splitdir(doc.path)[1], href)
        child = load_cellml(path)
        append!(doc.xmls, child.xmls)

        L = Dict{Symbol, Symbol}()    # list of directly imported components

        for σ in list_import_components(ϵ)  # συστατικό == component
            name = Symbol(σ["component_ref"])
            comp = find_component(child, name)
            push!(doc.comps, Component(Symbol(σ["name"]), comp.node))
            L[name] = Symbol(σ["name"])
        end

        cluster = find_cluster(child, collect(keys(L)))

        if !isempty(cluster)
            for c in cluster
                comp = find_component(child, c)
                name = implicit_name(c, k)
                push!(doc.comps, Component(name, comp.node))
                L[c] = name
            end

            for conn in connections(child)
                c1, c2 = components(conn)
                if haskey(L,c1) || haskey(L,c2)
                    d1, d2 = L[c1], L[c2]
                    vars = [Var(d1,v1.var) => Var(d2,v2.var) for (v1,v2) in conn.vars]
                    push!(doc.conns, Connection(L[c1], L[c2], vars))
                end
            end

            k += 1
        end
    end
end

function find_cluster(doc::Document, l)
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
