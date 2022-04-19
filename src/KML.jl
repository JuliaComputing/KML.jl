module KML

using OrderedCollections: OrderedDict
using AbstractTrees
import AbstractTrees: children
using XML
import XML: Element, showxml

#-----------------------------------------------------------------------------# utils
const current_id = Ref(0)
const INDENT = "    "

next_id() = "ID_$(current_id[] += 1)"

#-----------------------------------------------------------------------------# types
# - An AbstractObject has an `attributes::ObjectAttributes` field.
# - `children(o::AbstractObject)` returns an iterator of `XML.Element`s
# - A 0-arg constructor, e.g. `Document()`, must be defined.
abstract type AbstractObject end

# A "Feature" must have a `feature::FeatureElements` field.
abstract type AbstractFeature <: AbstractObject end
abstract type AbstractContainer <: AbstractFeature end

# "Geometry"
abstract type AbstractGeometry <: AbstractObject end

#-----------------------------------------------------------------------------# printing
# Each field inside an AbstractObject is either:
#   - `attributes::ObjectAttributes` (gets printed in opening tag)
#   - Is the name and value of an element, e.g. `extrude::Bool = true` → `<extrude>1</extrude>`
#   - Is an `AbstractObject` to be printed as `show(io, obj; depth)`

name(::Type{T}) where {T} = replace(string(T), "KML." => "")

function showxml(io::IO, o::T; depth=0) where {T<:AbstractObject}
    tag = name(T)
    print(io, INDENT ^ depth, '<')
    printstyled(io, tag, color=:light_cyan)
    !isnothing(o.attributes.id) && printstyled(io, ' ', "id=", repr(o.attributes.id); color=:light_green)
    !isnothing(o.attributes.targetId) && printstyled(io, ' ', "targetId=", repr(o.attributes.targetId); color=:light_green)
    println(io, '>')
    for child in children(o)
        showxml(io, child; depth = depth + 1)
    end
    print(io, INDENT ^ depth, "</")
    printstyled(io, tag, color=:light_cyan)
    print(io, '>')
end

function Element(o::T) where {T<:AbstractObject}
    Element(name(T), OrderedDict(o.attributes), collect(children(o)))
end

Base.show(io::IO, ::MIME"text/plain", o::AbstractObject) = showxml(io, o)

# Turn fields into Elements
#  - e.g. `extrude::Bool=true` → XML.h("extrude", "1")
#  - e.g. `outerBoundaryIs::LinearRing=LinearRing()` → `Element(outerBoundaryIs)`
function _children(o, fields...)
    out = Element[]
    for field in fields
        val = getfield(o, field)
        if val isa Union{Element, AbstractObject}
            push!(out, XML.h(string(field), Element(val)))
        elseif val isa Vector{<:AbstractObject}
            !isempty(val) && push!(out, XML.h(string(field), Element.(val)...))
        elseif !isnothing(val)
            push!(out, XML.h(string(field), xml_string(getfield(o,field))))
        end
    end
    return out
end

#-----------------------------------------------------------------------------# ObjectAttributes
"""
    ObjectAttributes(; id = nothing, targetId = nothing)

The `id` and `targetId` (both default to `nothing`) for a KML Object.
"""
Base.@kwdef mutable struct ObjectAttributes
    id::Union{Nothing, String} = nothing
    targetId::Union{Nothing, String} = nothing
end
function OrderedDict(o::ObjectAttributes)
    out = OrderedDict{Symbol,String}()
    !isnothing(o.id) && (out[:id] = o.id)
    !isnothing(o.targetId) && (out[:targetId] = o.targetId)
    return out
end
function ObjectAttributes(o::OrderedDict)
    out = ObjectAttributes()
    haskey(o, :id) && (out[:id] = o[:id])
    haskey(o, :targetId) && (out[:targetId] = o[:targetId])
    return out
end

