# ADR-0011: License, benchmark tool and coverage floor

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint); decision 2's CI tool amended
  2026-10-20 for factory 0.2.7 (see "Amendment 2026-10-20"). The tool change is in force: the
  user approved the workflow change. Only the amendment's wording waits for the user's
  confirmation (★ below)
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
2. **Benchmarks: ~~AirspeedVelocity~~ the factory's `scripts/bench.jl` in CI** (amended
   2026-10-20; AirspeedVelocity was the L0 choice).
   - each repo keeps `benchmark/benchmarks.jl` defining a BenchmarkTools `SUITE`;
   - *Superseded 2026-10-20 (Amendment):* ~~**AirspeedVelocity** compares a PR against `main` in
     CI, because it is the more actively maintained of the two;~~ `scripts/bench.jl`
     (`julia scripts/ci.jl bench`) compares a PR's head against its merge base with the PR's base
     branch in CI, because AirspeedVelocity cannot be installed next to CSV.jl 1.x;
   - **the benchmark CI job is warning-only at first** (`continue-on-error: true`, or the
     equivalent), and becomes **blocking** once a package's baselines settle. Making it blocking
     is a T3 change to that repo's workflow, recorded in its CHANGELOG;
   - the regression threshold is `ratchets.toml` `bench.time_tolerance` (one-way: it may only
     fall), and the budgets come from each package's performance ADR.
   - *Superseded 2026-10-20 (Amendment):* ~~UNVERIFIED: AirspeedVelocity's CI action inputs and
     its `SUITE` conventions (check when scaffolding).~~ Moot now that CI does not run
     AirspeedVelocity. Factory 0.2.3 read the action's inputs from its `action.yml` (2026-10-19), and
     ChuiFrames PF-12 read the conventions from the 0.6.6 source.
   - See "Amendment 2026-10-20" below. The `SUITE`, warning-only and threshold bullets stand.
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
  - *Amended 2026-10-20:* factory 0.2.3 made that move (the AirspeedVelocity action, warning-only);
    factory 0.2.7 replaced the action with `scripts/bench.jl` and kept the job warning-only. See
    "Amendment 2026-10-20".

## Verification

- E-19 (General's license rule), E-33 (registry versions, `gh api` repo activity).
- UNVERIFIED: MIT's share of General; the processcoverage output format. (AirspeedVelocity's
  action inputs: moot since the 2026-10-20 amendment.)
- Amendment 2026-10-20: factory spec `docs/superpowers/specs/2026-10-20-factory-027-design.md` §1;
  ChuiFrames `docs/research/upstream-airspeedvelocity-json3.md` and PF-12 in its
  `docs/research/performance.md`. Not yet an E-number in `research/ecosystem-verification.md`.

## Revisit when

- A package's benchmark baselines settle (make its benchmark job blocking).
- AirspeedVelocity or PkgBenchmark is archived.
- AirspeedVelocity can be installed next to CSV.jl 1.x (see the amendment below).

## Amendment 2026-10-20: decision 2, the CI benchmark tool (factory 0.2.7)

The user approved the Benchmark workflow change in factory 0.2.7 (merged in the coordinator,
961b764; spec `docs/superpowers/specs/2026-10-20-factory-027-design.md` §1). The user's call on
the upstream defect was "Fix workflow; document only": no upstream issue is filed. This section
changes one bullet of decision 2; where it differs from that bullet, this section wins.

**What changed.**
- The template's `.github/workflows/Benchmark.yml` no longer runs the AirspeedVelocity action
  (added in factory 0.2.3). It checks out the full history (`fetch-depth: 0`), runs
  `julia scripts/ci.jl setup`, then `julia scripts/ci.jl bench -- --base "origin/$BASE"`.
- `BASE` is `${{ github.base_ref || 'main' }}`, passed through the step's `env:` and never written
  into the shell line, since a branch name may hold `$(...)` (factory spec, review S2).
- `ci.jl bench` runs the factory's `scripts/bench.jl`: BenchmarkTools on HEAD and on the merge
  base with `origin/<base>`, comparing median times. It needs no tool installed next to the
  package under test.
- So decision 2's "AirspeedVelocity compares a PR against `main` in CI" now reads: **`scripts/bench.jl`
  must be the CI comparison: a PR's head against its merge base with the PR's base branch.** On
  `workflow_dispatch` the base is `origin/main`. In a repo whose default branch is not `main`,
  bench.jl then finds no merge base and exits 2, which `continue-on-error` hides (the workflow
  header says so).
