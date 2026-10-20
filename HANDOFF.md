# HANDOFF — Chui coordinator (lead)

Updated: 2026-10-20 · Phase: **L0 done (★ answered 2026-10-19: all recommendations accepted).** All five repos are public under `bonmac` (first push 2026-10-19). The first CI runs found clean-clone bugs in the factory; factory 0.2.5 fixes them and is synced everywhere, waiting for the user's push. Next: L1.

## State

- **Coordinator:** `main` (the main checkout `<root>`); the lead's worktree `.claude/worktrees/lead-l0` (branch `worktree-lead-l0`) trails it and can be removed at L1. Factory 0.2.4, profile coordinator. Spec: `docs/superpowers/specs/2026-10-19-coordinator-bootstrap.md`.
- **History rewritten (2026-10-19)** with `git filter-repo` so no tracked file or commit names the private reference projects. Content was unchanged by the rewrite (same tree). Commit hashes from before the rewrite no longer exist publicly; provenance comments now cite `ff0100a`. The unredacted history is only on the local branch `pre-redaction-backup`: **never push it**; delete it once the user confirms the push.
- **Machine-local, gitignored:** `.agents/factory.local.toml` (the real read-only roots, rendered by `scripts/gen.jl` into `.claude/hooks/read-only-roots.txt`) and `private/` (the full reference study, rewrite inputs, `redaction-patterns.txt`). `require_read_only_roots = true`, so bash_guard fails closed in a checkout without them.
- **Renamed 2026-10-19 (user decision): Junta → Chui.** ChuiCore, ChuiTypes, ChuiFrames; later ChuiStats, ChuiLearn, ChuiSpatial, ChuiPlot. Every name was checked against General's names (E-21).
- **Repos** (all public, `origin` = `https://github.com/bonmac/<name>`, only `main` pushed). Factory 0.2.5 everywhere; the first push carried 0.2.4:

  | Repo | Pushed | Local `main` (0.2.5) | Package tests on GitHub CI (first push) |
  |---|---|---|---|
  | `Chui` (this repo) | `b9a3c3c` | coordinator commit with the 0.2.5 sync and this HANDOFF | — |
  | `ChuiCore.jl` | `88291e5` | `06d2ae6` | pass: lts, 1, pre, macOS; Aqua/JET pass |
  | `ChuiTypes.jl` | `7d10c7a` | `db74452` | pass: lts, 1, pre, macOS; Aqua/JET pass |
  | `ChuiFrames.jl` | `f118874` | `d778f93` | pass: lts, 1, pre, macOS; Aqua/JET pass |
  | `ChuiRegistry` | `b307327` | same | empty registry (LocalRegistry 0.5.7) |

  First CI: Guards red in all four repos and Runic red in the packages, from factory bugs that only appear without the gitignored local files. Fixed in factory 0.2.5 (spec `docs/superpowers/specs/2026-10-20-factory-025-clean-clone.md`).

- **Julia:** `release` 1.13.2 (default), `lts` 1.10.12 and 1.11.7, all via juliaup.
- **Where to run the L1 lead:** from the main checkout `<root>`. Spawn package lanes with cwd = the package repo.
- **Hooks:** in the coordinator, `prompts/*`, `contracts/*`, the gate scripts and the factory machinery are T3 (`risk.toml`); write_guard blocks them unless the user sets `FACTORY_ALLOW_T3=1`. The lane cap is 6 (decision 12) <!-- claim: max_open=6 -->.
- **User-authorized T3 bypasses on 2026-10-19 (complete list):**
  1. **coord-setup:** the coordinator bootstrap (`.agents/agent-registry.toml` and the `coord_*` bodies, `risk.toml`, the skeletons).
  2. **The factory syncs** into the coordinator (0.2.0 onward), plus the lead's edit adding `.agents/factory.toml` to the T3 globs. Re-running the 0.2.4 sync on 2026-10-20 (only `.factory-version`'s `source_commit` changed) falls under this.
  3. **contracts-fixer:** the `contracts/` fixes after contracts-critic.
  4. **One `[check_docs] exclude`** in each package's `.agents/factory.toml` at scaffold time.
  5. **Package syncs** of 0.2.3/0.2.4 and their seeded-file edits (the ★ L0 answer, item 11).

