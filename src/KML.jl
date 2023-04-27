module KML

using OrderedCollections: OrderedDict
using GeoInterface: GeoInterface
import XML: XML, Node
using InteractiveUtils: subtypes

#----------------------------------------------------------------------------# utils
const INDENT = "  "

macro def(name, definition)
    return quote
        macro $(esc(name))()
            esc($(Expr(:quote, definition)))
        end
    end
end

@def altitude_mode_elements begin
    altitudeMode::Union{Nothing, Enums.altitudeMode} = nothing
    gx_altitudeMode::Union{Nothing, Enums.gx_altitudeMode} = nothing
end

# @option field::Type → field::Union{Nothing, Type} = nothing
macro option(expr)
    expr.head == :(::) || error("@default only works on type annotations e.g. `field::Type`")
    expr.args[2] = Expr(:curly, :Union, :Nothing, expr.args[2])
    return esc(Expr(:(=), expr, :nothing))
end

# Same as `@option` but prints a warning.
macro required(expr)
    expr.head == :(::) || error("@required only works on type annotations e.g. `field::Type`")
    expr.args[2] = Expr(:curly, :Union, :Nothing, expr.args[2])
    warning = "Field :$(expr.args[1]) is required by KML spec but has been initialized as `nothing`."
    return esc(Expr(:(=), expr, :(@warn($warning))))
end

name(T::Type) = replace(string(T), r"([a-zA-Z]*\.)" => "")
name(o) = name(typeof(o))

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

#-----------------------------------------------------------------------------# KMLElement
# `attr_names` fields print as attributes, everything else as an element
abstract type KMLElement{attr_names} <: XML.AbstractXMLNode end

const NoAttributes = KMLElement{()}

function Base.show(io::IO, o::T) where {names, T <: KMLElement{names}}
    printstyled(io, T; color=:light_cyan)
    print(io, ": [")
    show(io, Node(o))
    print(io, ']')
end

# XML Interface
XML.tag(o::KMLElement) = name(o)

function XML.attributes(o::T) where {names, T <: KMLElement{names}}
    Dict(k => getfield(o, k) for k in names if !isnothing(getfield(o, k)))
end

XML.children(o::KMLElement) = XML.children(Node(o))

typemap(o) = typemap(typeof(o))
function typemap(::Type{T}) where {T<:KMLElement}
    Dict(name => Base.nonnothingtype(S) for (name, S) in zip(fieldnames(T), fieldtypes(T)))
end

Base.:(==)(a::T, b::T) where {T<:KMLElement} = all(getfield(a,f) == getfield(b,f) for f in fieldnames(T))


#-----------------------------------------------------------------------------# "Enums"
module Enums
import ..NoAttributes, ..name
using XML

abstract type AbstractKMLEnum <: NoAttributes end

Base.show(io::IO, o::AbstractKMLEnum) = print(io, typeof(o), ": ", repr(o.value))
Base.convert(::Type{T}, x::String) where {T<:AbstractKMLEnum} = T(x)
Base.string(o::AbstractKMLEnum) = o.value

macro kml_enum(T, vals...)
    esc(quote
        struct $T <: AbstractKMLEnum
            value::String
            function $T(value)
                string(value) ∈ $(string.(vals)) || error($(string(T)) * " ∉ " * join($vals, ", ") * ". Found: " * string(value))
                new(string(value))
            end
        end
    end)
end
@kml_enum altitudeMode clampToGround relativeToGround absolute
@kml_enum gx_altitudeMode relativeToSeaFloor clampToSeaFloor
@kml_enum refreshMode onChange onInterval onExpire
@kml_enum viewRefreshMode never onStop onRequest onRegion
@kml_enum shape rectangle cylinder sphere
@kml_enum gridOrigin lowerLeft upperLeft
@kml_enum displayMode default hide
@kml_enum listItemType check checkOffOnly checkHideChildren radioFolder
@kml_enum units fraction pixels insetPixels
@kml_enum itemIconState open closed error fetching0 fetching1 fetching2
@kml_enum styleState normal highlight
@kml_enum colorMode normal random
@kml_enum flyToMode smooth bounce
end

#-----------------------------------------------------------------------------# KMLFile
mutable struct KMLFile
    children::Vector{Union{Node, KMLElement}}  # Union with XML.Node to allow Comment and CData
end
KMLFile(content::KMLElement...) = KMLFile(collect(content))