#-----------------------------------------------------------------------------# FeatureElements
"""
    FeatureElements(; kw...)

The elements shared by every KML Feature (abstract type).  Options and their defaults:

- `name = nothing`
- `visibility = true`
- `open = false`
- `var"atom:author" = nothing`
- `var"atom:link" = nothing`
- `address = nothing`
- `var"xal:AddressDetails" = nothing`
- `phoneNumber = nothing`
- `description = nothing`
"""
Base.@kwdef mutable struct FeatureElements
    name::Union{Nothing, String} = nothing
    visibility::Bool = true
    open::Bool = false
    var"atom:author"::Union{Nothing, String} = nothing
    var"atom:link"::Union{Nothing, String} = nothing
    address::Union{Nothing, String} = nothing
    var"xal:AddressDetails"::Union{Nothing, String} = nothing
    phoneNumber::Union{Nothing,String} = nothing
    description::Union{Nothing, String} = nothing
    # TODO elements:
    # AbstractView
    # TimePrimitive
    # styleURL
    # StyleSelector
    # Region
    # ExtendedData
end
children(o::FeatureElements) = _children(o, fieldnames(FeatureElements)...)


#-----------------------------------------------------------------------------# Unknown
# If we don't know how to convert the `XML.Element`, dump it into here
Base.@kwdef mutable struct Unknown <: AbstractObject
    attributes::ObjectAttributes = ObjectAttributes()
    element::Union{Nothing,Element} = nothing
end
children(o::Unknown) = children(o.element)

#-----------------------------------------------------------------------------# Document
"""
    Document(; attributes, feature, style_children, feature_children)
"""
Base.@kwdef mutable struct Document <: AbstractContainer
    attributes::ObjectAttributes = ObjectAttributes()
    feature::FeatureElements = FeatureElements()
    style_children::Vector = []
    feature_children::Vector{AbstractFeature} = []
end
children(o::Document) = Iterators.flatten((
    children(o.feature),
    Iterators.map(Element, o.style_children),
    Iterators.map(Element, o.feature_children)
))

#-----------------------------------------------------------------------------# Folder
"""
    Folder(; attributes, feature, children)
"""
Base.@kwdef mutable struct Folder <: AbstractContainer
    attributes::ObjectAttributes = ObjectAttributes()
    feature::FeatureElements = FeatureElements()
    children::Vector{AbstractFeature} = []
end
children(o::Folder) = Iterators.flatten((children(o.feature), Iterators.map(Element,o.children)))

#-----------------------------------------------------------------------------# Placemark
"""
    Placemark(; attributes, feature, geometry)
"""
Base.@kwdef mutable struct Placemark <: AbstractFeature
    attributes::ObjectAttributes = ObjectAttributes()
    feature::FeatureElements = FeatureElements()
    geometry::Union{Nothing, AbstractGeometry} = nothing
end
function children(o::Placemark)
    out = children(o.feature)
    !isnothing(o.geometry) && push!(out, o.geometry)
    return out
end

#-----------------------------------------------------------------------------# Point
@enum ALTITUDEMODE clampToGround relativeToGround absolute relativeToSeaFloor clampToSeaFloor

"""
    Point(; attributes, extrude=false, altitudeMode=clampToGround, coordinates=[0.0, 0.0])
"""
Base.@kwdef mutable struct Point <: AbstractGeometry
    attributes::ObjectAttributes = ObjectAttributes()
    extrude::Bool = false
    altitudeMode::ALTITUDEMODE = clampToGround
    coordinates::Vector{Float64} = [0, 0]
end
children(o::Point) = _children(o, :extrude, :altitudeMode, :coordinates)


xml_string(x::Bool) = x ? "1" : "0"
xml_string(x::Vector{Float64}) = join(x, ",")
xml_string(x::Vector{Vector{Float64}}) = join(map(x -> join(x, ','), x), '\n')
xml_string(x::Enum) = string(x)
xml_string(x::String) = x

#-----------------------------------------------------------------------------# LineString
"""
    LineString(; attributes, extrude, tesselate, altitudeMode, coordinates)
"""
Base.@kwdef mutable struct LineString <: AbstractGeometry
    attributes::ObjectAttributes = ObjectAttributes()
    extrude::Bool = false
    tesselate::Bool = false
    altitudeMode::ALTITUDEMODE = clampToGround
    coordinates::Vector{Vector{Float64}} = [[0.0, 0.0]]
