module KML

using OrderedCollections: OrderedDict
using AbstractTrees
import AbstractTrees: children
using XML
import XML: Element, showxml

#----------------------------------------------------------------------------# utils
const current_ids = Ref(Dict{String, Int}())
const INDENT = "  "

function next_id(prefix="id")
    current_ids[][prefix] = get(current_ids[], prefix, 0) + 1
    return prefix * "_$(current_ids[][prefix])"
end

#-----------------------------------------------------------------------------# types.jl
include("types.jl")

end #module