## Open lanes

**L1 started 2026-10-20** (CI green on all pushed repos first: Guards, CI, Docs, Contracts).

| Lane | Repo | Worktree / branch | File scope | Status |
|---|---|---|---|---|
| core-p4 | ChuiCore.jl | `.worktrees/phase4-perf` / `feat/phase4-perf` | `src/**`, `ext/**`, `test/**`, `Project.toml`, `docs/**`, `benchmark/**`, `HANDOFF.md`, changelog fragment, `JuliaTestItems.toml` | running: phase 4 performance |
| types-p3 | ChuiTypes.jl | `.worktrees/phase3-effects` / `feat/phase3-effects` | same shape, plus `.gitignore` | running: phase 3 Reader/Writer/State + effect runtime (in review) |
| frames-p2b | ChuiFrames.jl | `.worktrees/phase2b-tidyr` / `feat/phase2b-tidyr` | same shape | running: rest of phase 2 (ADR-0021 timestamps, tidyr, ranking tail); a ★ on Parquet2 internals coming |

**Merged locally (2026-10-20), all reviewer-approved, tests re-run by the lead on 1.13.2 and 1.10.12:**
- ChuiCore: phase 1 (`8082735`), phase 2 traits and law kits (`20f5c14`), phase 3 schemes/transducers/optics/laziness/banner (`b4f1ca3`; requests R3, R5, R6, R7, R9 satisfied on main, unreleased). 3044 tests.
- ChuiTypes: phase 1 (`455c085`), phase 2 core data types (`dc1882c`; `LazyList` exception to ADR-0001 §4, user-approved). 474 / 461 tests.
- ChuiFrames: phase 1 (`c5db1cb`), phase 2 first milestone (squashed `10e8b9a`, recorded merged `1a2f1eb`): own Arrow IPC reader (spike gate passed), core verbs, CSV/Arrow/Parquet, printing. 3142 / 3112 tests.
- Coordinator: ADRs 0012–0014 Accepted; ADR-0007 §2 and ADR-0009 amended; requests R1–R10 filed (R8 answered: ChuiFrames owns `missing`-aware aggregators).
- Factory 0.2.6 (`944f407`; reviewer APPROVE WITH NITS; the user approved the sync including the sub-lane write loosening): synced into the coordinator (`183a2ad`) and the packages (ChuiCore `b601f05`, ChuiTypes `af12b4a`, ChuiFrames `7e39416`).

