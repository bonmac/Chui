- **factory 0.2.7** (`factory/`, not yet synced into the coordinator or the packages): four fixes
  for problems lanes hit on 2026-10-20. The Benchmark workflow runs `julia scripts/ci.jl bench --
  --base origin/<base>` (full history, warning-only) instead of AirspeedVelocity, which cannot be
  installed next to CSV.jl 1.x. `bench.time_tolerance` is documented as meaningful only on a quiet
  runner. check_docs skips Documenter's bare `(@ref)` link targets. evidence.jl records `termsignal` and
  exits 128 + the signal for a killed run, which check_claims no longer takes test totals from.
  An `origin/<b>` base that does not resolve falls back to a local `<b>` in `dod.jl`, `ratchet.jl`
  and `lane audit`. Spec: `docs/superpowers/specs/2026-10-20-factory-027-design.md`. Each repo
  takes 0.2.7 in its own sync lane.