Base.push!(o::KMLFile, el::Union{Node, KMLElement}) = push!(o.children, el)

# TODO: print better summary of file
function Base.show(io::IO, o::KMLFile)
    print(io, "KMLFile ")
    printstyled(io, '(', Base.format_bytes(Base.summarysize(o)), ')'; color=:light_black)
end

function Node(o::KMLFile)
    children = [
        Node(XML.Declaration, nothing, Dict("version" => "1.0", "encoding" => "UTF-8")),
        Node(XML.Element, "kml", Dict("xmlns" => "http://earth.google.com/kml/2.2"), nothing, Node.(o.children))
    ]
    Node(XML.Document, nothing, nothing, nothing, children)
end


Base.:(==)(a::KMLFile, b::KMLFile) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(KMLFile))

# read
Base.read(io::IO, ::Type{KMLFile}) = KMLFile(read(io, XML.Node))
Base.read(filename::AbstractString, ::Type{KMLFile}) = KMLFile(read(filename, XML.Node))
function KMLFile(doc::XML.Node)
    i = findfirst(x -> x.tag == "kml", XML.children(doc))
    isnothing(i) && error("No <kml> tag found in file.")
    KMLFile(map(object, XML.children(doc[i])))
end

Writable = Union{KMLFile, KMLElement, Node}

write(io::IO, o::Writable; kw...) = XML.write(io, Node(o); kw...)
write(file::AbstractString, o::Writable; kw...) = XML.write(file, Node(o); kw...)
write(o::Writable; kw...) = XML.write(Node(o); kw...)

#-----------------------------------------------------------------------------# Object
abstract type Object <: KMLElement{(:id, :targetId)} end

abstract type Feature <: Object end
abstract type Overlay <: Feature end
abstract type Container <: Feature end

abstract type Geometry <: Object end
GeoInterface.isgeometry(o::Geometry) = true

abstract type StyleSelector <: Object end

abstract type TimePrimitive <: Object end

abstract type AbstractView <: Object end

abstract type SubStyle <: Object end
abstract type ColorStyle <: SubStyle end

abstract type gx_TourPrimitive <: Object end


#-===========================================================================-# Immediate Subtypes of Object
@def object begin
    @option id::String
    @option targetId::String
end

#-----------------------------------------------------------------------------# Link <: Object
Base.@kwdef mutable struct Link <: Object
    @object
    @option href::String
    @option refreshMode::Enums.refreshMode
    @option refreshInterval::Float64
    @option viewRefreshMode::Enums.viewRefreshMode
    @option viewRefreshTime::Float64
    @option viewBoundScale::Float64
    @option viewFormat::String
    @option httpQuery::String
end
#-----------------------------------------------------------------------------# Icon <: Object
Base.@kwdef mutable struct Icon <: Object
    @object
    @option href::String
    @option refreshMode::Enums.refreshMode
    @option refreshInterval::Float64
    @option viewRefreshMode::Enums.viewRefreshMode
    @option viewRefreshTime::Float64
    @option viewBoundScale::Float64
    @option viewFormat::String
    @option httpQuery::String
end
#-----------------------------------------------------------------------------# Orientation <: Object
Base.@kwdef mutable struct Orientation <: Object
    @object
    @option heading::Float64
    @option tilt::Float64
    @option roll::Float64
end
#-----------------------------------------------------------------------------# Location <: Object
Base.@kwdef mutable struct Location <: Object
    @object
    @option longitude::Float64
    @option latitude::Float64
    @option altitude::Float64
end
#-----------------------------------------------------------------------------# Scale <: Object
Base.@kwdef mutable struct Scale <: Object
    @object
    @option x::Float64
    @option y::Float64
    @option z::Float64
end
#-----------------------------------------------------------------------------# Lod <: Object
Base.@kwdef mutable struct Lod <: Object
    @object
    minLodPixels::Int = 128
    @option maxLodPixels::Int
    @option minFadeExtent::Int
    @option maxFadeExtent::Int
end
#-----------------------------------------------------------------------------# LatLonBox <: Object
Base.@kwdef mutable struct LatLonBox <: Object
    @object
    north::Float64 = 0
    south::Float64 = 0
    east::Float64 = 0
    west::Float64 = 0
    @option rotation::Float64
