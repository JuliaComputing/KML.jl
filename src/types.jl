# =========================================================================== # Abstract Types

abstract type KMLElement end  # Things that are not an `Object`, but still in the spec


abstract type ElementSet end  # Common elements for an Object (e.g. Feature)
Base.show(io::IO, o::ElementSet) = showxml(io, o)
showxml(io::IO, o::ElementSet; depth=0) = show_all_fields(io, o; depth)



#-----------------------------------------------------------------------------# Object
abstract type Object end  # has fields `id` and `targetId`

macro object_attributes()
    esc(quote
        id::Union{Nothing, String} = nothing
        targetId::Union{Nothing, String} = nothing
    end)
end

Base.show(io::IO, o::Object) = showxml(io, o)

function showxml(io::IO, o::T; depth=0) where {T<:Object}
    tag = replace(string(T), "KML." => "")
    printstyled(io, INDENT^depth, '<', tag, attrs(o), '>', '\n'; color=:light_cyan)
    show_all_fields(io, o; depth = depth + 1)
    printstyled(io, INDENT ^ depth, "</", tag, '>'; color=:light_cyan)
end

function attrs(o::Object)
    (isnothing(o.id) ? "" : " id=$(repr(o.id))") * (isnothing(o.targetId) ? "" : " targetId=$(repr(targetID))")
end

function show_all_fields(io::IO, o::T; depth=0) where {T}
    for field in fieldnames(T)
        tag = replace(string(field), '_' => ':')
        x = getfield(o, field)
        if !isnothing(x) && field ∉ [:id, :targetId]
            if x isa Object || x isa KMLElement
                showxml(io, x; depth = depth)
            elseif x isa ElementSet
                show_all_fields(io, x; depth)
            else
                printstyled(io, INDENT ^ depth, '<', tag, '>'; color=:light_green)
                print(io, xml_string(x))
                printstyled(io, "</", tag, '>'; color=:light_green)
            end
            println(io)
        end
    end
end

xml_string(x::Bool) = x ? "1" : "0"
xml_string(x::Union{Vector, Tuple}) = join(x, ",")
xml_string(x::Vector{Vector{Float64}}) = join(xml_string.(x), '\n')
xml_string(x) = string(x)

#-----------------------------------------------------------------------------# Feature
abstract type Feature <: Object end  # has field `FeatureElements::FeatureElements`
# function Base.getproperty(o::T, prop::Symbol) where {T<:Feature}
#     f = getfield(o, :FeatureElements)
#     hasfield(T, prop) ? getfield(f, prop) : getfield(o, prop)
# end
# function Base.setproperty!(o::T, prop::Symbol, value) where {T<:Feature}
#     f = getfield(o, :FeatureElements)
#     hasfield(T, prop) ? setfield!(f, prop, value) : setfield!(o, prop, value)
# end



abstract type Overlay <: Feature end
abstract type Container <: Feature end

#-----------------------------------------------------------------------------# Geometry
abstract type Geometry <: Object end

#-----------------------------------------------------------------------------# StyleSelector
abstract type StyleSelector <: Object end

#-----------------------------------------------------------------------------# TimePrimitive
abstract type TimePrimitive <: Object end

#-----------------------------------------------------------------------------# AbstractView
abstract type AbstractView <: Object end

#-----------------------------------------------------------------------------# SubStyle
abstract type SubStyle <: Object end
abstract type ColorStyle <: SubStyle end

#-----------------------------------------------------------------------------# GXTourPrimitive
abstract type GXTourPrimitive <: Object end





# =========================================================================== # Concrete Types

#-----------------------------------------------------------------------------# "Enums"
# Not using @enum because some EnumTypes use the same values
altitudeMode = (clampToGround=:clampToGround, relativeToGround=:relativeToGround, absolute=:absolute)

var"gx:altitudeMode" = (relativeToSeaFloor=:relativeToSeaFloor, clampToSeaFloor=:clampToSeaFloor)

refreshMode = (onChange=:onChange, onInterval=:onInterval, onExpire=:onExpire)

viewRefreshMode = (never=:never, onStop=:onStop, onRequest=:onRequest, onRegion=:onRegion)

