struct Var
    comp::Symbol
    var::Symbol
end

struct Component
    name::Symbol
    node::EzXML.Node
    deps::Set{Symbol}
end

nameof(comp::Component) = comp.name

struct Connection
    comp_1::Symbol
    comp_2::Symbol
    vars::Array{Pair{Var}}
end

components(conn::Connection) = (conn.comp_1, conn.comp_2)
variables(conn::Connection) = conn.vars

struct Document
    path::AbstractString
    xmls::Array{EzXML.Document}
    comps::Array{Component}
    conns::Array{Connection}
end

components(doc::Document) = doc.comps
connections(doc::Document) = doc.conns

struct CellModel
    doc::Document
    sys::System
end
