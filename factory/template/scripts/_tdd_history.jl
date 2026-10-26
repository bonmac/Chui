# The tdd.jl history and evidence rules (factory 0.3.0; spec §0.5, §3.1-3.2, §4.2, §4.3, §5.2, §6).
# Top-level definitions, included after _common.jl (it uses `git`, `merge_base`) by tdd.jl's
# `module Tdd` and by dod.jl; never run on its own, no `module` of its own, no side effects.

"One non-merge lane commit: `author` is `name <email>`, `phase` the `TDD:` trailer, `mode` the
commit's own `TDD-Mode:` trailer as (mode, reason), `paths` repo-relative."
struct LaneCommit
    sha::String
    author::String
    phase::Union{Nothing, String}
    mode::Union{Nothing, Tuple{String, String}}
    paths::Vector{String}
end

function trailers end
function lane_commits end
function history_rules end
function strip_lines! end
function is_compat_decl end
function stub_declares_only end
function evidence_rules end
function audit end
