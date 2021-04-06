# Accessor functions to parse CellML xml(doc) files
# naming convention:
#   list_*:         returns a list of 'Ezxml(doc).Node's
#   get_*:          returns a single 'Ezxml(doc).Node'
#   list_*_names:   returns a list of String

EzXML.root(doc::Document) = root(doc.xmls[1])

cellml_ns(doc::Document) = cellml_ns(doc.xmls[1])
cellml_ns(comp::Component) = cellml_ns(comp.node)

nodeof(xml::EzXML.Document) = root(xml)
nodeof(node::EzXML.Node) = node
nodeof(comp::Component) = comp.node

"""
    list_components returns the list of CellML <Component>s
"""
list_components(xml) = findall("//x:model/x:component", root(xml), ["x"=>cellml_ns(xml)])

"""
    get_model returns the single <model> element of a CellML file
"""
get_model(xml) = findfirst("//x:model", root(xml), ["x"=>cellml_ns(xml)])

"""
    get_component_variables returns the list of the variables of a component
    comp is an Ezxml(doc) as returned by list_components
"""
list_component_variables(comp) = findall("./x:variable", nodeof(comp), ["x"=>cellml_ns(comp)])

"""
    list_initiated_variables returns all variables that have an initial_value
"""
# list_initiated_variables(xml::EzXML.Document) = findall("//x:component/x:variable[@initial_value]", root(xml), ["x"=>cellml_ns(xml)])

list_initiated_variables(comp::Component) = findall("./x:variable[@initial_value]", nodeof(comp), ["x"=>cellml_ns(comp)])

"""
    list_connections returns the list of <connection> nodes in the CellML document
"""
list_connections(xml) = findall("//x:connection", root(xml), ["x"=>cellml_ns(xml)])

"""
    get_connection_variables returns the pair of components for the given connection
    conn is an Ezxml(doc) node as returned by list_connections
"""
get_connection_component(conn) = findfirst("./x:map_components", nodeof(conn), ["x"=>cellml_ns(conn)])

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
list_connection_variables(conn) = findall("./x:map_variables", nodeof(conn), ["x"=>cellml_ns(conn)])

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
    nodes = findall("./y:math/y:apply", nodeof(comp), ["y"=>mathml_ns])
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
    nodes = findall("./y:math/y:apply", nodeof(comp), ["y"=>mathml_ns])
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
list_component_math(comp) = findall("./y:math", nodeof(comp), ["y"=>mathml_ns])

list_component_bvar(comp) = findall(".//y:math//y:bvar/y:ci", nodeof(comp), ["y"=>mathml_ns])

"""
    list_imports returns the list of <import> nodes in the CellML document
"""
list_imports(xml) = findall("//x:import", get_model(xml), ["x"=>cellml_ns(xml)])

"""
    list_import_components returns the list of component nodes of the given
    import element
    node: an import node as returned by list_imports
"""
list_import_components(node) = findall("./x:component", nodeof(node), ["x"=>cellml_ns(node)])
