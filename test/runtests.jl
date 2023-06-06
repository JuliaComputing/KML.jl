using KML
using GeoInterface
using Test
using XML

@testset "Empty Constructors" begin
    for T in KML.all_concrete_subtypes(KML.Object)
        @test T() isa T
    end
    @testset "Empty constructor roundtrips with XML.Node" begin
        for T in KML.all_concrete_subtypes(KML.Object)
            o = T()
            n = XML.Node(o)
            @test occursin(XML.tag(n), replace(string(T), '_' => ':'))
            o2 = object(n)
            @test o2 isa T
            @test o == o2
        end
    end
end


@testset "GeoInterface" begin
    @test GeoInterface.testgeometry(Point(coordinates=(0,0)))
    @test GeoInterface.testgeometry(LineString(coordinates=Tuple{Float64,Float64}[(0,0), (1,1)]))
    @test GeoInterface.testgeometry(LinearRing(coordinates=Tuple{Float64,Float64}[(0,0), (1,1), (2,2)]))

    p = Polygon(
        outerBoundaryIs = LinearRing(coordinates=Tuple{Float64,Float64}[(0,0), (1,1), (2,2), (0,0)]),
        innerBoundaryIs = [
            LinearRing(coordinates=Tuple{Float64,Float64}[(.5,5), (.7,7), (0,0), (.5,.5)])
        ]
    )
    @test GeoInterface.testgeometry(p)

    @test GeoInterface.testfeature(Placemark(Geometry=p))
end

@testset "KMLFile roundtrip" begin
    file = read(joinpath(@__DIR__, "example.kml"), KMLFile)
    @test file isa KMLFile

    temp = tempname()

    KML.write(temp, file)

    file2 = read(temp, KMLFile)
    @test file == file2
end

@testset "Issue Coverage" begin
    # https://github.com/JuliaComputing/KML.jl/issues/8
    @test_warn "Unhandled case" read(joinpath(@__DIR__, "outside_spec.kml"), KMLFile)
end
