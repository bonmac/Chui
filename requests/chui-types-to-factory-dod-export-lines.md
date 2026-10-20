# dod.jl rates a public-API change T1 when it only touches export lines in `src/<Pkg>.jl` (R12)

- **From → to:** chui-types → factory (`factory/template/`, synced to every package; T3 there: `risk.toml`, `scripts/dod.jl`, `.agents/checks.toml`)
- **Status:** open
- **Urgency:** soon (every package lane that adds or removes an export is under-tiered today)
- **Contract IDs affected:** none (process). Indirectly CT-003, CF-009 and CC-010 (export collision rules) and the T2 row of `risk.toml` ("public API, contracts, deps, compat")
- **Adapter used meanwhile:** the lead and the reviewer raise such PRs to T2 by hand (a `tier:T2` label, which dod.jl honours upward); nothing automatic
- **Reproducer:** in `<root>`: `julia --startup-file=no -e 'using TOML; include("factory/template/scripts/dod.jl"); r = TOML.parsefile("factory/template/risk.toml"); t, _ = DoD.evaluate(r, ["src/ChuiTypes.jl"], String[], ""); c = TOML.parsefile("factory/template/.agents/checks.toml"); d = only(filter(x -> x["id"] == "dod", c["checks"])); listed = any(b -> occursin("export", b), d["blind_spots"]); println("tier=", t, " blind_spot_listed=", listed); exit(t == "T2" || listed ? 0 : 1)'`. RED today (factory 0.2.7, coordinator `961b764`): `tier=T1 blind_spot_listed=false`, exit 1. GREEN under either option below. (Option A will need the reproducer to pass the diff text too, if `evaluate` grows a parameter for it.)

## Problem
`risk.toml`'s tiers say T2 is "public API, contracts, deps, compat". `dod.jl` derives the tier
only from **paths**: `max(label, the touched paths' tiers in [[protected]], default_tier)`
(`scripts/dod.jl` lines 6 and 57–62). The T2 globs are `Project.toml`, `test/contracts/*` and
`ext/*`. A change that adds, removes or renames an `export` or `public` line in
`src/<Pkg>.jl` changes the public API but touches no T2 path, so dod.jl rates it **T1** (short
plan, no spec) unless someone labels it. ChuiTypes' phase-4 lane saw this: its export lines for
`Queue`, `Stream`, the run functions and the adapters (`src/ChuiTypes.jl` lines 60–70 at
`6ee5fac`) were tiered by hand. `.agents/checks.toml`'s `dod` entry does not list this as a blind
spot either, so `docs/CHECK_COVERAGE.md` claims more than the check does.

## Proposed API
Either, in factory `0.2.8`:
- **A (preferred): a T2 rule for export lines.** dod.jl reads the base…head diff of
  `src/<Pkg>.jl` (the package's main module file, from `Project.toml`'s `name`) and raises the
  tier to T2 when an added or removed line matches `^\s*(export|public)\b` or
  `^\s*@compat public\b`. It reports `("tier", :info, "export lines changed in src/<Pkg>.jl: T2")`.
  A test in `scripts/test/test_dod.jl` covers an export-only diff (T2), a comment-only diff in
  the same file (T1), and a `@compat public` line (T2).
  - Blind spot to list even then: exports built by macros or in files `include`d from
    `src/<Pkg>.jl`. A public-API change made only by changing a method's signature is also not
    caught; reviewers still own that.
- **B (minimum): list it as a blind spot.** Add to the `dod` entry's `blind_spots` in
  `.agents/checks.toml`: "a public-API change that only edits `export`/`public` lines in
  `src/` is tiered by path (T1); the tier must be raised by a `tier:T2` label". Regenerate
  `docs/CHECK_COVERAGE.md` with `julia scripts/gen.jl`.

## History
- 2026-10-20 open: drafted in the ChuiTypes phase-4 lane's report, filed by the coordinator lane
  requests-p4p3. Reproducer run in `<root>` at `961b764` (factory 0.2.7), Julia 1.13.2:
  `tier=T1 blind_spot_listed=false`, exit 1 (RED).
