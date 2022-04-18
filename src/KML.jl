module KML


using GeoInterface
using OrderedCollections: OrderedDict
using AbstractTrees
using XML
import XML: Element

#-----------------------------------------------------------------------------# utils
const current_id = Ref(0)
const INDENT = "    "

next_id() = "ID_$(current_id[] += 1)"

#-----------------------------------------------------------------------------# ObjectAttributes
Base.@kwdef mutable struct ObjectAttributes
    id::Union{Nothing, String} = nothing
    targetId::Union{Nothing, String} = nothing
end
function Base.show(io::IO, o::ObjectAttributes)
    !isnothing(o.id) && print(io, ' ', "id=", '"', o.id, '"')
    !isnothing(o.targetId) && print(io, ' ', "id=", '"', o.targetId, '"')
end

#-----------------------------------------------------------------------------# FeatureElements
# the `feature` field of every `AbstractFeature`
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
function Base.show(io::IO, f::FeatureElements; depth=0)
    indent = INDENT ^ depth
    for field in fieldnames(FeatureElements)
        val = getfield(f, field)
        if !isnothing(val)
            println(io)
            print(io, indent, '<', field, '>')
            print(io, to_xml(val))
            print(io, "</", field, '>')
        end
    end
end

to_xml(val) = val
to_xml(val::Bool) = Int(val)
to_xml(val::Vector{Float64}) = join(val, ", ")
to_xml(val::Enum) = replace(string(val), "KML." => "")

#-----------------------------------------------------------------------------# types and printing
abstract type AbstractObject end

abstract type AbstractFeature <: AbstractObject end
abstract type AbstractContainer <: AbstractFeature end

abstract type AbstractGeometry <: AbstractObject end



tag(o::T) where {T <: AbstractObject} = replace(string(T), "KML." => "")

function print_opening_tag(io::IO, o::T; depth=0) where {T<:AbstractObject}
    print(io, INDENT ^ depth, '<', tag(o))
    show(io, o.attributes)
    print(io, '>')
end

print_closing_tag(io::IO, o::T; depth=0) where {T} = print(io, INDENT^depth, "</", tag(o), '>')

function Base.show(io::IO, o::AbstractObject; depth=0)
    print_opening_tag(io, o; depth)
    for child in children(o)
        println(io)
        show(io, child; depth = depth+1)
    end
    print_closing_tag(io, o; depth)
end

#-----------------------------------------------------------------------------# Document
Base.@kwdef mutable struct Document <: AbstractContainer
    attributes::ObjectAttributes = ObjectAttributes()
    feature::FeatureElements = FeatureElements()
    style_children::Vector = []
    feature_children::Vector{AbstractFeature} = []
end
children(o::Document) = (o.feature, o.style_children..., o.feature_children...)

#-----------------------------------------------------------------------------# Folder
Base.@kwdef mutable struct Folder <: AbstractContainer
    attributes::ObjectAttributes = ObjectAttributes()
    feature::FeatureElements = FeatureElements()
    children::Vector{AbstractFeature} = []
end
children(o::Folder) = (o.feature, o.children...)

#-----------------------------------------------------------------------------# Placemark
Base.@kwdef mutable struct Placemark <: AbstractFeature
    attributes::ObjectAttributes = ObjectAttributes()
    feature::FeatureElements = FeatureElements()
    geometry::Union{Nothing, AbstractGeometry} = nothing
end
children(o::Placemark) = (o.feature, o.geometry)

#-----------------------------------------------------------------------------# Point
@enum ALTITUDEMODE clampToGround relativeToGround absolute relativeToSeaFloor clampToSeaFloor

Base.@kwdef mutable struct Point <: AbstractGeometry
    extrude::Bool = false
    altitudeMode::ALTITUDEMODE = clampToGround
    coordinates::Vector{Float64} = [0, 0]
end
function Base.show(io::IO, o::Point; depth=0)
    println(io, INDENT^depth, "<Point>")
    println(io, INDENT ^ (depth+1), "<extrude>", to_xml(o.extrude), "</extrude>")
    println(io, INDENT ^ (depth+1), "<altitudeMode>", to_xml(o.altitudeMode), "</altitudeMode>")
    println(io, INDENT ^ (depth+1), "<coordinates>", to_xml(o.coordinates), "</coordinates>")
    print(io, INDENT^depth, "</Point>")
end


# #-----------------------------------------------------------------------------# Validate
# module Validate
#     longitude(x) = (@assert -90 ≤ x ≤ 90; x)
#     latitude(x) = (@assert -180 ≤ x ≤ 180; x)

# end

# #-----------------------------------------------------------------------------# enums
# @enum altitudeMode clampToGround relativeToGround absolute
# @enum gx_altitudeMode clampToSeaFloor relativeToSeaFloor

# #-----------------------------------------------------------------------------# KMLElement
# abstract type KMLElement end
# abstract type KMLGeometry <: KMLElement end
# with_parents(o::KMLElement) = o

# Base.show(io::IO, o::KMLElement) = XML.showxml(io, Element(o))

# Base.@kwdef struct Attributes
#     id::Union{String, Nothing} = next_id()
#     targetId::Union{String, Nothing} = nothing
# end

# function Element(o::T) where {T <: KMLElement}
#     tag = replace(string(typeof(o)), "KML." => "")
#     attrs = OrderedDict{Symbol, String}()
#     !isnothing(o.attributes.id) && (attrs[:id] = o.attributes.id)
#     !isnothing(o.attributes.targetId) && (attrs[:targetId] = o.attributes.targetId)
#     children = map(setdiff(fieldnames(T), [:attributes])) do field
#         x = getfield(o, field)
#         x isa KMLElement ? Element(x) : XML.h(string(field), to_xml(x))
#     end
#     Element(tag, attrs, children)
# end

# to_xml(val) = string(val)
# to_xml(val::Bool) = string(val ? 1 : 0)
# to_xml(val::Vector) = join(val, ", ")


# #-----------------------------------------------------------------------------# FeatureElements
# Base.@kwdef mutable struct FeatureElements

# end

# #-----------------------------------------------------------------------------# Placemark
# Base.@kwdef struct Placemark <: KMLElement
#     attributes::Attributes = Attributes()
#     name::String = ""
#     visibility::Bool = true
#     geometry::Union{Nothing, KMLGeometry} = nothing
# end
# geometry(o::Placemark) = o.geometry


# #-----------------------------------------------------------------------------# Point
# Base.@kwdef struct Point <: KMLGeometry
#     attributes::Attributes = Attributes()
#     extrude::Bool = false
#     altitudeMode::Union{altitudeMode, gx_altitudeMode} = clampToGround
#     coordinates::Position = [0.0, 0.0]
# end
# with_parents(o::Point) = Placemark(geometry=o)

# #-----------------------------------------------------------------------------# template
# Base.@kwdef struct KMLDoc
#     prolog::Vector{Union{Comment, Declaration, DTD}} = [Declaration("xml", OrderedDict(:version=>"1.0", :encoding=>"UTF-8"))]
#     root::Element = XML.h("kml"; xmlns="http://www.opengis.net/kml/2.2", var"xmlns:gx"="http://www.google.com/kml/ext/2.2")
# end
# Base.show(io::IO, o::KMLDoc) = AbstractTrees.print_tree(io, o)
# AbstractTrees.printnode(io::IO, o::KMLDoc) = print(io, "KML.KMLDoc")

# AbstractTrees.children(o::KMLDoc) = (o.prolog..., o.root)

end