end
#-----------------------------------------------------------------------------# LatLonAltBox <: Object
Base.@kwdef mutable struct LatLonAltBox <: Object
    @object
    north::Float64 = 0
    south::Float64 = 0
    east::Float64 = 0
    west::Float64 = 0
    @option minAltitude::Float64
    @option maxAltitude::Float64
    @altitude_mode_elements
end
#-----------------------------------------------------------------------------# Region <: Object
Base.@kwdef mutable struct Region <: Object
    @object
    LatLonAltBox::LatLonAltBox = LatLonAltBox(north=0,south=0,east=0,west=0)
    @option Lod::Lod
end
#-----------------------------------------------------------------------------# gx_LatLonQuad <: Object
Base.@kwdef mutable struct gx_LatLonQuad <: Object
    @object
    coordinates::Vector{NTuple{2, Float64}} = [(0,0), (0,0), (0,0), (0,0)]
    gx_LatLonQuad(id, targetId, coordinates) = (@assert length(coordinates) == 4; new(id, targetId, coordinates))
end
#-----------------------------------------------------------------------------# gx_Playlist <: Object
Base.@kwdef mutable struct gx_Playlist
    @object
    gx_TourPrimitives::Vector{gx_TourPrimitive} = []
end

#-===========================================================================-# Things that don't quite conform
#-----------------------------------------------------------------------------# Snippet
Base.@kwdef mutable struct Snippet <: KMLElement{(:maxLines,)}
    content::String = ""
    maxLines::Int = 2
end
showxml(io::IO, o::Snippet) = printstyled(io, "<Snippet maxLines=", repr(o.maxLines), '>', o.content, "</Snippet>", color=:light_yellow)
#-----------------------------------------------------------------------------# ExtendedData
# TODO: Support ExtendedData.  This currently prints incorrectly.
Base.@kwdef mutable struct ExtendedData <: NoAttributes
    @required children::Vector{Any}
end


#-===========================================================================-# Features
@def feature begin
    @object
    @option name::String
    @option visibility::Bool
    @option open::Bool
    @option atom_author::String
    @option atom_link::String
    @option address::String
    @option xal_AddressDetails::String
    @option phoneNumber::String
    @option Snippet::Snippet
    @option description::String
    @option AbstractView::AbstractView
    @option TimePrimitive::TimePrimitive
    @option styleUrl::String
    @option StyleSelectors::Vector{StyleSelector}
    @option Region::Region
    @option ExtendedData::ExtendedData
end
#-----------------------------------------------------------------------------# gx_Tour <: Feature
Base.@kwdef mutable struct gx_Tour <: Feature
    @feature
    @option gx_Playlist::gx_Playlist
end
#-----------------------------------------------------------------------------# NetworkLink <: Feature
Base.@kwdef mutable struct NetworkLink <: Feature
    @feature
    @option refreshVisibility::Bool
    @option flyToView::Bool
    Link::Link = Link()
end
#-----------------------------------------------------------------------------# Placemark <: Feature
Base.@kwdef mutable struct Placemark <: Feature
    @feature
    @option Geometry::Geometry
end
GeoInterface.isfeature(o::Type{Placemark}) = true
GeoInterface.trait(o::Placemark) = GeoInterface.FeatureTrait()
GeoInterface.properties(o::Placemark) = NamedTuple(Dict(f => getfield(o,f) for f in setdiff(fieldnames(Placemark), [:Geometry])))
GeoInterface.geometry(o::Placemark) = o.Geometry


#-===========================================================================-# Geometries
#-----------------------------------------------------------------------------# Point <: Geometry
Base.@kwdef mutable struct Point <: Geometry
    @object
    @option extrude::Bool
    @altitude_mode_elements
    @option coordinates::Union{NTuple{2, Float64}, NTuple{3, Float64}}
end
GeoInterface.geomtrait(o::Point) = GeoInterface.PointTrait()
GeoInterface.ncoord(::GeoInterface.PointTrait, o::Point) = length(o.coordinates)
GeoInterface.getcoord(::GeoInterface.PointTrait, o::Point, i) = o.coordinates[i]

#-----------------------------------------------------------------------------# LineString <: Geometry
Base.@kwdef mutable struct LineString <: Geometry
    @object
    @option gx_altitudeOffset::Float64
    @option extrude::Bool
    @option tessellate::Bool
    @altitude_mode_elements
    @option gx_drawOrder::Int
    @option coordinates::Union{Vector{NTuple{2, Float64}}, Vector{NTuple{3, Float64}}}
