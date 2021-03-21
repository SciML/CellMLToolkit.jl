"""queries the cellml repo api for links to cellml model repo"""
function generate_cellml_links()

    run(`curl -sL -H 'Accept: application/vnd.physiome.pmr2.json.1' 
        https://models.physiomeproject.org/search -d '{
        "template": {"data": [
            {"name": "Subject", "value": "CellML Model"},
            {"name": "portal_type", "value": "ExposureFile"}
        ]}
    }' -o cellml.json`)

    s = read("cellml.json", String);
    j = JSON3.read(s);
    x = j.collection.links
    map(x -> x.href[1:end - 5], x) # remove `/view` from urls 
end

"""
downloads the cellml model repository

todo use Base.Downloads to speed this up
"""
function grab(ls)
    !ispath("data") && mkpath("data")
    @sync Threads.@threads for l in ls 
        fn = split(l, "/")[end]
        download(l, "data/$(fn)")
    end
end
