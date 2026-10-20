# Factory 0.2.7: six fixes from 2026-10-20 lanes

- **Date:** 2026-10-20
- **Lane:** factory-027 (coordinator, `factory/**`)
- **Tier:** T3 in every repo that syncs it, because there these are CI workflow and process
  scripts. In the coordinator, `dod.jl` computes T2 for this diff: `factory/template/` paths are
  not protected there. The user approved the Benchmark workflow change.

Each problem was reproduced in a scratch repo built from the 0.2.6 template before it was fixed.
The reproductions are in the lane report.

## 1. The benchmark CI job did nothing for packages on CSV.jl 1.x

**Cause.** The 0.2.6 `Benchmark.yml` ran the AirspeedVelocity action. AirspeedVelocity depends on
JSON3 (1.0.0–1.14.3), and every JSON3 release caps Parsers at <= 2.8.8. CSV 1.0–1.1 needs Parsers
3.0.0. Pkg reports "Unsatisfiable requirements detected for package Parsers", both for
AirspeedVelocity 0.6.6 and for an unpinned AirspeedVelocity. Reproduced in a scratch depot on
2026-10-20, with the General registry as of that day.

**Change (approved by the user).** The job checks out with `fetch-depth: 0`, runs `ci.jl setup`,
then `julia scripts/ci.jl bench -- --base "origin/$BASE"`, with `BASE` set in the step's `env:` (see
S2 below). That is the
factory's own `scripts/bench.jl`: BenchmarkTools on HEAD and on the merge base, in a temporary
copy of `benchmark/Project.toml`. It needs no tool installed next to the package. The job stays
warning-only (`continue-on-error: true`, `timeout-minutes: 60`), as ADR-0011 requires.
`julia-actions/cache` is added, as in CI.yml.

**Base branch through `env:` (review S2, decided by the lead).** The first draft put
`${{ github.base_ref }}` straight into the `run:` shell line. A git branch name may contain `$(...)`,
backticks or `;`, so the shell would expand such a name. The risk was low: only someone with write
access to the base repo can create a branch, and the job token is `contents: read`. The lead chose
the standard hardening anyway: `env: BASE: ${{ github.base_ref || 'main' }}`, then
`julia scripts/ci.jl bench -- --base "origin/$BASE"`.

On `workflow_dispatch`, `github.base_ref` is empty and the base is `origin/main`. In a repo whose
default branch is not `main`, bench.jl then exits 2, and `continue-on-error` hides it. The workflow
header says so.

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
resolve and `refs/heads/<b>` exists. A resolving `origin/<b>` is still taken as given.
- An expression follows the same rule: `origin/main~1` becomes `main~1`.
- `base_note` prints a one-line notice wherever the fallback happens: `lane audit`, `dod.jl`,
  `ratchet.jl` and `bench.jl` (review S1).
- ratchet.jl reports "NOT RUN: no merge base with ..." when there is none.

**Review B1 (fixed).** `lane audit --base origin/<b>` is how a merged lane is audited against the
remote. In 6e579f3, when that ref did not resolve, the local `<b>` stood in for it. After a local
merge that branch already contains the lane, so the audit saw 0 files and passed. 0.2.6 had failed
the same case with "is not a commit here". Now:
- the 0.2.6 containment guard tests the resolved bases;
- when the fallback happened and the local `<b>` contains the lane's tip, the audit fails and says
  to fetch the remote or pass the commit before the merge.

dod.jl and ratchet.jl only print the notice. Run on the base branch after a local merge, they still
compare it with itself, as the register already says for that case.
Tests: no remote; a remote whose `origin/main` was deleted; `origin/nope`; and the degenerate
`origin/`, which never becomes `""`, meaning HEAD.

## 5. Bounded runs must kill the whole tree (added by the lead)

**Cause.** Lanes bounded runs with `perl -e 'alarm N; exec @ARGV' julia scripts/ci.jl test`. When
the alarm fires it kills ci.jl only. The child julia that `Pkg.test` started keeps running: a hung
property test ran for about 6 hours at 97% CPU.

**Change.** `ci.jl <job> --timeout SECONDS`, or the env var `CI_TIMEOUT` (the flag wins), bounds
the whole job.
- With a limit, each command is spawned detached. libuv then calls `setsid`, so the command gets
  its own session and process group, with pgid = its pid. Without a limit, behaviour is as in 0.2.6.
- On expiry: SIGTERM to the whole group, a 10 s grace, then SIGKILL to whatever is still in it.
  ci.jl prints `TIMED OUT after S s … This is not a pass.` and exits 124, as coreutils `timeout`
  does.
- A command that finishes in time also has any leftovers in its group killed.
- A bad value (`0`, `-1`, `soon`, a missing value) is exit 2.

**Test.** A planted hang in a scratch package: its test process writes its pid, starts a
grandchild `sleep 600`, and loops forever. The test checks:
- rc 124, within limit + grace + slack;
- both pids are dead;
- `pgrep -f <package dir>` finds nothing.

**Blind spots (in the register).**
- A process that leaves the group escapes: it calls `setsid` itself or is daemonized.
- If ci.jl itself is killed from outside (SIGKILL, or the old `perl -e alarm`), the detached group
  is NOT killed, because nothing is left to kill it. That is why the docs say to use `--timeout`
  instead of an outer alarm.
- On Windows only the leader process is killed.

Documented in the template `CLAUDE.md` Commands section and in the `lane-lifecycle` skill. The
coordinator's own `CLAUDE.md` is outside this lane (`factory/**`), so the lead adds the line there.

## 6. A plain `]test` on the LTS ran stable-only doctests (added by the lead)

**Cause.** The seeded `test/runtests.jl` skipped `:doctest`/`:snapshot` only when `CI_STABLE=false`.
Unset meant stable, so a fresh clone's `]test` on 1.10 ran them and failed. ChuiCore hit this in
its 0.0.1 release prep.

**Change.**
- One constant, `STABLE_MIN = v"1.13"`, the oldest Julia the doctests and snapshots are written
  against. It cites ADR-0008 §3.
- `is_stable(env, version)`: `CI_STABLE=true`/`false` decides, both ways, case-insensitively.
  Empty or unset means `VERSION >= STABLE_MIN`. Any other value is an error.
- CI.yml is unchanged: it still sets `CI_STABLE` per job (true on `'1'`, false on lts and pre).
  The block sits between markers, and `scripts/test/test_runtests_template.jl` evaluates it on its
  own. The test covers both defaults (1.10/1.12 not stable; 1.13/1.14 stable), both overrides, an
  empty value, a bad value and the ADR citation.
- In a package, `test/runtests.jl` is the package's own file (seeded, never overwritten by a sync),
  so the test checks the block only where it exists, and requires it only in the factory.

**Sync note.** Every package needs a hand edit of its `test/runtests.jl`; ChuiCore's release lane
is making its own. `STABLE_MIN` must be raised by hand when the ecosystem's stable line moves.

## Not in scope

- Syncing 0.2.7 into the coordinator or the packages: the lead syncs after review, and each
  package takes it in its own lane.
- The ADR-0011 amendment (the lead writes it in the coordinator).
- The coordinator's own `CLAUDE.md` line for `--timeout` (outside `factory/**`).