shape = (rectangle=:rectangle, cylinder=:cylinder, sphere=:sphere)

gridOrigin = (lowerLeft=:lowerLeft, upperLeft=:upperLeft)

#-----------------------------------------------------------------------------# ExtendedData
# TODO: details
Base.@kwdef mutable struct ExtendedData
    children::Vector
end
function showxml(io::IO, o::ExtendedData; depth=0)
    println(io, "<ExtendedData>")
    for child in o.children
        showxml(io, child; depth = depth + 1)
    end
    println(io, "</ExtendedData>")
end



#-----------------------------------------------------------------------------# LatLonBox
Base.@kwdef mutable struct LatLonBox <: Object
    @object_attributes
    north::Float64
    south::Float64
    east::Float64
    west::Float64
    rotation::Float64 = 0.0
end

#-----------------------------------------------------------------------------# LatLonQuad (gx:LatLonQuad)
Base.@kwdef mutable struct LatLonQuad <: Object
    @object_attributes
    coordinates::Vector{NTuple{2, Float64}}
end

#-----------------------------------------------------------------------------# Lod
Base.@kwdef mutable struct Lod <: Object
    @object_attributes
    minLodPixels::Int = 256
    maxLodPixels::Int = -1
    minFadeExtent::Int = 0
    maxFadeExtent::Int = 0
end

#-----------------------------------------------------------------------------# LatLonAltBox
Base.@kwdef mutable struct LatLonAltBox <: Object
    @object_attributes
    north::Float64
    south::Float64
    east::Float64
    west::Float64
    minAltitude::Union{Nothing, Float64} = nothing
    maxAltitude::Union{Nothing, Float64} = nothing
    altitudeMode::Union{Nothing, Symbol} = nothing
    gx_altitudeMode::Union{Nothing, Symbol} = nothing
end

#-----------------------------------------------------------------------------# Region
Base.@kwdef mutable struct Region <: Object
    @object_attributes
    LatLonAltBox::LatLonAltBox = LatLonAltBox(north=0,south=0,east=0,west=0)
    Lod::Lod = Lod()
end

#-----------------------------------------------------------------------------# Snippet
Base.@kwdef mutable struct Snippet <: KMLElement
    @object_attributes
    content::String
    maxLines::Int = 2
end
showxml(io::IO, o::Snippet) = print(io, "<Snippet maxLines=", o.maxLines, '>', o.content, "</Snippet>")

#-----------------------------------------------------------------------------# @feature_elements
macro feature_elements()
    esc(quote
        name::Union{Nothing, String}                    = nothing
        visibility::Union{Nothing, Bool}                = nothing
        open::Union{Nothing, Bool}                      = nothing
        atom_author::Union{Nothing, String}        = nothing
        atom_link::Union{Nothing, String}          = nothing
        address::Union{Nothing, String}                 = nothing
        xal_AddressDetails::Union{Nothing, String} = nothing
        phoneNumber::Union{Nothing, String}             = nothing
        Snippet::Union{Nothing, Snippet}                = nothing
        description::Union{Nothing, String}             = nothing
        AbstractView::Union{Nothing, AbstractView}      = nothing
        TimePrimitive::Union{Nothing, TimePrimitive}    = nothing
        styleURL::Union{Nothing, String}                = nothing
        StyleSelector::Union{Nothing, StyleSelector}    = nothing
        region::Union{Nothing, Region}                  = nothing
        extended_data::Union{Nothing, ExtendedData}     = nothing
    end)
end

#-----------------------------------------------------------------------------# Placemark
Base.@kwdef mutable struct Placemark <: Feature
    @object_attributes
    @feature_elements
    Geometry::Union{Nothing, Geometry} = nothing
end

#-----------------------------------------------------------------------------# Link/Icon
Base.@kwdef mutable struct Link <: Object
    @object_attributes
    href::Union{Nothing,String}                 = nothing
    refreshMode::Union{Nothing, Symbol}         = nothing # enum
    refreshInterval::Union{Nothing, Float64}    = nothing
    viewRefreshMode::Union{Nothing, Symbol}     = nothing # enum
    viewRefreshTime::Union{Nothing, Float64}    = nothing
    viewBoundScale::Union{Nothing, Float64}     = nothing
    viewFormat::Union{Nothing, String}          = nothing
    httpQuery::Union{Nothing, String}           = nothing
