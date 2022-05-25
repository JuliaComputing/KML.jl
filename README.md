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
2. These keyword arguments are the child elements of the `Object`.

```julia
Point(; coordinates=(0,1))
# <Point>
#   <coordinates>0,1</coordinates>
# </Point>
```

3. Arguments are `nothing` by default. They can be set after construction.

```julia
pt = Point()
# <Point />

pt.coordinates = (2,3)
pt
# <Point>
#   <coordinates>2,3</coordinates>
# </Point>
```

4. Some child elements are also `Object`s.  The argument matches the type name.

```julia
pl = PlaceMark()

# A Placemark accepts any `Geometry`, which is an abstract type (Point <: Geometry)
pl.Geometry = Point(coordinates=(4, 5))
```

5. Some `Object`s can have several children of the same type.  Fields with plural names expect a `Vector`.

```julia
mg = MultiGeometry()

mg.Geometries = [Point(coordinates=(0,1)), Point(coordinates=(2,3))]
```

6. Enum types are in the `KML.Enums` module:

```julia
KML.Enums.altitudeMode
# Enum KML.Enums.altitudeMode:
# clampToGround = 0
# relativeToGround = 1
# absolute = 2
```

7. Objects (and their fields) use `_` rather than `:`.  E.g. `gx:altitudeMode` → `gx_altitudeMode`


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
Schemas            :: Union{Nothing, Vector{KML.Schema}}
Features           :: Union{Nothing, Vector{KML.Feature}} # Vector of any Type <: Feature
```


<br>
<br>


## API
