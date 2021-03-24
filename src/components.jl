


function left_hand_side(eqs, alg)
    lq = [arguments(eq.lhs)[1] for eq in eqs]
    la = [eq.lhs for eq in alg]
    union(lq, la)
end

function connections(xml, eqs, alg)
    a = []
    p = map(x -> string(first(x)), list_params(xml))
    l = string.(left_hand_side(eqs, alg))
    maps = findall("//x:map_variables", root(xml), ["x"=>cellml_ns(xml)])
    for m in maps
        var1 = m["variable_1"]
        var2 = m["variable_2"]
        if var1 != var2
            if var1 ∈ l && var2 ∉ l
                push!(a, create_var(var2) ~ create_var(var1))
                @info "accept connection: $var2 ~ $var1"
            elseif var1 ∉ l && var2 ∈ l
                push!(a, create_var(var1) ~ create_var(var2))
                @info "accept connection: $var1 ~ $var2"
            elseif var1 ∈ l && var2 ∈ l
                @warn "frustrated connection: $var1 ~ $var2"
            else
                if var1 ∈ p
                    push!(a, create_var(var2) ~ create_var(var1))
                    @info "accept connection: $var2 ~ param($var1)"
                elseif var2 ∈ p
                    push!(a, create_var(var1) ~ create_var(var2))
                    @info "accept connection: $var1 ~ param($var2)"
                else
                    @warn "dangling connection: $var1 ~ $var2"
                end
            end
        end
    end
    return a
end

function find_components(xml::EzXML.Document)
    comps = findall("//x:component", root(xml), ["x"=>cellml_ns(xml)])
    map(x -> x["name"], comps)
end

function find_component_variables(xml::EzXML.Document, comp)
    vars = findall("//x:component[@name='$comp']/x:variable", root(xml), ["x"=>cellml_ns(xml)])
    map(x -> x["name"], vars)
end

find_connections(xml::EzXML.Document) = findall("//x:connection", root(xml), ["x"=>cellml_ns(xml)])

function find_connection_components(xml::EzXML.Document, k)
    m = findfirst("x:map_components", k, ["x"=>cellml_ns(xml)])
    m["component_1"], m["component_2"]
end

function find_connection_variables(xml::EzXML.Document, k)
    vs = findall("x:map_variables", k, ["x"=>cellml_ns(xml)])
    [(v["variable_1"], v["variable_2"]) for v in vs]
end

function find_state_names(xml::EzXML.Document, comp)
    nodes = findall("//x:component[@name='$comp']/y:math/y:apply", root(xml), ["x"=>cellml_ns(xml), "y"=>mathml_ns])
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

function find_alg_names(xml::EzXML.Document, comp)
    nodes = findall("//x:component[@name='$comp']/y:math/y:apply", root(xml), ["x"=>cellml_ns(xml), "y"=>mathml_ns])
    names = String[]
    for n in nodes
        e = elements(n)
        if e[1].name == "eq" && e[2].name == "ci"
            push!(names, strip(nodecontent(e[2])))
        end
    end
    return names
end

function find_initiated_names(xml::EzXML.Document, comp)
    nodes = findall("//x:component[@name='$comp']/x:variable[@initial_value]", root(xml), ["x"=>cellml_ns(xml)])
    map(x -> x["name"], nodes)
end

################################################################################

struct Var
    comp::Symbol
    var::Symbol
end

make_var(c::AbstractString, v::AbstractString) = Var(Symbol(c), Symbol(v))

names_to_varset(comp, l) = Set([make_var(comp, x) for x in l])

function list_component_lhs(xml::EzXML.Document, comp)
    names_to_varset(comp, find_state_names(xml, comp)) ∪ names_to_varset(comp, find_alg_names(xml, comp))
    # ∪ names_to_varset(comp, find_initiated_names(xml, comp))
end

list_all_lhs(xml::EzXML.Document) = ∪([list_component_lhs(xml, c) for c in find_components(xml)]...)

function find_equivalence_groups(xml::EzXML.Document)
    groups = Dict{Var, Set{Var}}()

    for c in find_components(xml)
        for v in find_component_variables(xml, c)
            u = make_var(c, v)
            groups[u] = Set([u])
        end
    end

    for k in find_connections(xml)
        c1, c2 = find_connection_components(xml, k)
        for (v1,v2) in find_connection_variables(xml, k)
            u1 = make_var(c1, v1)
            u2 = make_var(c2, v2)
            s = groups[u1] ∪ groups[u2]
            for x in s
                groups[x] = s
            end
        end
    end

    return groups
end

