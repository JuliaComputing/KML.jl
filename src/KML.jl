module KML

using OrderedCollections: OrderedDict
using AbstractTrees
import AbstractTrees: children
using XML
import XML: Element, showxml

#----------------------------------------------------------------------------# utils
const current_id = Ref(0)
const INDENT = "    "

next_id(prefix="id") = "$(prefix)_$(current_id[] += 1)"

include("types.jl")

end #module
