#-----------------------------------------------------------------------------# XML.Node ←→ KMLElement
typetag(T) = replace(string(T), r"([a-zA-Z]*\.)" => "", "_" => ":")

coordinate_string(x::Tuple) = join(x, ',')
coordinate_string(x::Vector) = join(coordinate_string.(x), '\n')

# KMLElement → Node
Node(o::T) where {T<:Enums.AbstractKMLEnum} = XML.Element(typetag(T), o.value)

function Node(o::T) where {names, T <: KMLElement{names}}
    tag = typetag(T)
    attributes = Dict(string(k) => string(getfield(o, k)) for k in names if !isnothing(getfield(o, k)))
    element_fields = filter(x -> !isnothing(getfield(o,x)), setdiff(fieldnames(T), names))
    isempty(element_fields) && return XML.Node(XML.Element, tag, attributes)
    children = Node[]
    for field in element_fields
        val = getfield(o, field)
        if field == :innerBoundaryIs
            push!(children, XML.Element(:innerBoundaryIs, Node.(val)))
        elseif field == :outerBoundaryIs
            push!(children, XML.Element(:outerBoundaryIs, Node(val)))
        elseif field == :coordinates
            push!(children, XML.Element("coordinates", coordinate_string(val)))
        elseif val isa KMLElement
            push!(children, Node(val))
        elseif val isa Vector{<:KMLElement}
            append!(children, Node.(val))
        else
            push!(children, XML.Element(field, val))
        end
    end
    return XML.Node(XML.Element, tag, attributes, nothing, children)
end

#-----------------------------------------------------------------------------# object (or enum)
function object(node::Node)
    sym = tagsym(node)
    if sym in names(Enums, all=true)
        return getproperty(Enums, sym)(XML.value(only(node)))
    end
    if sym in names(KML) || sym == :Pair
        T = getproperty(KML, sym)
        o = T()
        add_attributes!(o, node)
        for child in XML.children(node)
            add_element!(o, child)
        end
        return o
    end
    nothing
end

function add_element!(o::Union{Object,KMLElement}, child::Node)
    sym = tagsym(child)
    o_child = object(child)

    if !isnothing(o_child)
        @goto child_is_object
    else
        @goto child_is_not_object
    end

    @label child_is_not_object
    return if sym == :outerBoundaryIs
        setfield!(o, :outerBoundaryIs, object(XML.only(child)))
    elseif sym == :innerBoundaryIs
        setfield!(o, :innerBoundaryIs, object.(XML.children(child)))
    elseif hasfield(typeof(o), sym) && XML.is_simple(child)
        autosetfield!(o, sym, XML.value(only(child)))
    else
        @warn "Unhandled case encountered while trying to add child with tag `$sym` to parent `$o`."
    end

    @label child_is_object
    T = typeof(o_child)

    for (field, FT) in typemap(o)
        T <: FT && return setfield!(o, field, o_child)
        if FT <: AbstractVector && T <: eltype(FT)
            v = getfield(o, field)
            if isnothing(v)
                setfield!(o, field, eltype(FT)[])
            end
            push!(getfield(o, field), o_child)
            return
        end
    end
    error("This was not handled: $o_child")
end


tagsym(x::String) = Symbol(replace(x, ':' => '_'))
tagsym(x::Node) = tagsym(XML.tag(x))

function add_attributes!(o::Union{Object,KMLElement}, source::Node)
    attr = XML.attributes(source)
    !isnothing(attr) && for (k,v) in attr
        autosetfield!(o, tagsym(k), v)
    end
end

function autosetfield!(o::Union{Object,KMLElement}, sym::Symbol, x::String)
    T = typemap(o)[sym]
    T <: Number && return setfield!(o, sym, parse(T, x))
    T <: AbstractString && return setfield!(o, sym, x)
    T <: Enums.AbstractKMLEnum && return setfield!(o, sym, T(x))
    if sym == :coordinates
        val = [Tuple(parse.(Float64, split(v, ','))) for v in split(x)]
        # coordinates can be a tuple or a vector of tuples, so we need to do this:
        if fieldtype(typeof(o), sym) <: Union{Nothing, Tuple}
            val = val[1]
        end
        return setfield!(o, sym, val)
    end
    setfield!(o, sym, x)
end