function can_use_global_names(groups)
    s = Dict{Symbol, Set{Var}}()
    iv = Symbol(find_iv(xml))

    for g in groups
        v = first(g).var
        if v != iv && haskey(s, v) && s[v] != last(g)
            error("Conflict detected! cannot use global naming: $(first(g)) vs $(first(s[v]))")
        else
            s[v] = last(g)
        end
    end
end

function classify_variables(xml::EzXML.Document)
    groups = find_equivalence_groups(xml)
    lhs = list_all_lhs(xml)
    Dict{Var, Bool}(first(g) => (length(last(g) ∩ lhs) == 1) for g in groups)
end

function connections_global(xml::EzXML.Document)
    groups = find_equivalence_groups(xml)
    can_use_global_names(groups)
    lhs = list_all_lhs(xml)
    iv = find_iv(xml)

    a = []

    for g in groups
        var1 = string(first(g).var)
        s = [x for x in (last(g) ∩ lhs)]
        if length(s) == 1
            var2 = string(s[1].var)
            if var1 != var2
                push!(a, create_var(var1) ~ create_var(var2))
                @info "accept connection: $var1 ~ $var2"
            end
        elseif length(s) == 0
            if var1 != iv
                @warn "dangling variable: $var1"
            end
        else
            @warn "frustrated variable $var1: $s"
        end
    end

    return a
end

function connections(xml::EzXML.Document)
    a = []
    for k in find_connections(xml)
        c1, c2 = find_connection_components(xml, k)
        for w in find_connection_variables(xml, k)
            v1, v2 = w
            push!(a, (make_var(c1,v1), make_var(c2,v2)))
        end
    end
    return a
end

function translate_connections(systems, conns, class)
    a = []
    for c in conns
        v1, v2 = c

        if class[v1] && class[v2]
            sys1 = systems[v1.comp]
            sys2 = systems[v2.comp]

            if Symbol(sys1.iv) != v1.var
                #assert(Symbol(sys2.iv) != c[2].var)
                var1 = getproperty(sys1, c[1].var)
                var2 = getproperty(sys2, c[2].var)
                push!(a, var1 ~ var2)
            end
        end
    end
    return a
end


##############################################################################

component_lhs(xml::EzXML.Document, comp) = find_state_names(xml, comp) ∪ find_alg_names(xml, comp)
all_lhs(xml::EzXML.Document) = ∪([component_lhs(xml, c) for c in find_components(xml)]...)

function process_components(xml::EzXML.Document, iv=find_iv(xml); simplify=true)
    class = classify_variables(xml)
    systems = subsystems(xml, class, iv)
    l = translate_connections(systems, connections(xml), class)
    sys = ODESystem(l; systems=collect(values(systems)))
    if simplify
        sys = structural_simplify(sys)
    end
    return sys
end

function subsystems(xml::EzXML.Document, class, iv=find_iv(xml))
    names = find_components(xml)
    systems = Dict{Symbol,ODESystem}()

    for c in names
        sys = process_component(xml, c, class, iv)
        if sys != nothing
            systems[sys.name] = sys
        end
    end
    return systems
end

function list_substitution(xml, comp, class, iv=find_iv(xml))
    vars = find_component_variables(xml, comp)
    states = [create_var(x) => create_var(x, iv) for x in vars if class[make_var(comp,x)]]
    params = [create_var(x) => create_param(x) for x in vars if !class[make_var(comp,x)]]
    # params = [create_var(x) => create_param(x) for x in find_initiated_names(xml, comp) if x ∉ state_names]
    # [create_var(x) => create_var(x, iv) for x in vars if x != iv]

    return states ∪ params
end

function process_component(xml::EzXML.Document, comp, class, iv=find_iv(xml))
    math = findall("//x:component[@name='$comp']/y:math", root(xml), ["x"=>cellml_ns(xml), "y"=>mathml_ns])
    s = list_substitution(xml, comp, class, iv)
    if length(math) == 0
        eqs = Equation[]
    else
        eqs = vcat(parse_node.(math)...)
        eqs = [substitute(eq.lhs, s) ~ substitute(eq.rhs, s) for eq in eqs]
    end

    ivp = create_var(iv)
    ps = [Num(last(x)) for x in values(s) if last(x) isa Sym && Symbol(first(x)) != Symbol(iv)]
    states = [Num(last(x)) for x in values(s) if !(last(x) isa Sym)]
    sys = ODESystem(eqs, ivp, states, ps; name=Symbol(comp))
    # sys = ODESystem(eqs; name=Symbol(comp))
    return sys
end
