using KML
using GeoInterface
using InteractiveUtils
using Test

@testset "GeoInterface" begin
    @test GeoInterface.testgeometry(KML.Point(coordinates=(0,0)))
    @test GeoInterface.testgeometry(KML.LineString(coordinates=[(0,0), (1,1)]))
    @test GeoInterface.testgeometry(KML.LinearRing(coordinates=[(0,0), (1,1), (2,2)]))

    p = KML.Polygon(
        outerBoundaryIs = KML.LinearRing(coordinates=[(0,0), (1,1), (2,2), (0,0)]),
        innerBoundaryIs = [
            KML.LinearRing(coordinates=[(.5,5), (.7,7), (0,0), (.5,.5)])
        ]
    )
    @test GeoInterface.testgeometry(p)
end
