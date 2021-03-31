using HTTP

is_url(path) = length(path) > 7 && path[1:7] ∈ ["http://", "https:/", "HTTP://", "HTTPS:/"]

function read_full_xml(path)
    if is_url(path)
        r = HTTP.request(:GET, path)
        str = String(r.body)
        xml = parsexml(str)
    else
        xml = readxml(path)
    end

    model = get_model_node(xml)

    for x in list_import_nodes(xml)
        href = x["xlink:href"]
        if !is_url(href)
            href = joinpath(splitdir(path)[1], href)
        end        
        child = read_full_xml(href)
        for y in list_import_component_nodes(xml, x)
            c = get_component_node(child, y["component_ref"])
            if c != nothing
                unlink!(c)
                c["name"] = y["name"]
                link!(model, c)
            end
        end
    end

    return xml
end
