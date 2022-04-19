using KML
using XML: XML
using Test

@testset "KML.jl" begin
    doc = XML.Document(joinpath(@__DIR__, "example.kml"))
end
