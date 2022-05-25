<h1 align="center">KML.jl</h1>

**Working with Google Earth's KML format in Julia.**

This package takes inspiration from Python's [simplekml](https://simplekml.readthedocs.io/en/latest/)
package.

<br>
<br>

## Quickstart

### Writing

```julia
file = KMLFile(
    Document(
        Features = Feature[
            Placemark(
                Geometry = Point(coordinates=(77.0369, 38.9072)),
                name = "Washington, D.C."
            )
        ]
    )
)
```


```xml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.2">
  <Document>
    <Placemark>
      <name>Washington, D.C.</name>
      <Point>
        <coordinates>77.0369,38.9072</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>
```


### Reading

```julia
path = download("https://developers.google.com/kml/documentation/KML_Samples.kml")

file = KMLFile(path)
```


<br>
<br>


## KML Objects ←→ Julia structs

This package is designed to be used intuitively alongside [Google's KML Reference Page](https://developers.google.com/kml/documentation/kmlreference).  Thus, there are rules that guide the mapping between KML (XML) Objects and Julia structs.

1. In Julia, each `Object` is constructed with keyword arguments only.
2. Keywords are the associated attributes as well as child elements of the `Object`
  - E.g. `pt = Point(id="mypoint", coordinates=(0,1)) sets the `id` attribute and `coordinates` child element.
3. Every keyword has a default value (most often `nothing`).  They can be set after construction.
  - E.g. `pt.coordinates = (2.3)`
4. If a child element is itself an `Object`, the keyword matches the type name.
  - E.g. `pl = Placemark(); pl.Geometry = Point()`.  Here, a `Placemark` can hold any `Geometry`, which is an abstract type.  A `Point` is a subtype of `Geometry`.
5. Some `Object`s can hold several children of the same type.  Fields with plural names expect a `Vector`.
  - E.g. `mg = MultiGeometry(); mg.Geometries = [Point(), Polygon()]
6. Enum types are in the `KML.Enums` module.  However, you shouldn't need to create them directly as conversion is handled for you/helpful error messages are provided.

```julia
julia> pt.altitudeMode = "clamptoground"
ERROR: altitudeMode ∉ clampToGround, relativeToGround, absolute
```

7. Google extensions (things with `gx:` in the name) replace `:` with `_`.
  - E.g. `gx:altitudeMode` → `gx_altitudeMode`


<br><br>

---

#### For a concrete example, examine the fields of a `KML.Document`:

```
Fields
≡≡≡≡≡≡≡≡

id                 :: Union{Nothing, String}
targetId           :: Union{Nothing, String}
name               :: Union{Nothing, String}
visibility         :: Union{Nothing, Bool}
open               :: Union{Nothing, Bool}
atom_author        :: Union{Nothing, String}
atom_link          :: Union{Nothing, String}
address            :: Union{Nothing, String}
xal_AddressDetails :: Union{Nothing, String}
phoneNumber        :: Union{Nothing, String}
Snippet            :: Union{Nothing, KML.Snippet}
description        :: Union{Nothing, String}
AbstractView       :: Union{Nothing, KML.AbstractView}    # Camera or LookAt
TimePrimitive      :: Union{Nothing, KML.TimePrimitive}   # TimeSpan or TimeMap
styleURL           :: Union{Nothing, String}
StyleSelector      :: Union{Nothing, KML.StyleSelector}   # Style or StyleMap
region             :: Union{Nothing, KML.Region}
ExtendedData       :: Union{Nothing, KML.ExtendedData}
Schemas            :: Union{Nothing, Vector{KML.Schema}}  # Multiple Schemas allowed
Features           :: Union{Nothing, Vector{KML.Feature}} # Multiple Features (abstract type) allowed
```


<br>
<br>
