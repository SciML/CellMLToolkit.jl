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