end
Base.@kwdef mutable struct Icon <: Object
    @object_attributes
    href::Union{Nothing,String}                 = nothing
    refreshMode::Union{Nothing, Symbol}         = nothing # enum
    refreshInterval::Union{Nothing, Float64}    = nothing
    viewRefreshMode::Union{Nothing, Symbol}     = nothing # enum
    viewRefreshTime::Union{Nothing, Float64}    = nothing
    viewBoundScale::Union{Nothing, Float64}     = nothing
    viewFormat::Union{Nothing, String}          = nothing
    httpQuery::Union{Nothing, String}           = nothing
end

#-----------------------------------------------------------------------------# Overlay
macro overlay_elements()
    esc(quote
        color::Union{Nothing, String} = nothing
        drawOrder::Union{Nothing, Int} = nothing
        Icon::Union{Nothing, Icon} = nothing
    end)
end

#-----------------------------------------------------------------------------# Point
Base.@kwdef mutable struct Point <: Geometry
    @object_attributes
    extrude::Union{Nothing, Bool} = nothing
    altitudeMode::Union{Nothing, Symbol} = nothing
    gx_altitudeMode::Union{Nothing, Symbol} = nothing
    coordinates::Union{NTuple{2,Float64}, NTuple{3, Float64}} = (0.0, 0.0) # lon / lat / (alt)
end

#-----------------------------------------------------------------------------# PhotoOverlay
Base.@kwdef mutable struct ViewVolume <: KMLElement
    leftFov::Float64 = 0
    rightFov::Float64 = 0
    bottomFov::Float64 = 0
    topFov::Float64 = 0
    near::Float64 = 0
end

Base.@kwdef mutable struct ImagePyramid <: KMLElement
    tileSize::Int = 256
    maxWidth::Int
    maxHeight::Int
    gridOrigin::Symbol # lowerLeft or upperLeft
end

Base.@kwdef mutable struct PhotoOverlay <: Overlay
    @object_attributes
    @feature_elements
    @overlay_elements
    rotation::Union{Nothing, Float64}           = nothing
    ViewVolume::Union{Nothing, ViewVolume}      = nothing
    ImagePyramid::Union{Nothing, ImagePyramid}  = nothing
    Point::Union{Nothing, Point}                = nothing
    shape::Union{Nothing, Symbol}               = nothing # enum
end

#-----------------------------------------------------------------------------# ScreenOverlay
# TODO: change String to structs for these troublesome elements: overlayXY → size
Base.@kwdef mutable struct ScreenOverlay <: Overlay
    @object_attributes
    @feature_elements
    @overlay_elements
    overlayXY::Union{Nothing, String}   = nothing # FIXME
    screenXY::Union{Nothing, String}    = nothing # FIXME
    rotationXY::Union{Nothing, String}  = nothing # FIXME
    size::Union{Nothing, String}        = nothing # FIXME
    rotation::Union{Nothing, Float64} = nothing
end

#-----------------------------------------------------------------------------# GroundOverlay
Base.@kwdef mutable struct GroundOverlay <: Overlay
    @object_attributes
    @feature_elements
    @overlay_elements
    altitude::Union{Nothing, Float64}           = nothing
    altitudeMode::Union{Nothing, Symbol}        = nothing
    gx_altitudeMode::Union{Nothing, Symbol}     = nothing
    LatLonBox::Union{Nothing, LatLonBox}        = nothing
    gx_LatLonQuad::Union{Nothing, LatLonQuad}   = nothing
end

#-----------------------------------------------------------------------------# NetworkLink
Base.@kwdef mutable struct NetworkLink <: Feature
    @object_attributes
    @feature_elements
    refreshVisibility::Union{Nothing,Bool}  = nothing
    flyToView::Union{Nothing,Bool}          = nothing
    Link::Link                              = Link()
end
