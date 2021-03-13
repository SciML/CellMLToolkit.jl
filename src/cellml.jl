using EzXML

const cellml_ns = "http://www.cellml.org/cellml/1.0#"
const mathml_ns = "http://www.w3.org/1998/Math/MathML"

# list the name of the CellML variables (state variables + parameters)
function list_variables(xml)
    nodes = findall("//x:variable/@name", root(xml), ["x"=>cellml_ns])
    vars = nodecontent.(nodes)
    return unique(vars)
end

# list the name of the state variables, i.e., variables that occur on the left
# hand side of an assignment
function list_state_variables(xml)
    nodes = findall("//x:math//x:eq/following-sibling::x:apply[1]/x:ci", root(xml), ["x"=>mathml_ns])
    vars = nodecontent.(nodes)
    return unique(vars)
end

# find the unique independent variable
function find_iv(xml)
    nodes = findall("//x:math//x:bvar/x:ci", root(xml), ["x"=>mathml_ns])
    ivs = unique(nodecontent.(nodes))
    if length(ivs) > 1
        error("Only one independent variable (iv) is acceptable")
    end
    return ivs[1]
end

# list the name of all the parameters
function list_parameters(xml)
    vars = list_variables(xml)
    states = list_state_variables(xml)
    iv = find_iv(xml)
    params = filter(x -> x ∉ states && x != iv, vars)
    return params
end