end
GeoInterface.geomtrait(::LineString) = GeoInterface.LineStringTrait()
GeoInterface.ngeom(::GeoInterface.LineStringTrait, o::LineString) = length(o.coordinates)
GeoInterface.getgeom(::GeoInterface.LineStringTrait, o::LineString, i) = Point(coordinates=o.coordinates[i])

#-----------------------------------------------------------------------------# LinearRing <: Geometry
Base.@kwdef mutable struct LinearRing <: Geometry
    @object
    @option gx_altitudeOffset::Float64
    @option extrude::Bool
    @option tessellate::Bool
    @altitude_mode_elements
    @option coordinates::Union{Vector{NTuple{2, Float64}}, Vector{NTuple{3, Float64}}}
end
GeoInterface.geomtrait(::LinearRing) = GeoInterface.LinearRingTrait()
GeoInterface.ngeom(::GeoInterface.LinearRingTrait, o::LinearRing) = length(o.coordinates)
GeoInterface.getgeom(::GeoInterface.LinearRingTrait, o::LinearRing, i) = Point(coordinates=o.coordinates[i])

#-----------------------------------------------------------------------------# Polygon <: Geometry
Base.@kwdef mutable struct Polygon <: Geometry
    @object
    @option extrude::Bool
    @option tessellate::Bool
    @altitude_mode_elements
    outerBoundaryIs::LinearRing = LinearRing()
    @option innerBoundaryIs::Vector{LinearRing}
end
GeoInterface.geomtrait(o::Polygon) = GeoInterface.PolygonTrait()
GeoInterface.ngeom(::GeoInterface.PolygonTrait, o::Polygon) = 1 + length(o.innerBoundaryIs)
GeoInterface.getgeom(::GeoInterface.PolygonTrait, o::Polygon, i) = i == 1 ? o.outerBoundaryIs : o.innerBoundaryIs[i-1]

#-----------------------------------------------------------------------------# MultiGeometry <: Geometry
Base.@kwdef mutable struct MultiGeometry <: Geometry
    @object
    @option Geometries::Vector{Geometry}
end
GeoInterface.geomtrait(geom::MultiGeometry) = GeoInterface.GeometryCollectionTrait()
GeoInterface.ncoord(::GeoInterface.GeometryCollectionTrait, geom::MultiGeometry) = GeoInterface.ncoord(first(o.Geometries))
GeoInterface.ngeom(::GeoInterface.GeometryCollectionTrait, geom::MultiGeometry) = length(o.Geometries)
GeoInterface.getgeom(::GeoInterface.GeometryCollectionTrait, geom::MultiGeometry, i) = o.Geometries[i]

#-----------------------------------------------------------------------------# Model <: Geometry
Base.@kwdef mutable struct Alias <: NoAttributes
    @option targetHref::String
    @option sourceHref::String
end
Base.@kwdef mutable struct ResourceMap <: NoAttributes
    @option Aliases::Vector{Alias}
end
Base.@kwdef mutable struct Model <: Geometry
    @object
    @altitude_mode_elements
    @option Location::Location
    @option Orientation::Orientation
    @option Scale::Scale
    @option Link::Link
    @option ResourceMap::ResourceMap
end
GeoInterface.isgeometry(::Type{Model}) = false
#-----------------------------------------------------------------------------# gx_Track <: Geometry
Base.@kwdef mutable struct gx_Track <: Geometry
    @object
    @altitude_mode_elements
    @option when::String
    @option gx_coord::String
    @option gx_angles::String
    @option Model::Model
    @option ExtendedData::ExtendedData
end
GeoInterface.isgeometry(::Type{gx_Track}) = false
#-----------------------------------------------------------------------------# gx_MultiTrack <: Geometry
Base.@kwdef mutable struct gx_MultiTrack
    @object
    @altitude_mode_elements
    @option gx_interpolate::Bool
    @option gx_Track::Vector{gx_Track}
end


#-===========================================================================-# Overlays
@def overlay begin
    @feature
    @option color::String
    @option drawOrder::Int
    @option Icon::Icon
end

#-----------------------------------------------------------------------------# PhotoOverlay <: Overlay
Base.@kwdef mutable struct ViewVolume <: NoAttributes
    @option leftFov::Float64
    @option rightFov::Float64
    @option bottomFov::Float64
    @option topFov::Float64
    @option near::Float64
end
Base.@kwdef mutable struct ImagePyramid <: NoAttributes
    @option tileSize::Int
    @option maxWidth::Int
    @option maxHeight::Int
    @option gridOrigin::Enums.gridOrigin
