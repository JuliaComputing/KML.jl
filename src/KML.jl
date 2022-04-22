module KML

using OrderedCollections: OrderedDict
using AbstractTrees
import AbstractTrees: children
using XML
import XML: Element, showxml

#----------------------------------------------------------------------------# utils
const INDENT = "  "

module Enums
@enum altitudeMode clampToGround relativeToGround absolute
@enum gx_altitudeMode relativeToSeaFloor clampToSeaFloor
@enum refreshMode onChange onInterval onExpire
@enum viewRefreshMode never onStop onRequest onRegion
@enum shape rectangle cylinder sphere
@enum gridOrigin lowerLeft upperLeft
@enum displayMode default hide
@enum listItemType check checkOffOnly checkHideChildren radioFolder
@enum units fraction pixels insetPixels
@enum styleState open closed error fetching0 fetching1 fetching2
@enum colorMode normal random
end


xml_string(x::Bool) = x ? "1" : "0"
xml_string(x::Union{Vector, Tuple}) = join(x, ",")
xml_string(x::Vector{<:Union{Vector, Tuple}}) = join(xml_string.(x), '\n')
xml_string(x) = string(x)


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

macro option(expr)
    expr.head == :(::) || error("@default only works on type annotations e.g. `field::Type`")
    expr.args[2] = Expr(:curly, :Union, :Nothing, expr.args[2])
    return esc(Expr(:(=), expr, :nothing))
end



#-----------------------------------------------------------------------------# KMLElement
# `attr_names` fields print as attributes, everything else as an element
abstract type KMLElement{attr_names} end

const NoAttributes = KMLElement{()}

Base.show(io::IO, o::KMLElement) = showxml(io, o)

# :light_cyan => KMLElement
# :light_green => field name
# :light_black => field value
function showxml(io::IO, o::T; depth=0) where {attr_names, T<:KMLElement{attr_names}}
    tag = replace(string(T), "KML." => "", "_" => ":")
    printstyled(io, INDENT ^ depth, '<', tag; color=:light_cyan)
    for (k, v) in zip(attr_names, getfield.(Ref(o), attr_names))
        !isnothing(v) && printstyled(io, ' ', k, '=', '"', v, '"'; color=:light_cyan)
    end
    printstyled(io, '>', '\n'; color=:light_cyan)
    element_names = setdiff(fieldnames(T), attr_names)
    for (k, v) in zip(element_names, getfield.(Ref(o), element_names))
        if v isa KMLElement
            show(io, v; depth = depth + 1)
            println(io)
        elseif v isa Vector{<:KMLElement}
            map(v) do child
                showxml(io, child; depth=depth+1)
                println(io)
            end
        else
            if !isnothing(v)
                s = xml_string(v)
                printstyled(io, INDENT^(depth+1), '<', k, '>'; color=:light_green)
                if occursin('\n', s)
                    prefix = '\n' * INDENT^(depth + 2)
                    printstyled(io, prefix, replace(s, '\n' => prefix), '\n'; color=:light_black)
                    printstyled(io, INDENT^(depth + 1), "</", k, '>'; color=:light_green)
                else
                    printstyled(io, s; color=:light_black)
                    printstyled(io, "</", k, '>'; color=:light_green)
                end
                println(io)
            end
        end
    end
    printstyled(io, INDENT ^ depth, "</", tag, '>'; color=:light_cyan)
end

#-----------------------------------------------------------------------------# Object
abstract type Object <: KMLElement{(:id, :targetId)} end

abstract type Feature <: Object end
abstract type Overlay <: Feature end
abstract type Container <: Feature end

abstract type Geometry <: Object end

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
    minLodPixels::Int
    @option maxLodPixels::Int
    @option minFadeExtent::Int
    @option maxFadeExtent::Int
end
#-----------------------------------------------------------------------------# LatLonBox <: Object
Base.@kwdef mutable struct LatLonBox <: Object
    @object
    north::Float64
    south::Float64
    east::Float64
    west::Float64
    @option rotation::Float64
end
#-----------------------------------------------------------------------------# LatLonAltBox <: Object
Base.@kwdef mutable struct LatLonAltBox <: Object
    @object
    north::Float64
    south::Float64
    east::Float64
    west::Float64
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
    coordinates::Vector{NTuple{2, Float64}}
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
    content::String
    maxLines::Int = 2
end
showxml(io::IO, o::Snippet) = printstyled(io, "<Snippet maxLines=", repr(o.maxLines), '>', o.content, "</Snippet>", color=:light_yellow)
#-----------------------------------------------------------------------------# ExtendedData
# TODO: finish
Base.@kwdef mutable struct ExtendedData <: NoAttributes
    children::Vector
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
    @option styleURL::String
    @option StyleSelector::StyleSelector
    @option region::Region
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


#-===========================================================================-# Geometries
#-----------------------------------------------------------------------------# Point <: Geometry
Base.@kwdef mutable struct Point <: Geometry
    @object
    @option extrude::Bool
    @altitude_mode_elements
    @option coordinates::Tuple
end
#-----------------------------------------------------------------------------# LineString <: Geometry
Base.@kwdef mutable struct LineString <: Geometry
    @object
    @option gx_altitudeOffset::Float64
    @option extrude::Bool
    @option tesselate::Bool
    @altitude_mode_elements
    @option gx_drawOrder::Int
    @option coordinates::Vector{Tuple}
end
#-----------------------------------------------------------------------------# LinearRing <: Geometry
Base.@kwdef mutable struct LinearRing <: Geometry
    @object
    @option gx_altitudeOffset::Float64
    @option extrude::Bool
    @option tesselate::Bool
    @altitude_mode_elements
    @option coordinates::Vector{Tuple}
end
#-----------------------------------------------------------------------------# PolyGon <: Geometry
Base.@kwdef mutable struct Polygon <: Geometry
    @object
    @option extrude::Bool
    @option tesselate::Bool
    @option outerBoundaryIs::LinearRing
    @option innerBoundaryIs::Vector{LinearRing}
end
#-----------------------------------------------------------------------------# MultiGeometry <: Geometry
Base.@kwdef mutable struct MultiGeometry <: Geometry
    @object
    @option Geometries::Vector{Geometry}
end
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
    @option x::Float64
    @option y::Float64
    @option xunits::Enums.units
    @option yunits::Enums.units
end
Base.@kwdef mutable struct screenXY <: KMLElement{(:x, :y, :xunits, :yunits)}
    @option x::Float64
    @option y::Float64
    @option xunits::Enums.units
    @option yunits::Enums.units
end
Base.@kwdef mutable struct rotationXY <: KMLElement{(:x, :y, :xunits, :yunits)}
    @option x::Float64
    @option y::Float64
    @option xunits::Enums.units
    @option yunits::Enums.units
end
Base.@kwdef mutable struct ScreenOverlay <: Overlay
    @overlay
    @option overlayXY::overlayXY
    @option screenXY::screenXY
    @option rotationXY::rotationXY
    @option size::String
    @option rotation::Float64
end
#-----------------------------------------------------------------------------# GroundOverlay <: Overlay
Base.@kwdef mutable struct GroundOverlay <: Overlay
    @overlay
    @option altitude::Float64
    @altitude_mode_elements
    @option LatLonBox::LatLonBox
    @option GXLatLonQuad::gx_LatLonQuad
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
Base.@kwdef mutable struct ItemIcon <: Object # lie
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
    @option width::Int
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
    @option styleURL::String
    @option Style::Style
end

Base.@kwdef mutable struct StyleMap <: StyleSelector
    @object
    @option Pairs::Vector{Pair}
end

end #module
