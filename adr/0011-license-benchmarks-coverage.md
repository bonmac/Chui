# ADR-0011: License, benchmark tool and coverage floor

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint)
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem

## Context

The ADRs so far leave three ecosystem-wide choices open:
- General requires an OSI-approved license (E-19).
- `common.md` §3 names "AirspeedVelocity.jl or PkgBenchmark" for benchmark-regression checks.
- The factory's base project uses "a coverage floor that only rises" (§3), with no mechanism chosen yet.

Registry and activity facts (E-33):
- AirspeedVelocity 0.6.6 (Julia ≥ 1.10, pushed 2026-10-15);
- PkgBenchmark 0.2.15 (Julia `1`, pushed 2026-03-13);
- BenchmarkTools 1.8.0. None of them is archived.

## Decision (all three decided by the user at the L0 checkpoint, 2026-10-19)

1. **License: MIT** for every package and the coordinator repo. It is OSI-approved and the most
   common license in General (UNVERIFIED share). The `LICENSE` file is in place before any push.
2. **Benchmarks: AirspeedVelocity.**
   - each repo keeps `benchmark/benchmarks.jl` defining a BenchmarkTools `SUITE`;
   - **AirspeedVelocity** compares a PR against `main` in CI, because it is the more actively
     maintained of the two;
   - **the benchmark CI job is warning-only at first** (`continue-on-error: true`, or the
     equivalent), and becomes **blocking** once a package's baselines settle. Making it blocking
     is a T3 change to that repo's workflow, recorded in its CHANGELOG;
   - the regression threshold is `ratchets.toml` `bench.time_tolerance` (one-way: it may only
     fall), and the budgets come from each package's performance ADR.
   - UNVERIFIED: AirspeedVelocity's CI action inputs and its `SUITE` conventions (check when scaffolding).
3. **Coverage floor: local, one-way, in `ratchets.toml`.**
   - CI runs `julia-actions/julia-processcoverage` on the stable job, producing `lcov.info`;
   - the factory's `scripts/ratchet.jl --lcov` (the `ci.jl coverage` step) compares line coverage
     (sum LH / sum LF) with `ratchets.toml` `coverage.floor` and fails below it;
   - `coverage.floor` **may only rise**: `ratchet.jl` fails any change that lowers it against the
     merge base. Lowering it needs an ADR and the user's decision, made by editing `ratchets.toml`
     (a T3 path), together with a debt-register entry.
   - **No external service** (no Codecov): it would need an account and a token, an
     outward-facing action.
   - *Amended at the L0 checkpoint:* the proposal named a `coverage-floor.txt` file read by a
     `scripts/coverage_floor.jl`; factory 0.2.2 keeps the floor in `ratchets.toml` instead (same
     one-way rule, one file for every ratchet), and this ADR follows the factory.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Apache-2.0 / BSD-3 | Both OSI-approved and acceptable; MIT is simplest. |
| PkgBenchmark | Less active (last push 2026-03); kept as the fallback. |
| A blocking benchmark job from day one | Early baselines are noisy and change with every engine rewrite; blocking would fail PRs for noise. |
| Codecov / Coveralls floor | An external account and token; a local floor is reviewable and needs no service. |
| A separate `coverage-floor.txt` + `scripts/coverage_floor.jl` | A second file and script for the same one-way rule that `ratchets.toml` and `ratchet.jl` already enforce. |

## Consequences

- The factory template carries `benchmark/` support, a benchmark CI job and the coverage step
  (`ratchet.jl --lcov` against `ratchets.toml`). It does not yet seed a `LICENSE` file: each repo
  (and the coordinator) needs an MIT `LICENSE` before its first push, and the factory should
  seed one (a follow-up for the factory lane).
- Factory 0.2.2's `Benchmark.yml` runs the factory's own `scripts/bench.jl` (BenchmarkTools, HEAD
  vs the merge base) and has no `continue-on-error`, so it is blocking. Moving it to
  AirspeedVelocity and warning-only is a factory change (a follow-up for the factory lane).

## Verification

- E-19 (General's license rule), E-33 (registry versions, `gh api` repo activity).
- UNVERIFIED: MIT's share of General; AirspeedVelocity's action inputs; the processcoverage output format.

## Revisit when

- A package's benchmark baselines settle (make its benchmark job blocking).
- AirspeedVelocity or PkgBenchmark is archived.
