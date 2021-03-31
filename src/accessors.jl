list_component_nodes(xml::EzXML.Document) = findall("//x:model/x:component", root(xml), ["x"=>cellml_ns(xml)])

get_model_node(xml::EzXML.Document) = findfirst("//x:model", root(xml), ["x"=>cellml_ns(xml)])

get_component_node(xml::EzXML.Document, comp) = findfirst("//x:component[@name='$comp']", root(xml), ["x"=>cellml_ns(xml)])

"""
    list_components returns the names of CellML <Component>s
"""
@memoize list_components(xml::EzXML.Document) = map(x -> x["name"], list_component_nodes(xml))

"""
    get_component_variables returns the names of the variables of a component
"""
function get_component_variables(xml::EzXML.Document, comp)
    vars = findall("//x:component[@name='$comp']/x:variable", root(xml),
                   ["x"=>cellml_ns(xml)])
    map(x -> x["name"], vars)
end

"""
    list_initiated_variables returns all variables that have an initial_value
"""
@memoize function list_initiated_variables(xml::EzXML.Document)
    findall("//x:component/x:variable[@initial_value]", root(xml), ["x"=>cellml_ns(xml)])
end

"""
    list_connections returns the list of <connection> nodes in the CellML document
"""
@memoize list_connections(xml::EzXML.Document) = findall("//x:connection", root(xml), ["x"=>cellml_ns(xml)])

"""
    get_connection_variables returns the pair of components for the given connection
    connection: an EzXML node
"""
function get_connection_components(xml::EzXML.Document, k)
    m = findfirst("x:map_components", k, ["x"=>cellml_ns(xml)])
    m["component_1"], m["component_2"]
end

"""
    get_connection_variables returns list composed of pairs of variable names
    for the given connection
    connection: an EzXML node
"""
function get_connection_variables(xml::EzXML.Document, connection)
    vs = findall("x:map_variables", connection, ["x"=>cellml_ns(xml)])
    [(v["variable_1"], v["variable_2"]) for v in vs]
end

"""
    list_state_names returns the names of variables that occur on the left-hand-side
    of an ODE; hence are *state* variables
"""
function list_state_names(xml::EzXML.Document, comp)
    nodes = findall("//x:component[@name='$comp']/y:math/y:apply", root(xml),
                    ["x"=>cellml_ns(xml), "y"=>mathml_ns])
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
"""
function find_alg_names(xml::EzXML.Document, comp)
    nodes = findall("//x:component[@name='$comp']/y:math/y:apply", root(xml),
                    ["x"=>cellml_ns(xml), "y"=>mathml_ns])
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
    list_component_math returns a list of math elements (as EzXML.Node) in the
    given component
"""
function list_component_math(xml::EzXML.Document, comp)
    findall("//x:component[@name='$comp']/y:math", root(xml),
            ["x"=>cellml_ns(xml), "y"=>mathml_ns])
end

list_import_nodes(xml::EzXML.Document) = findall("//x:import", root(xml), ["x"=>cellml_ns(xml)])

list_import_component_nodes(xml::EzXML.Document, n) = findall("//x:import/x:component", n, ["x"=>cellml_ns(xml)])