end
Base.@kwdef mutable struct PhotoOverlay <: Overlay
    @overlay
    @option rotation::Float64
    @option ViewVolume::ViewVolume
    @option ImagePyramid::ImagePyramid
    @option Point::Point
    @option shape::Enums.shape
end
#-----------------------------------------------------------------------------# ScreenOverlay <: Overlay
Base.@kwdef mutable struct overlayXY <: KMLElement{(:x, :y, :xunits, :yunits)}
    x::Float64 = 0.5
    y::Float64 = 0.5
    xunits::Enums.units = "fraction"
    yunits::Enums.units = "fraction"
end
Base.@kwdef mutable struct screenXY <: KMLElement{(:x, :y, :xunits, :yunits)}
    x::Float64 = 0.5
    y::Float64 = 0.5
    xunits::Enums.units = "fraction"
    yunits::Enums.units = "fraction"
end
Base.@kwdef mutable struct rotationXY <: KMLElement{(:x, :y, :xunits, :yunits)}
    x::Float64 = 0.5
    y::Float64 = 0.5
    xunits::Enums.units = "fraction"
    yunits::Enums.units = "fraction"
end
Base.@kwdef mutable struct size <: KMLElement{(:x, :y, :xunits, :yunits)}
    x::Float64 = 0.5
    y::Float64 = 0.5
    xunits::Enums.units = "fraction"
    yunits::Enums.units = "fraction"
end
Base.@kwdef mutable struct ScreenOverlay <: Overlay
    @overlay
    overlayXY::overlayXY = overlayXY()
    screenXY::screenXY = screenXY()
    rotationXY::rotationXY = rotationXY()
    size::size = size()
    rotation::Float64 = 0.0
end
#-----------------------------------------------------------------------------# GroundOverlay <: Overlay
Base.@kwdef mutable struct GroundOverlay <: Overlay
    @overlay
    @option altitude::Float64
    @altitude_mode_elements
    @option LatLonBox::LatLonBox
    @option GXLatLonQuad::gx_LatLonQuad
end



#-===========================================================================-# SubStyles
#-----------------------------------------------------------------------------# BalloonStyle <: SubStyle
Base.@kwdef mutable struct BalloonStyle <: SubStyle
    @object
    @option bgColor::String
    @option textColor::String
    @option text::String
    @option displayMode::Enums.displayMode
end
#-----------------------------------------------------------------------------# ListStyle <: SubStyle
Base.@kwdef mutable struct ItemIcon <: KMLElement{()}
    @option state::Enums.styleState
    @option href::String
end
Base.@kwdef mutable struct ListStyle <: SubStyle
    @object
    @option listItemType::Symbol
    @option bgColor::String
    @option ItemIcons::Vector{ItemIcon}
end

#-===========================================================================-# ColorStyles
@def colorstyle begin
    @object
    @option color::String
    @option colorMode::Enums.colorMode
end
#-----------------------------------------------------------------------------# LineStyle <: ColorStyle
Base.@kwdef mutable struct LineStyle <: ColorStyle
    @colorstyle
    @option width::Float64
    @option gx_outerColor::String
    @option gx_outerWidth::Float64
    @option gx_physicalWidth::Float64
    @option gx_labelVisibility::Bool
end
#-----------------------------------------------------------------------------# PolyStyle <: ColorStyle
Base.@kwdef mutable struct PolyStyle <: ColorStyle
    @colorstyle
    @option fill::Bool
    @option outline::Bool
end
#-----------------------------------------------------------------------------# IconStyle
Base.@kwdef mutable struct hotSpot <: KMLElement{(:x, :y, :xunits, :yunits)}
    @option x::Float64
    @option y::Float64
    @option xunits::Enums.units
    @option yunits::Enums.units
end
Base.@kwdef mutable struct IconStyle <: ColorStyle
    @colorstyle
    @option scale::Float64
    @option heading::Float64
    @option Icon::Icon
    @option hotSpot::hotSpot
end
#-----------------------------------------------------------------------------# LabelStyle
Base.@kwdef mutable struct LabelStyle <: ColorStyle
    @colorstyle
    @option scale::Float64
end


