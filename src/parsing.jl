function all_concrete_subtypes(T)
    types = subtypes(T)
    out = filter(isconcretetype, types)
    for S in filter(isabstracttype, types)
        append!(out, all_concrete_subtypes(S))
    end
    return out
end

function all_abstract_subtypes(T)
    types = filter(isabstracttype, subtypes(T))
    for t in types
        append!(types, all_abstract_subtypes(t))
    end
    types
end

object_types = all_concrete_subtypes(KMLElement)

tag2type = Dict(
    (replace(string(k), "KML." => "") => k for k in object_types)...,
    "outerBoundaryIs" => LinearRing,
)

#-----------------------------------------------------------------------------# field subsets
enum_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T,x)) <: Enums.AbstractKMLEnum, fieldnames(T))
element_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T, x)) <: KMLElement, fieldnames(T))
multi_element_fields(T) = filter(x -> Base.nonnothingtype(fieldtype(T,x)) <: Vector{<:KMLElement}, fieldnames(T))
parsed_fields(T) = setdiff(fieldnames(T), enum_fields(T), element_fields(T), multi_element_fields(T))

#-----------------------------------------------------------------------------# object
object(x::XML.Node) = object(tag2type[x.tag], x)

function object(::Type{T}, x::XML.Node) where {T<:KMLElement}
    o = T()
    for (k,v) in x.attributes
        FT = Base.nonnothingtype(fieldtype(T, k))
        if FT == String
            setfield!(o, Symbol(k), v)
        elseif FT in [Bool, Int, Float64]
            setfield!(o, Symbol(k), parse(FT, v))
        elseif FT <: Enums.AbstractKMLEnum
            setfield!(o, Symbol(k), FT(v))
        else
            error("$FT boo")
        end
    end
    isnothing(x.children) && return o
    for child in x.children
        tag = Symbol(child.tag)
        field = match_tag_to_fieldname(T, tag)
        FT = Base.nonnothingtype(fieldtype(T, field))
        if tag == :outerBoundaryIs
            o.outerBoundaryIs = object(child[1])
        elseif tag == :innerBoundaryIs
            o.innerBoundaryIs = object.(child.children)
        elseif field in enum_fields(T)
            setfield!(o, field, FT(child[1]))
        elseif field in element_fields(T)
            setfield!(o, field, object(child))
        elseif field in multi_element_fields(T)
            if isnothing(getfield(o, field))
                V = Base.nonnothingtype(fieldtype(T, field))
                setfield!(o, field, V())
            end
            push!(getfield(o, field), object(child))
        elseif field in parsed_fields(T)
            s = string(child[1])
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
    for field in element_fields(T)
        getproperty(KML, tag) <: getproperty(KML, field) && return field
    end
    for field in multi_element_fields(T)
        getproperty(KML, tag) <: eltype(Base.nonnothingtype(fieldtype(T, field))) && return field
    end
end

#-----------------------------------------------------------------------------# KMLFile
function KMLFile(path::AbstractString)
    doc = XML.readnode(path)
    i = findfirst(x -> x.tag == "kml", doc.children)
    isnothing(i) && error("No <kml> tag found in file.")
    KMLFile(map(object, doc.children[i].children))
end
