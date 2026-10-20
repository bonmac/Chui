# Factory 0.2.7: four fixes from 2026-10-20 lanes

- **Date:** 2026-10-20
- **Lane:** factory-027 (coordinator, `factory/**`)
- **Tier:** T3 (CI workflow, process scripts). The user approved the Benchmark workflow change.

Each problem was reproduced in a scratch repo built from the 0.2.6 template before it was fixed.
The reproductions are in the lane report.

## 1. The benchmark CI job did nothing for packages on CSV.jl 1.x

**Cause.** The 0.2.6 `Benchmark.yml` ran the AirspeedVelocity action. AirspeedVelocity depends on
JSON3 (1.0.0–1.14.3), and every JSON3 release caps Parsers at <= 2.8.8. CSV 1.0–1.1 needs Parsers
3.0.0. Pkg reports "Unsatisfiable requirements detected for package Parsers", both for
AirspeedVelocity 0.6.6 and for an unpinned AirspeedVelocity. Reproduced in a scratch depot on
2026-10-20, with the General registry as of that day.

**Change (approved by the user).** The job checks out with `fetch-depth: 0`, runs `ci.jl setup`,
then `julia scripts/ci.jl bench -- --base origin/${{ github.base_ref || 'main' }}`. That is the
factory's own `scripts/bench.jl`: BenchmarkTools on HEAD and on the merge base, in a temporary
copy of `benchmark/Project.toml`. It needs no tool installed next to the package. The job stays
warning-only (`continue-on-error: true`, `timeout-minutes: 60`), as ADR-0011 requires.
`julia-actions/cache` is added as in CI.yml.

**Noise.** `bench.time_tolerance` only means something on a quiet runner: on a loaded machine,
identical trees measured 1.12–1.20× slower. This is documented in `ratchets.toml`, in `bench.jl`
and in the ratchet row of the check register. It is one more reason to keep the job warning-only.

**Rejected alternatives.**
- Pin an older AirspeedVelocity: 0.6.6 is the newest, and an unpinned `Pkg.add` with CSV 1 finds
  no version that resolves either.
- Wait for an upstream fix: the job would stay empty for an unknown time.
- PkgBenchmark: ADR-0011 keeps it only as the fallback. bench.jl is already in the factory and tested.

**ADR-0011 follow-up.** ADR-0011 decision 2 names AirspeedVelocity as the tool that "compares a PR
against `main` in CI". Its Consequences call moving to AirspeedVelocity a factory follow-up. After
0.2.7 the factory uses `scripts/bench.jl` instead, so the ADR no longer describes the factory.
**ADR-0011 needs a dated amendment** (for the user, since the ADR is accepted), along these lines:

> *Amended 2026-10-20 (factory 0.2.7):* AirspeedVelocity 0.6.6 cannot be installed next to
> CSV.jl 1.x (JSON3 1.14.3 caps Parsers at <= 2.8.8; CSV needs Parsers 3). The benchmark job runs
> the factory's `scripts/bench.jl` (`ci.jl bench`, BenchmarkTools, HEAD vs the merge base with
> `origin/<base>`), still warning-only, with the same `bench.time_tolerance` ratchet.
> AirspeedVelocity may return when its dependency bounds allow CSV 1.x.

"Revisit when" could also gain: "AirspeedVelocity can be installed next to CSV.jl 1.x".

## 2. check_docs read Documenter links as paths

**Cause.** The link pattern `\]\(([^)\s]+)\)` matches a bare Documenter link (link text, then `(@ref)`), and `@ref` was resolved as a
relative path. `[x](@ref Target)` and `[x](@ref "Heading")` never matched, because the pattern
stops at whitespace.

**Change.** Skip a link target that is exactly `@ref`. Tests cover both forms and a nested
`(@ref Mod.f(::Int))`, and check that `@refs.md`, `./@ref` and `@ref/x.md` are still read as paths.
Documenter's own build checks whether the target exists; the register row says so.

## 3. evidence.jl hid signals

**Cause.** `Base.Process.exitcode` is 0 for a process killed by a signal, and `termsignal` holds
the signal. evidence.jl recorded only `exitcode`.

**Change.** Record `termsignal: N` (0 when none). A signalled run exits 128 + N, as a shell
reports it, and the summary line says `KILLED by signal N: not a pass`. check_claims returns no
totals from such a file, so a test-count claim citing it is UNVERIFIED. A partial `Test Summary:`
printed before the kill is not evidence. 0.2.6 files have no `termsignal` line and read as before.

## 4. Merge bases without a tracking ref

**Cause.** In 0.2.6 `base_ref` took any `origin/<b>` as given. When it did not resolve (no
remote, a pruned or deleted tracking ref), `merge_base` returned nothing:
- `dod.jl --base origin/main` failed with rc 2;
- `lane audit --base origin/main` failed with "is not a commit here";
- `ratchet.jl` skipped its one-way check and said "no ratchets.toml at the merge base".

A plain `main` already worked with no remote (the 0.2.6 tests cover that).

**Change.** `base_ref("origin/<b>")` falls back to a local `<b>` only when `origin/<b>` does not
resolve and `refs/heads/<b>` exists. A resolving `origin/<b>` is still taken as given. `lane audit`
checks the resolved base. ratchet.jl reports "NOT RUN: no merge base with ..." when there is none.
Tests: no remote; a remote whose `origin/main` was deleted; `origin/nope`; and the degenerate
`origin/`, which never becomes `""`, meaning HEAD.

## Not in scope

- Syncing 0.2.7 into the coordinator or the packages: the lead syncs after review, and each
  package takes it in its own lane.
- The ADR-0011 amendment itself (the user's).
