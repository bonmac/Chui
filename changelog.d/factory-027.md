- **factory 0.2.7** (`factory/`, not yet synced into the coordinator or the packages): six fixes
  for problems lanes hit on 2026-10-20.
  - The Benchmark workflow runs `julia scripts/ci.jl bench -- --base "origin/$BASE"` (full history,
    the base branch passed through `env:`, warning-only) instead of AirspeedVelocity, which cannot
    be installed next to CSV.jl 1.x.
  - `bench.time_tolerance` is documented as meaningful only on a quiet runner.
  - check_docs skips Documenter's bare `(@ref)` link targets.
  - evidence.jl records `termsignal` and exits 128 + the signal for a killed run. check_claims no
    longer takes test totals from such a run.
  - An `origin/<b>` base that does not resolve falls back to a local `<b>`, with a printed note,
    in `dod.jl`, `ratchet.jl`, `bench.jl` and `lane audit`.
  - `ci.jl --timeout SECONDS` (or `CI_TIMEOUT`) bounds a run and kills its whole process tree
    (exit 124). This replaces `perl -e alarm`.
  - The seeded `test/runtests.jl` skips `:doctest`/`:snapshot` below `STABLE_MIN` when
    `CI_STABLE` is unset. Each package's own `test/runtests.jl` needs that edit by hand.

  Spec: `docs/superpowers/specs/2026-10-20-factory-027-design.md`. Each repo takes 0.2.7 in its own
  sync lane.
