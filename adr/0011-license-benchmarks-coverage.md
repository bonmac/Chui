# ADR-0011: License, benchmark tool and coverage floor

- **Status:** Proposed — all three are ★ questions for the user
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

## Decision (proposed; each item needs the user's answer)

1. **★ License: MIT** for every package and the coordinator repo. It is OSI-approved and the most
   common license in General (UNVERIFIED share). The `LICENSE` file is in place before any push.
2. **★ Benchmarks:**
   - each repo keeps `benchmark/benchmarks.jl` defining a BenchmarkTools `SUITE`;
   - **AirspeedVelocity** compares a PR against `main` in CI, because it is the more actively
     maintained of the two;
   - the regression threshold and the budgets come from each package's performance ADR.
   - UNVERIFIED: AirspeedVelocity's CI action inputs and its `SUITE` conventions (check when scaffolding).
3. **★ Coverage floor:**
   - CI runs `julia-actions/julia-processcoverage` on the stable job;
   - a small `scripts/coverage_floor.jl` compares line coverage with `coverage-floor.txt` in the repo;
   - the job fails below the floor. A PR may raise the floor, and only a PR that changes
     `coverage-floor.txt` together with a debt-register entry may lower it.
   - No external service is used (Codecov would need an account and a token: an outward-facing
     action). The julia-processcoverage output format is UNVERIFIED.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Apache-2.0 / BSD-3 | Both OSI-approved and acceptable; MIT is simplest. The user may pick one instead. |
| PkgBenchmark | Less active (last push 2026-03); kept as the fallback. |
| Codecov / Coveralls floor | An external account and token; a local floor file is reviewable and needs no service. |

## Consequences

- The factory template gets a `LICENSE` placeholder, `benchmark/`, a benchmark CI job and the coverage-floor script.

## Verification

- E-19 (General's license rule), E-33 (registry versions, `gh api` repo activity).
- UNVERIFIED: MIT's share of General; AirspeedVelocity's action inputs; the processcoverage output format.

## Revisit when

- The user answers the ★ questions.
- AirspeedVelocity or PkgBenchmark is archived.
