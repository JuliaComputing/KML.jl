# KML

## KML Object-to-Julia mapping

- Each `Object` is a `struct`.
- Objects are constructed with keyword args only, e.g. `Point(coordinates=(0, 1))`.
    - In XML, this becomes `<Point><coordinates>0.0,1.0</coordinates></Point>`.
- Each field in an Object struct is itself an element (like `coordinates` above).
    - Except for `id` and `targetId` because they are attributes, e.g. `<Tag id="my id">`
- Elements like `gx:altitudeMode` are converted to `gx_altitudeMode`.
- Objects like `gx:Tour` are converted to simply `GXTour`.

## What's left to implement
    - StyleSelector
        - [ ] StyleMap
    - TimePrimitive
        - [ ] TimeSpan
        - [ ] TimeStamp
    - AbstractView
        - [ ] Camera
        - [ ] LookAt
    - SubStyle
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

## Resources

- Primary Resource: [https://developers.google.com/kml/documentation/kmlreference](https://developers.google.com/kml/documentation/kmlreference)
