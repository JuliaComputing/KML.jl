<h1 align="center">KML.jl</h1>

**Working with Google Earth's KML format in Julia.**

This package takes inspiration from Python's [simplekiml](https://simplekml.readthedocs.io/en/latest/)
package.

<br>
<br>

## Quickstart

```julia
file = KMLFile(
    Document(
        Features=[
            Placemark(
                Geometry=Point(
                    coordinates=(77.0369, 38.9072)
                ),
                name="Washington, D.C."
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


<br>
<br>

## KML Object-to-Julia mapping

<br>

####  Each `Object` is a `struct`, constructed with keyword arguments only.

```julia
pt = Point(coordinates=(0,1))
```

- In XML, this becomes

```xml
<Point>
    <coordinates>0.0,1.0</coordinates>
</Point>
```

- Most keyword arguments are optional.  They can be set after construction.

```julia
pt = Point()

pt.coordinates = (2,3)
```

<br>

#### Google extensions (things with `gx:` in the name) are renamed to use `_`:

E.g.
- `gx:altitudeMode` → `gx_altitudeMode`
- `gx:Tour` → `gx_Tour`

<br>

#### The fields of a struct are KML elements.

- Lowercased fields are elements where `field_name == tag`
    - e.g. `pt.coordinates` gets written as `<coordinates>$(xml_string(pt.coordinates))</coordinates>`

- Uppercased fields match their type.
    - e.g. The `Geometry` field of a `Placemark` must be a `Geometry` (abstract type) like `Point`.

```julia
p = PlaceMark()

p.Geometry = Point(coordinates=(4,5))
```

- There are rare exceptions to lower/upper casing: fields of `ScreenOverlay`, extensions like `gx_Track`.

- Fields with plural names expect a `Vector` of the associated type.

```julia
mg = MultiGeometry()

mg.Geometries = [Point(coordinates=(0,1)), Point(coordinates=(2,3))]
```
