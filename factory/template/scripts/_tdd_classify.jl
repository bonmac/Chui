# The tdd.jl classifier (factory 0.3.0; spec §3.3, §3.4). Top-level definitions, included after _common.jl.

"One `@testitem`: its name, file, first and last line, and the names in its `setup = [...]`."
struct ItemSpan
    name::String
    file::String
    first::Int
    last::Int
    setup::Vector{String}
end

function item_spans end
function module_names end
function requested end
function headers end
function classify end
function red_ok end
function report end
