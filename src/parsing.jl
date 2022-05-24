function all_subtypes(T)
    types = subtypes(T)
    out = filter(isconcretetype, types)
    for S in filter(isabstracttype, types)
        append!(out, all_subtypes(S))
    end
    return out
end

object_types = all_subtypes(Object)

tag2type = Dict(
    (replace(string(k), "KML." => "") => k for k in object_types)...,
    "outerBoundaryIs" => LinearRing,
)

#-----------------------------------------------------------------------------# field subsets
enum_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T,x)) <: Enum, fieldnames(T))
object_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T, x)) <: Object, fieldnames(T))
multi_object_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T,x)) <: Vector{<:Object}, fieldnames(T))
parsed_fields(T) = setdiff(fieldnames(T), enum_fields(T), object_fields(T), multi_object_fields(T))

#-----------------------------------------------------------------------------# object
object(x::XML.Node) = object(tag2type[x.tag], x)

function object(::Type{T}, x::XML.Node) where {T<:Object}
    o = T()
    for child in x.children
        tag = Symbol(child.tag)
        field = match_tag_to_fieldname(T, tag)
        if tag == :outerBoundaryIs
            o.outerBoundaryIs = object(child.children[1])
        elseif tag == :innerBoundaryIs
            o.innerBoundaryIs = object.(child.children)
        elseif field in enum_fields(T)
            setfield!(o, field, getproperty(Enums, Symbol(child.children[1])))
        elseif field in object_fields(T)
            setfield!(o, field, object(child))
        elseif field in multi_object_fields(T)
            if isnothing(getfield(o, field))
                V = Base.nonnothingtype(fieldtype(T, field))
                setfield!(o, field, V())
            end
            push!(getfield(o, field), object(child))
        elseif field in parsed_fields(T)
            FT = Base.nonnothingtype(fieldtype(T, field))
            s = string(child.children[1])
            if String <: FT
                setfield!(o, field, s)
            elseif Bool <: FT
                setfield!(o, field, parse(Bool, s))
            elseif Int <: FT
                setfield!(o, field, parse(Int, s))
            elseif Float64 <: FT
                setfield!(o, field, parse(Float64, s))
            elseif Vector{NTuple{2, Float64}} <: FT || Vector{NTuple{3, Float64}} <: FT
                val = Tuple.(map(x -> parse.(Float64,x), split.(split(s), ',')))
                setfield!(o, field, val)
            end
        end
    end
    return o
end


function match_tag_to_fieldname(T, tag)
    tag in fieldnames(T) && return tag  # e.g. Point → Point
    for field in object_fields(T)
        getproperty(KML, tag) <: getproperty(KML, field) && return field
    end
    for field in multi_object_fields(T)
        getproperty(KML, tag) <: eltype(fieldtype(T, field)) && return field
    end
end

#-----------------------------------------------------------------------------# KMLFile
function KMLFile(path::AbstractString)
    doc = XML.readnode(path)
    i = findfirst(x -> x.tag == "kml", doc.children)
    KMLFile(map(object, doc.children[i].children))
end