- **CI now applies the threshold.** Under the AirspeedVelocity action (0.2.3–0.2.6) CI reported
  without failing on a slowdown: its workflow header said so, and named `ci.jl bench` as the step
  to add later. From 0.2.7 a median slower than `bench.time_tolerance` allows turns the job red.
  `continue-on-error` keeps the PR mergeable. Factory 0.2.7 lists this among its stricter results.
- **New requirement:** `benchmark/Project.toml` must exist and list BenchmarkTools. bench.jl
  copies it into a temporary environment, and a missing file is an error, not a skip.
  AirspeedVelocity used it only when present (PF-12).
- **What CI no longer reports.** The action ran with its default `mode` `time,memory` and wrote a
  table to the job summary (`job-summary: 'true'`). bench.jl compares median time only and
  reports in the job log. The allocation comparison and the summary table are gone for every
  package, ChuiCore and ChuiTypes included, since the template is shared. Allocation budgets stay
  with each package's own checks (for ChuiFrames, ADR-0022 decision 6).
- Each package picks this up when it syncs factory 0.2.7. The coordinator profile has no
  `Benchmark.yml`. All three packages' `.factory-version` still say 0.2.6.

**Why.**
- AirspeedVelocity 0.6.6 adds JSON3 to every benchmark environment it builds. Every JSON3 release
  (1.0.0–1.14.3) caps Parsers at <= 2.8.8, and CSV 1.0–1.1 needs Parsers 3. Pkg fails with
  "Unsatisfiable requirements detected for package Parsers". So the action cannot build an
  environment for any package on CSV 1.x, ChuiFrames included. That was inferred from a local
  `Pkg` reproduction; the GitHub action itself was not run.
- Evidence: reproduced on 2026-10-20 in a scratch depot against General as of that day, both for
  AirspeedVelocity 0.6.6 and unpinned (factory spec §1); ChuiFrames
  `docs/research/upstream-airspeedvelocity-json3.md` and its PF-12 (AirspeedVelocity 0.6.6,
  JSON3 1.14.3, CSV 1.1.0, Parsers 3.0.0, Julia 1.13.2). ChuiFrames ADR-0022 decision 6 already
  adopts `ci.jl bench` "until AirspeedVelocity resolves with CSV 1.x". Not yet an E-number in
  `research/ecosystem-verification.md`.
- The command the job runs was checked locally on a scratch package on CSV 1.1.0 and Parsers
  3.0.0 (`bench.jl: OK`), and the workflow file with actionlint 1.7.12 (factory CHANGELOG 0.2.7).
  UNVERIFIED: the workflow has not yet run on a GitHub runner.

**What stays the same** (checked against decision 2 above).
- Each repo keeps `benchmark/benchmarks.jl` defining a BenchmarkTools `SUITE`.
- The job is **warning-only**: `continue-on-error: true` (with `timeout-minutes: 60`). It becomes
  blocking only once a package's baselines settle, by dropping `continue-on-error`: a T3 change to
  that repo's workflow, recorded in its CHANGELOG.
- The regression threshold is still `ratchets.toml` `bench.time_tolerance`: `0.10` in the template
  and in all three packages on 2026-10-20, one-way, so it may only fall. The value and the rule are
  unchanged; what is new is that CI applies it (see "What changed"). The budgets still come from
  each package's performance ADR.
- Decision 1 (MIT) and decision 3 (the coverage floor) are untouched.
- New caveat, not a new rule: the tolerance only means something on a quiet runner. A loaded
  machine gave false regressions of 1.12–1.20× on identical trees (factory 0.2.7), one more reason
  the job stays warning-only for now.

**Alternatives rejected** (factory spec §1).

| Alternative | Why rejected |
|---|---|
| Pin an older AirspeedVelocity | AirspeedVelocity's JSON3 range covers only releases that cap Parsers at <= 2.8.8, so no pin helps; an unpinned add with CSV 1 does not resolve either. |
| Wait for an upstream fix | The job would benchmark nothing for an unknown time. |
| PkgBenchmark | Kept only as the fallback in this ADR; `bench.jl` is already in the factory and tested. |
| File an upstream issue | An outward action; the user chose "document only". A draft text is in the ChuiFrames research note. |

**AirspeedVelocity can return.** If AirspeedVelocity drops JSON3, or JSON3 widens its Parsers bound,
so that it installs next to CSV.jl 1.x, the factory may switch back to its PR comparison and get the
memory table and job summary back. That is a factory change and a further amendment here. Until
then `bench.jl` is the CI tool.

**★ For the user:** confirm this amendment text (the workflow change itself is already approved).
