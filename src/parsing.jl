#-----------------------------------------------------------------------------# XML.Node ←→ KMLElement
typetag(T) = replace(string(T), r"([a-zA-Z]*\.)" => "", "_" => ":")
tuple2string(x) = replace(string(x), "), (" => "\n", "[(" => "", ")]" => "")

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
            push!(children, XML.Element("coordinates", tuple2string(val)))
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
        error("Not possible: $o with child $child")
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
        val = occursin('\n', x) ?
            eval.(Meta.parse.(split(x, '\n'))) :
            eval(Meta.parse(x))
        return setfield!(o, sym, val)
    end
    setfield!(o, sym, x)
end



# # tag2sym(x::String) = Symbol(replace(x, "gx:" => "gx_"))
# attribute_names(::Type{T}) where {names, T <: KMLElement{names}} = names

# function kml_type(o::Node)
#     sym = tag2sym(XML.tag(o))
#     sym in names(Enums, all=true) && return getproperty(Enums, sym)
#     sym in names(KML) && getproperty(KML, sym) <: Object && return getproperty(KML, sym)
#     sym == :outerBoundaryIs && return LinearRing

#     nothing
# end

# _parse(::Type{String}, s::String) = s
# _parse(::Type{T}, s::String) where {T<:Number} = parse(T, s)
# function _parse(::Type{T}, s::String) where {T<:Vector}
#     eval.(Meta.parse.(split(s)))
# end
# function _parse(::Type, s::String)
#     eval(Meta.parse(s))
# end



# #-----------------------------------------------------------------------------# add_element!
# struct SimpleNode
#     tag::String
#     val::String
# end

# function add_element!(o::KMLElement, node::Node)
#     tag = XML.tag(node)
#     sym = tag2sym(tag)
#     if sym in names(Enums, all=true)  # Case 1
#         T = getproperty(Enums, sym)
#         setfield!(o, sym, T(XML.value(only(node))))
#     elseif sym in names(KML)
#         child = object(node)
#         for (field, type) in typemap(typeof(o))
#             if typeof(child) <: type
#                 setfield!(o, field, child)  # Case 3
#             elseif type <: AbstractVector && typeof(child) <: eltype(type)
#                 if type isa Union
#                     setfield!(o, field, [child])  # 6
#                 else
#                     setfield!(o, field, eltype(type)[child])  # 4 and 5
#                 end
#             end
#         end
#     elseif sym == :outerBoundaryIs || sym == :innerBoundaryIs
#         setfield!(o, sym, object(only(node)))  # Case 7
#     elseif islowercase(tag[1])  # Case 2
#         setfield!(o, sym, _parse(typemap(o)[sym], XML.value(only(node))))
#     end
# end

# _eltype(x) = x
# _eltype(x::Union) = Union{eltype(getproperty(x,sym) for sym in propertynames(x))...}





# # function all_concrete_subtypes(T)
# #     types = subtypes(T)
# #     out = filter(isconcretetype, types)
# #     for S in filter(isabstracttype, types)
# #         append!(out, all_concrete_subtypes(S))
# #     end
# #     return out
# # end

# # function all_abstract_subtypes(T)
# #     types = filter(isabstracttype, subtypes(T))
# #     for t in types
# #         append!(types, all_abstract_subtypes(t))
# #     end
# #     types
# # end

# # object_types = all_concrete_subtypes(KMLElement)

# # tag2type = Dict(
# #     (replace(string(k), "KML." => "") => k for k in object_types)...,
# #     "outerBoundaryIs" => LinearRing,
# # )

# # #-----------------------------------------------------------------------------# field subsets
# # enum_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T,x)) <: Enums.AbstractKMLEnum, fieldnames(T))
# # element_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T, x)) <: KMLElement, fieldnames(T))
# # multi_element_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T,x)) <: Vector{<:KMLElement}, fieldnames(T))
# # parsed_fields(T) = setdiff(fieldnames(T), enum_fields(T), element_fields(T), multi_element_fields(T))

# # #-----------------------------------------------------------------------------# object
# # object(x::XML.Node) = object(tag2type[x.tag], x)

# # function object(::Type{T}, x::XML.Node) where {T<:KMLElement}
# #     o = T()
# #     !isnothing(x.attributes) && for (k,v) in x.attributes
# #         FT = Base.nonnothingtype(fieldtype(T, Symbol(k)))
# #         if FT == String
# #             setfield!(o, Symbol(k), v)
# #         elseif FT in [Bool, Int, Float64]
# #             setfield!(o, Symbol(k), parse(FT, v))
# #         elseif FT <: Enums.AbstractKMLEnum
# #             setfield!(o, Symbol(k), FT(v))
# #         else
# #             error("$FT boo")
# #         end
# #     end
# #     isnothing(x.children) && return o
# #     for child in x.children
# #         tag = Symbol(child.tag)
# #         field = match_tag_to_fieldname(T, tag)
# #         FT = Base.nonnothingtype(fieldtype(T, field))
# #         if tag == :outerBoundaryIs
# #             o.outerBoundaryIs = object(child[1])
# #         elseif tag == :innerBoundaryIs
# #             o.innerBoundaryIs = object.(child.children)
# #         elseif field in enum_fields(T)
# #             setfield!(o, field, FT(child[1]))
# #         elseif field in element_fields(T)
# #             setfield!(o, field, object(child))
# #         elseif field in multi_element_fields(T)
# #             if isnothing(getfield(o, field))
# #                 V = Base.nonnothingtype(fieldtype(T, field))
# #                 setfield!(o, field, V())
# #             end
# #             push!(getfield(o, field), object(child))
# #         elseif field in parsed_fields(T)
# #             s = child[1].value
# #             if String <: FT
# #                 setfield!(o, field, s)
# #             elseif Bool <: FT
# #                 setfield!(o, field, parse(Bool, s))
# #             elseif Int <: FT
# #                 setfield!(o, field, parse(Int, s))
# #             elseif Float64 <: FT
# #                 setfield!(o, field, parse(Float64, s))
# #             elseif Vector{NTuple{2, Float64}} <: FT || Vector{NTuple{3, Float64}} <: FT
# #                 val = Tuple.(map(x -> parse.(Float64,x), split.(split(s), ',')))
# #                 setfield!(o, field, val)
# #             end
# #         end
# #     end
# #     return o
# # end


# # function match_tag_to_fieldname(T, tag)
# #     tag in fieldnames(T) && return tag  # e.g. Point::Point
# #     for field in element_fields(T)
# #         getproperty(KML, tag) <: getproperty(KML, field) && return field  # e.g. Point::Geometry
# #     end
# #     for field in multi_element_fields(T)
# #         getproperty(KML, tag) <: eltype(Base.nonnothingtype(fieldtype(T, field))) && return field
# #     end
# # end

# # #-----------------------------------------------------------------------------# KMLFile
# # function KMLFile(path::AbstractString)
# #     doc = read(path, XML.Node)
# #     i = findfirst(x -> x.tag == "kml", doc.children)
# #     isnothing(i) && error("No <kml> tag found in file.")
# #     KMLFile(map(object, doc.children[i].children))
# # end
