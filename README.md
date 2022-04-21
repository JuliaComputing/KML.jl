# KML

## KML Object-to-Julia mapping

- Each `Object` is a `struct`.
- Objects are constructed with keyword args only, e.g. `Point(coordinates=(0, 1))`.
    - In XML, this becomes `<Point><coordinates>0.0,1.0</coordinates></Point>`.
- Each field in an Object struct is itself an element (like `coordinates` above).
    - Except for `id` and `targetId` because they are attributes, e.g. `<Tag id="my id">`
- Elements like `gx:altitudeMode` are converted to `gx_altitudeMode`.

## Progress

- Object
    - Feature
        - [ ] gx:Tour
        - [x] NetworkLink
        - [x] Placemark
        - Overlay
            - [x] PhotoOverlay
            - [x] ScreenOverlay (*needs work)
            - [x] GroundOverlay
        - Container
            - [ ] Folder
            - [ ] Document
    - Geometry
        - [x] Point
        - [ ] LineString
        - [ ] LinearRing
        - [ ] PolyGon
        - [ ] MultiGeometry
        - [ ] Model
        - [ ] gx:Track
        - [ ] gx:MultiTrack
    - [x] Link
    - [x] Icon
    - [ ] Orientation
    - [ ] Location
    - [ ] Scale
    - StyleSelector
        - [ ] Style
        - [ ] StyleMap
    - TimePrimitive
        - [ ] TimeSpan
        - [ ] TimeStamp
    - AbstractView
        - [ ] Camera
        - [ ] LookAt
    - [x] Region
    - [x] Lod
    - [x] LatLonBox
    - [x] LatLonAltBox
    - [x] gx:LatLonQuad
    - SubStyle
        - [ ] BalloonStyle
        - [ ] ListStyle
        - ColorStyle
            - [ ] LineStyle
            - [ ] PolyStyle
            - [ ] IconStyle
            - [ ] LabelStyle
    - gx:TourPrimitive
        - [ ] gx:AnimatedUpdate
        - [ ] gx:FlyTo
        - [ ] gx:SoundCue
        - [ ] gx:TourControl
        - [ ] gx:Wait
    - [ ] gx:PlayList

## Resources

- Primary Resource: [https://developers.google.com/kml/documentation/kmlreference](https://developers.google.com/kml/documentation/kmlreference)
