# Accessor functions to parse CellML xml(doc) files
# naming convention:
#   list_*:         returns a list of 'Ezxml(doc).Node's
#   get_*:          returns a single 'Ezxml(doc).Node'
#   list_*_names:   returns a list of String

struct Document
    xmls::Array{EzXML.Document}
end

EzXML.root(doc::Document) = root(doc.xmls[1])
cellml_ns(doc::Document) = cellml_ns(doc.xmls[1])

"""
    list_components returns the list of CellML <Component>s
"""
@memoize list_components(doc::Document) = list_components_unmem(doc)

"""
    unmemoizied version of list_components
"""
list_components_unmem(doc::Document) = findall("//x:model/x:component", root(doc), ["x"=>cellml_ns(doc)])

get_component(doc::Document, name) = findfirst("//x:model/x:component[@name='$name']", root(doc), ["x"=>cellml_ns(doc)])

"""
    get_model returns the single <model> element of a CellML file
"""
get_model(doc::Document) = findfirst("//x:model", root(doc), ["x"=>cellml_ns(doc)])

get_model(xml::EzXML.Document) = findfirst("//x:model", root(xml), ["x"=>cellml_ns(xml)])

"""
    get_component_variables returns the list of the variables of a component
    comp is an Ezxml(doc) as returned by list_components
"""
@memoize list_component_variables(comp) = findall("./x:variable", comp, ["x"=>cellml_ns(comp)])

"""
    list_initiated_variables returns all variables that have an initial_value
"""
@memoize list_initiated_variables(doc::Document) =
    findall("//x:component/x:variable[@initial_value]", root(doc), ["x"=>cellml_ns(doc)])

"""
    list_connections returns the list of <connection> nodes in the CellML document
"""
@memoize list_connections(doc::Document) =
    findall("//x:connection", root(doc), ["x"=>cellml_ns(doc)])

"""
    get_connection_variables returns the pair of components for the given connection
    conn is an Ezxml(doc) node as returned by list_connections
"""
get_connection_component(conn) =
    findfirst("./x:map_components", conn, ["x"=>cellml_ns(conn)])

"""
    components_of converts the output of get_connection_component to a pair
    of strings (the names of the components)
"""
components_of(x) = (x["component_1"], x["component_2"])

"""
    list_connection_variables returns a list composed of pairs of variable
    for the given connection
    conn is an Ezxml(doc) node as returned by list_connections
"""
list_connection_variables(conn) =
    findall("./x:map_variables", conn, ["x"=>cellml_ns(conn)])

"""
    components_of converts the output of list_connection_variables to a pair
    of strings (the names of the variables)
"""
variables_of(x) = (x["variable_1"], x["variable_2"])

"""
    list_state_names returns the names of variables that occur on the left-hand-side
    of an ODE; hence are *state* variables
    comp is an Ezxml(doc) as returned by list_components
"""
function find_state_names(comp)
    nodes = findall("./y:math/y:apply", comp, ["y"=>mathml_ns])
    names = String[]
    for n in nodes
        e = elements(n)
        if e[1].name == "eq" && e[2].name == "apply"
            h = elements(e[2])
            if h[1].name == "diff" && h[3].name == "ci"
                push!(names, strip(nodecontent(h[3])))
            end
        end
    end
    return names
end

"""
    list_alg_names returns the names of variables that occur on the left-hand-side
    of a non-ODE equation; hence are *algebraic* variables
    comp is an Ezxml(doc) as returned by list_components
"""
function find_alg_names(comp)
    nodes = findall("./y:math/y:apply", comp, ["y"=>mathml_ns])
    names = String[]
    for n in nodes
        e = elements(n)
        if e[1].name == "eq" && e[2].name == "ci"
            push!(names, strip(nodecontent(e[2])))
        end
    end
    return names
end

"""
    list_component_math returns a list of the math elements in the
    given component
"""
list_component_math(comp) = findall("./y:math", comp, ["y"=>mathml_ns])

"""
    list_imports returns the list of <import> nodes in the CellML document
"""
list_imports(doc::Document) = findall("//x:import", root(doc), ["x"=>cellml_ns(doc)])

list_imports(xml::EzXML.Document) = findall("//x:import", root(xml), ["x"=>cellml_ns(xml)])

"""
    list_import_components returns the list of component nodes of the given
    import element
    node: an import node as returned by list_imports
"""
list_import_components(node) = findall("./x:component", node, ["x"=>cellml_ns(node)])