#-===========================================================================-# StyleSelectors
# These need to come before Containers since `Document` holds `Style`s
#-----------------------------------------------------------------------------# Style <: StyleSelector
Base.@kwdef mutable struct Style <: StyleSelector
    @object
    @option IconStyle::IconStyle
    @option LabelStyle::LabelStyle
    @option LineStyle::LineStyle
    @option PolyStyle::PolyStyle
    @option BalloonStyle::BalloonStyle
    @option ListStyle::ListStyle
end
#-----------------------------------------------------------------------------# StyleMap <: StyleSelector
Base.@kwdef mutable struct Pair <: Object
    @object
    @option key::Enums.styleState
    @option styleUrl::String
    @option Style::Style
end

Base.@kwdef mutable struct StyleMap <: StyleSelector
    @object
    @option Pairs::Vector{Pair}
end


#-===========================================================================-# Containers
#-----------------------------------------------------------------------------# Folder <: Container
Base.@kwdef mutable struct Folder <: Container
    @feature
    @option Features::Vector{Feature}
end
#-----------------------------------------------------------------------------# Document <: Container
Base.@kwdef mutable struct SimpleField <: KMLElement{(:type, :name)}
    type::String
    name::String
    @option displayName::String
end
Base.@kwdef mutable struct Schema <: KMLElement{(:id,)}
    id::String
    @option SimpleFields::Vector{SimpleField}
end
Base.@kwdef mutable struct Document <: Container
    @feature
    @option Schemas::Vector{Schema}
    @option Features::Vector{Feature}
end




#-===========================================================================-# gx_TourPrimitives
#-----------------------------------------------------------------------------# gx_AnimatedUpdate
Base.@kwdef mutable struct Change <: KMLElement{()}
    child::KMLElement
end
Base.@kwdef mutable struct Create <: KMLElement{()}
    child::KMLElement
end
Base.@kwdef mutable struct Delete <: KMLElement{()}
    child::KMLElement
end
Base.@kwdef mutable struct Update <: KMLElement{()}
    targetHref::String
    @option Change::Change
    @option Create::Create
    @option Delete::Delete
end
Base.@kwdef mutable struct gx_AnimatedUpdate <: gx_TourPrimitive
    @object
    @option gx_duration::Float64
    @option Update::Update
    @option gx_delayedStart::Float64
end
#-----------------------------------------------------------------------------# gx_FlyTo
Base.@kwdef mutable struct gx_FlyTo <: gx_TourPrimitive
    @object
    @option gx_duration::Float64
    @option gx_flyToMode::Enums.flyToMode
    @option AbstractView::AbstractView
end
#-----------------------------------------------------------------------------# gx_SoundCue
Base.@kwdef mutable struct gx_SoundCue <: gx_TourPrimitive
    @object
    @option href::String
    @option gx_delayedStart::Float64
end
#-----------------------------------------------------------------------------# gx_TourControl
Base.@kwdef mutable struct gx_TourControl
    @object
    gx_playMode::String = "pause"
end
#-----------------------------------------------------------------------------# gx_Wait
Base.@kwdef mutable struct gx_Wait
    @object
    @option gx_duration::Float64
end
#-===========================================================================-# AbstractView
Base.@kwdef mutable struct gx_option
    name::String
    enabled::Bool
end

Base.@kwdef mutable struct gx_ViewerOptions
    options::Vector{gx_option}
end

#-----------------------------------------------------------------------------# Camera
Base.@kwdef mutable struct Camera <: AbstractView
    @object
    @option TimePrimitive::TimePrimitive
    @option gx_ViewerOptions::gx_ViewerOptions
    @option longitude::Float64
    @option latitude::Float64
    @option altitude::Float64
    @option heading::Float64
    @option tilt::Float64
    @option roll::Float64
    @altitude_mode_elements
end

Base.@kwdef mutable struct LookAt <: AbstractView
    @object
    @option TimePrimitive::TimePrimitive
    @option gx_ViewerOptions::gx_ViewerOptions
    @option longitude::Float64
    @option latitude::Float64
    @option altitude::Float64
    @option heading::Float64
    @option tilt::Float64
    @option range::Float64
    @altitude_mode_elements
end

#-----------------------------------------------------------------------------# parsing
include("parsing.jl")

#-----------------------------------------------------------------------------# exports
export KMLFile, Enums, object

for T in vcat(all_concrete_subtypes(KMLElement), all_abstract_subtypes(Object))
    if T != KML.Pair
        e = Symbol(replace(string(T), "KML." => ""))
        @eval export $e
    end
end

end #module