end
children(o::LineString) = _children(o, :extrude, :tesselate, :altitudeMode, :coordinates)


#-----------------------------------------------------------------------------# LinearRing
"""
    LinearRing(; attributes, altitudeOffset, extrude, altitudeMode, coordinates)
"""
Base.@kwdef mutable struct LinearRing <: AbstractGeometry
    attributes::ObjectAttributes = ObjectAttributes()
    altitudeOffset::Union{Nothing, Float64} = nothing
    extrude::Bool = false
    altitudeMode::ALTITUDEMODE = clampToGround
    coordinates::Vector{Vector{Float64}} = [[0, 0]]
end
children(o::LinearRing) = _children(o, :altitudeOffset, :extrude, :altitudeMode, :coordinates)

#-----------------------------------------------------------------------------# Polygon
"""
    Polygon(; attributes, altitudeOffset, extrude, altitudeMode, outerBoundaryIs, innerBoundaryIs)
"""
Base.@kwdef mutable struct Polygon <: AbstractGeometry
    attributes::ObjectAttributes = ObjectAttributes()
    extrude::Bool = false
    tesselate::Bool = false
    altitudeMode::ALTITUDEMODE = clampToGround
    outerBoundaryIs::LinearRing = LinearRing()
    innerBoundaryIs::Vector{LinearRing} = LinearRing[]
end
children(o::Polygon) = _children(o, :extrude, :altitudeMode, :outerBoundaryIs, :innerBoundaryIs)


#-----------------------------------------------------------------------------# MultiGeometry
Base.@kwdef mutable struct MultiGeometry <: AbstractGeometry
    attributes::ObjectAttributes = ObjectAttributes()
    geometries::Vector{AbstractGeometry} = AbstractGeometry[]
end
children(o::MultiGeometry) = o.geometries


#-----------------------------------------------------------------------------# KMLFile
Base.@kwdef mutable struct KMLFile
    prolog::Vector{Union{Comment, Declaration, DTD}} = [Declaration("xml", OrderedDict(:version=>"1.0", :encoding=>"UTF-8"))]
    root::Element = XML.h("kml"; xmlns="http://www.opengis.net/kml/2.2", var"xmlns:gx"="http://www.google.com/kml/ext/2.2")
end
Base.show(io::IO, o::KMLFile) = AbstractTrees.print_tree(io, o)
AbstractTrees.printnode(io::IO, o::KMLFile) = print(io, "KML.KMLFile")

AbstractTrees.children(o::KMLFile) = (o.prolog..., o.root)

#-----------------------------------------------------------------------------# "parsing"
function to_kml(o::XML.Document)
    f = KMLFile()
    f.prolog = o.prolog
    children(f.root)[:] = to_kml.(children(o.root))
    return f
end

tag2type = Dict(
    "Document" => Document,
    "Folder" => Folder,
    "Point" => Point,
    "LineString" => LineString,
    "Polygon" => Polygon,
    "MultiGeometry" => MultiGeometry
)

function to_kml(o::Element)
    t = XML.tag(o)
    out = get(tag2type, t, Unknown)()
    out.attributes = ObjectAttributes(XML.attributes(o))
    populate_elements!(out, o)
    out
end

function populate_elements!(f::FeatureElements, o::Element)
    c = children(o)
    for (tag, Type) in [(:name, String), (:visibility, Bool), (:open, Bool), (:var"atom:author", String),
                        (:var"atom:link", String), (:address, String), (:var"xal:AddressDetails", String),
                        (:phoneNumber, String), (:description, String)]
        x = filter(x -> XML.tag(x) == tag, c)
        if !isempty(x)
            child = x[1]
            setfield!(f, tag, parse(Type, children(child)[1]))
        end
    end
end

populate_elements!(init::Unknown, o::Element) = nothing

function populate_elements!(init::Document, o::Element)
    c = children(o)
    populate_elements!(init.feature, o)
    init.style_children = [Unknown(element=x) for x in filter(x -> XML.tag(x) == "Style", c)]
    init.feature_children = to_kml.(filter(x -> XML.tag(x) != "Style", c))
end

function populate_elements!(init, o::Element)
    @warn "don't know how to do this yet"
end

end
