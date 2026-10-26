# _tdd_backfill.jl: `tdd.jl mutate` and `tdd.jl gaps` (factory 0.3.0; spec 2026-10-26 §5.1, §5.2).
# Included by scripts/tdd.jl inside `module Tdd`; never run on its own.

"The evidence slug of item `name` (spec §5.2)."
function slug end

"The persistent mutation scratch worktree of `root`, `.lanes/scratch/mutate/`."
function scratch end

"Mutate one line in the scratch worktree and prove item `item` detects it (spec §5.2)."
function mutate end

"Print `UNTESTED name` for each exported or public name that appears nowhere in test/ (spec §5.1)."
function gaps end