**Waiting on the user:** the T3 copy of `chui-core.md`, `chui-types.md` and `chui-frames.md` into `contracts/`, and the push (`user-steps.sh` in the lead's scratchpad). After the copy: commit the contracts, refresh the packages' vendored `test/contracts/` copies, push again.

**Parquet2 upstream bug (documented, not filed; user, 2026-10-20):** Parquet2 0.2.37 loses 1 ms on ~0.6% of INT64 timestamps (Float64 round trip). ChuiFrames works around it (ADR-0021). The issue draft and reproducer are in `ChuiFrames.jl/docs/research/upstream-parquet2-timestamps.md`; filing is optional and needs the user.

**Next decision for the user:** register a ChuiCore 0.0.1 snapshot in ChuiRegistry (request R4), so ChuiTypes and ChuiFrames can depend on the real ChuiCore and run their contract tests.

Closed this session (all reported; none went idle without a report):
- **pkg-core-024, pkg-types-024, pkg-frames-024:** 0.2.4 sync and history rewrite per package.
- **fix-core** (`acaec8c`), **fix-types** (`7d10c7a`), **fix-frames** (`f118874`): seeded-file gaps (runtests `:contract` filter, JET compat, `.gitignore`, untracked roots file in ChuiFrames), provenance re-pinned to `ff0100a`, HANDOFFs refreshed. The lead re-ran the diffs and the redaction gate.
- **factory-025** (`a89e10f`, fast-forwarded into `main`): factory 0.2.5; nudged once (it had missed the Runic item sent after dispatch), then reported in full. Worktree removed; branch `feat/factory-025` kept.
- Lead: synced 0.2.5 into the coordinator and the three packages (dry runs showed no conflicts).
- Lead: re-synced 0.2.4 into ChuiCore (`88291e5`) and the coordinator so `source_commit` no longer names a pre-rewrite commit.
- Earlier L0 lanes (ref-research, eco-architect, adr-critic, eco-reviser, factory-builder, contracts-writer/critic/fixer, coord-setup, factory-maint, factory-patch, factory-022/023/024, guard-rereview, coord-redact, cc-lessons, coord-review, scaffold-*, checkpoint-apply): done; see git history.

## Evidence

All actual runs (`subagent_mode: actual`).

- **Factory 0.2.5, fresh clones** (no `factory.local.toml` or roots file): `ci.jl guards: OK` in the coordinator (1149/1149) and all three packages (1199/1199 each); `ci.jl format: OK` in all three packages. Template tests 1356/1356 (lead re-run on 1.13.2; lane on 1.10.12 too). Reviewer: APPROVE WITH NITS on the full range.
- **Redaction gate** (`git log -p main` and every object reachable from `main`, grepped with `private/redaction-patterns.txt`): 0 hits in the coordinator and all three packages. Positive control: 187 hits on `pre-redaction-backup`, which is not an ancestor of `main`.
- **bash_guard** in the main checkout: `ls` → rc 0; a `uv run` inside a reference repo → rc 2.
- **Packages:** `ci.jl guards` OK in all three (factory tests 1189/1189); tests as in the table above.
- **Coordinator** (before the rewrite; content unchanged since): gen --check OK (26 files), check_docs OK, check_claims OK, ratchet OK, runtests 1139/1139, dod.jl DONE.

## Checks NOT run, and why

- **GitHub Actions:** no remotes yet; first run comes with the push.
- **`ci.jl contracts`:** no upstream is released.
- **`ci.jl format` (Runic):** not yet run in the packages.
- **ChuiCore on 1.10.12** after the follow-up: not re-run (the change was docs and `.factory-version` only).
- **AirspeedVelocity failure behaviour:** UNVERIFIED.
- **Lane cap:** whether teammates count toward the cap is UNVERIFIED.

## ★ ChuiCore phase 1 (asked 2026-10-20; only ChuiCore is paused)

1. ADR-0001: Monoid family as dictionary passing (instance values) with a Holy-trait classifier, not `MonoidStyle(::Type)`. Recommend yes.
2. ADR-0005: aggregation protocol, aggregators, transducers, optics, schemes public but not exported; amend ecosystem ADR-0009 ("ChuiCore exports `partial`"). Recommend yes (alternative: opt-in `ChuiCore.Prelude`).
3. ADR-0004/0008: own Lens/Prism, Accessors only as an extension, ConstructionBase as a hard dependency. Recommend yes.
4. Ecosystem ADR-0007 §2 (all packages): require `@check record=false` plus an explicit `@test`, plus a planted-violation test on LTS. Cause: Julia 1.10's `Test` counts only `DefaultTestSet` children (lead reproduced: 1.10.12 rc 0, 1.13.2 rc 1). Recommend amend, no upstream issue.
5. Contract CC-001 via a contract ADR: Chui-added `⨟` methods stay binary; the CompositionsBase fallback and a downstream closing varargs method may be variadic. Recommend yes.

**Answered 2026-10-20: all five accepted.** ChuiCore phase 1 merged (`8082735`, `3054d7c`); phase 2 running (core-p2). Coordinator amendments: eco-amend lane.

## ★ ChuiTypes phase 1 (asked 2026-10-20; only ChuiTypes is paused)

1. Accept ADRs 0001–0006 (two-slot parametric structs; `Effect{E,A}` as data with a trampoline and cooperative cancellation; cold pull streams in chunks; `ChuiTypes.Upstream` adapter; deps ScopedValues, ChuiCore snapshot, Compat; Task/Channel adapters). Recommend accept.
2. Contract chui-types.md obligation 2 is unimplementable as written (Base `fetch` always wraps; a foreign Task can't be cancelled without a canceller; `Die` crossing a Task boundary returns as `Fail`): amend via a contract ADR using ADR-0006's wording. Recommend yes.
3. Names: `Option`/`Either` (no aliases), `Effect{E,A}` without an environment parameter, `run` as a `Base.run` method, `interrupt!` + `await`, `this`/`that`/`both` public not exported. Recommend yes.
4. (Already decided at the ChuiCore ★: the `@check record=false` amendment.)
5. File requests R1–R5 to ChuiCore in `requests/` (R1 is partly answered by ChuiCore ADR-0001; R4 asks for a registered ChuiCore 0.0.1 snapshot, which is an outward action). Recommend yes.

**Answered 2026-10-20: all accepted** (ADRs, contract amendment via a contract ADR, names, requests). The contract ADR and the requests go to the eco-amend lane; registration (R4) comes back to the user.

## ★ ChuiFrames phase 1 (asked 2026-10-20; only ChuiFrames is paused)

`0c17098`, `13ac267`, `685bc6a` on `feat/phase1-research`: ADRs 0001–0020 Proposed; 4 critics, every one ending at 0 blockers / 0 majors; check_docs and lane audit OK (lead re-ran). Questions: own Arrow IPC reader (Arrow.jl reads Polars IPC as an empty table, LC-04); Parquet as a Parquet2 extension and Arrow writer in core (brief deviation); morsel parallelism in phase 3, not 5 (brief deviation); `rename(new = :old)` and `Not` from InvertedIndices. Draft requests (a)–(e) to ChuiCore/ChuiTypes are in the lane's report.

## ★ Contract changes (asked 2026-10-20; T3, the user applies)

eco-amend merged into main (`a414f1b`): ADR-0007 §2 and ADR-0009 amended (dated sections), contract ADRs 0012 (chui-core) and 0013 (chui-types) Proposed, requests R1–R5 filed. Critic APPROVE. The fully assembled proposed contracts are in the lead's scratchpad (`eco-amend/contracts/`); contracts/check.jl passes on them on 1.13.2 and 1.10.12. Questions: CC-001 amended in place or retired and reissued; IDs for CC-012/CC-013 only; confirm `neutral`/`curry`/`pure`/`ap`/`fmap` public, not exported; accept ADR-0012's proposed section P1–P6 and ADR-0013.

## L0 checkpoint decisions (answered 2026-10-19: all recommendations accepted)

ADRs 0001–0011 Accepted; contracts binding; 0.0.x snapshots; Julia floor 1.10; Runic; `c` plain export; `papply`, fixed empty-input exceptions, `neutral`, retired stubs; MIT, AirspeedVelocity (warning-only at first), local coverage floor; CompatHelper/TagBot via ChuiRegistry; factory sync once reviewed; lane cap 6. Item 13 (permission mode) had no recommendation and stays unchanged. GitHub owner `bonmac`, all public: `Chui` (this coordinator, redacted first), `ChuiCore.jl`, `ChuiTypes.jl`, `ChuiFrames.jl`, `ChuiRegistry`.

Open factory notes for the user: the CHANGELOG rule suggests 0.3.0 for stricter guards (kept 0.2.x); `git reset --merge`/`--keep`, `checkout -- .` and `restore .` are not blocked by bash_guard (user's call).

## Next action

1. The user pushes the 0.2.5 commits (bash_guard blocks `git push` for the lead); then the lead checks that every GitHub workflow is green.
2. `pre-redaction-backup` is deleted locally; one unredacted copy remains in the lead's session scratchpad (`chui-rewrite`), never pushed; delete when the user agrees.
3. The coordinator has no format job; Runic would flag `contracts/*.jl` and `reference/prototype/**` (open, low).
4. L1: relaunch the lead from `<root>` and start each package's phase 1 (Research and ADRs) as parallel lanes.
