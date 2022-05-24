using KML
using GeoInterface
using Test

@testset "KML" begin
@testset "Empty Constructors" begin
    for T in KML.all_subtypes(KML.Object)
        @test T() isa T
    end
end

@testset "GeoInterface" begin
    @test GeoInterface.testgeometry(KML.Point(coordinates=(0,0)))
    @test GeoInterface.testgeometry(KML.LineString(coordinates=Tuple{Float64,Float64}[(0,0), (1,1)]))
    @test GeoInterface.testgeometry(KML.LinearRing(coordinates=Tuple{Float64,Float64}[(0,0), (1,1), (2,2)]))

    p = KML.Polygon(
        outerBoundaryIs = KML.LinearRing(coordinates=Tuple{Float64,Float64}[(0,0), (1,1), (2,2), (0,0)]),
        innerBoundaryIs = [
            KML.LinearRing(coordinates=Tuple{Float64,Float64}[(.5,5), (.7,7), (0,0), (.5,.5)])
        ]
    )
    @test GeoInterface.testgeometry(p)
end

@testset "KMLFile" begin
    file = KML.KMLFile(joinpath(@__DIR__, "example.kml"))
    @test file isa KML.KMLFile

    write("test.kml", file)

    file2 = KML.KMLFile("test.kml")
    @test file == file2

    rm("test.kml", force=true)
end
end # KML
