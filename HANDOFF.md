# HANDOFF — Chui coordinator (lead)

Updated: 2026-10-26 · Phase: **L1.** Lanes frames-p4 and types-p5 are running; ChuiCore 0.0.1 is waiting on the user's release script (see "Open lanes"). Earlier status (2026-10-20): ChuiCore 0.0.1 is merged and waiting for the user's release script (push, tag, register). ChuiTypes phase 4 and ChuiFrames phase 3 are merged. Factory 0.2.7 is merged and synced into the coordinator; the package syncs are running. Nothing since `1051a0d` (coordinator) is pushed. The current state is in "Open lanes" below; the sections further down are history.

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
| frames-p4 | ChuiFrames.jl | `.worktrees/phase4` / `feat/phase4` (integration); sub-lanes p4-groupby, p4-join, p4-codegen, then p4-bench | phase 4: grouped sinks, fast group-by, joins, codegen (plan `docs/superpowers/plans/2026-10-26-phase4.md`) | re-dispatched 2026-10-26 by the new lead (sub-lead teammate, max 3 sub-agents). Inherits `b51ca4e` (spec, plan, seam; unreviewed; the first execute.jl edit was made by a script, so the reviewer diffs it line by line). First: seam gate + critic + reviewer |
| ~~types-p5~~ | ChuiTypes.jl | **MERGED 2026-10-26: ChuiTypes main `57b78d7`** (user approved; ADR-0009 Accepted). The lead re-ran the suite on `a42e929`: 17283/17283 (1.13.2) and 17268/17268 (1.10.12), evidence `tests-lead-a42e929.txt` / `tests-lts-lead-a42e929.txt`; dod DONE. The worktree was removed, the branch kept, and the evidence copied to the main checkout's `.lanes/evidence/`. Agent closed. Open: item 1 (the ChuiCore 0.0.1 switch, blocked on the release); a quiet TTFX re-run before v0.1.0; follow-ups in ADR-0009 | was: its own `scripts/lane` worktrees → integration `feat/phase5` | phase 5 item 2 onward: sink pre-sizing, `fromiter` Vector fast path, per-chunk boxing, JET sites; TTFX dep-free workload + ADR-0009 budgets. Item 1 (the ChuiCore switch) waits for the 0.0.1 registration | re-dispatched 2026-10-26 by the new lead (sub-lead teammate, max 2 sub-agents). Inherits measurements only (`.lanes/reports/types-p5.md`, evidence `*p5*-08e9468.txt`) |
| tw-030 | coordinator | `.worktrees/tw-030` / `feat/tw-030` | `factory/template/scripts/**`, `factory/template/test/runtests.jl`, `factory/template/risk.toml`, `factory/template/.gitignore` (added by the lead: test_ci needs a root-level Manifest ignore line for the fixture Project.toml), plus the gen.jl-rendered `factory/template/.claude/hooks/protected-paths.txt` and `factory/template/.github/pull_request_template.md` (added by the lead: Task 7's risk.toml change regenerates them) | started 2026-10-26 (sub-lead teammate tw-build, max 2 sub-agents). Test-writer plan Tasks 1–7 only. Task 0, the T3 probe, is still owed and Task 8 waits on its result. Dogfood: fresh test subagents, then the implementer; reviewer FINAL before the lead merges |
| lead-1026 | coordinator | `.worktrees/lead-1026` | `HANDOFF.md`, `releases.md`, `compat-matrix.md` | the lead's own edits |

**Lead handover, 2026-10-26 (user: "make this session lead"):** two lead sessions were running. Session `0fe25a` (transcript `11d20fa9`) stood down at the new lead's request: it closed its frames-p4 and types-p5 lanes with WIP committed (frames `b51ca4e`; types had no tracked changes) and handed over. The new lead verified each claim (heads, clean trees, evidence files) before re-dispatching.

**Lead decisions, 2026-10-26 (no ★ in frames phase 4 or types phase 5):**
- ~~Join keyword `by =`~~ RETRACTED the same day: ChuiFrames ADR-0002 rule 16 (user-accepted) says `on =`, so the keyword is a user ★ (below).
- ChuiFrames p4-perf (approved): p4-bench found two quadratic `reduce(vcat, …)` concatenations. The allocation counts are load-independent.
  - Lazy gather in `src/columns.jl`: 945 MiB against 30 MiB, and lazy joins run 5–7× slower than eager.
  - Partitioned join in `src/engine/join_shapes.jl`: 8.6 GiB at p=8 for 4e6 rows.
  - A third issue is the per-row allocation of String keys in the hash-aggregate sink. That fired the ADR-0024 trigger.
  - Fixed in phase 4 by lane p4-perf, which runs after p4-bench merges because both own `benchmark/budgets.toml`. Allocation tests come first. No semantic change. Budgets are tightened only.
  - The partition-bits formula and parallel eager probes stay phase-5 follow-ups.
- p4-bench is merged into frames feat/phase4 as 5956626 (reviewer APPROVE WITH CONDITIONS, FINAL). The lead's rulings:
  - **dod waiver:** a lane-only waiver for a constant change without a test (`RADIX_SWITCH` 2^16 → 2^20). `dod.jl` at the final phase-4 head must pass with no waiver.
  - **ADR-0022 rule 1 note:** a dated note allows internal `_FORCE_*` switches in the SUITE. It goes to the user at the phase-4 ★ together with ADRs 0023–0025.
  - **ADR-0022 rule 1 draft note:** committed on feat/phase4 as f87784e. At the phase-4 ★, ask the user to accept both parts: the `_FORCE_JOIN`/`_FORCE_KERNEL` switches, and the SUITE building dictionary-encoded *inputs* with the internal `ChuiFrames.DictColumn`/`column`. The measured calls stay public.
  - **p4-perf started** from 1aa7bc2, which was green first: tests 14542/14542, t4 14543/14543, bench-check 138/138.
  - **p4-perf scope:** widened to `verbs_bind.jl` and `verbs_groups.jl`, which have the same `init` vcat pattern, plus memory rows.
- p4-perf is merged into frames feat/phase4 as b30cea3 (reviewer FINAL APPROVE WITH CONDITIONS, conditions fixed in 12ea449). Final reviewer preview on main...feat/phase4: one BLOCKER.
  - **B1 (CF-008):** a collected join side keeps unobserved dictionary levels, so `group_by(...; drop=false)` above a join shows n=0 groups that eager doesn't.
  - Fix lane p4-levels was approved by the lead. After it merges, the FULL gate set plus `dod.jl --base main` run at the new head, and the quiet window waits until then.
  - p4-levels merged as 9ef025e (reviewer FINAL APPROVE WITH CONDITIONS: 0/2880 bad cases at the lane head against 30/1806 at af85082; MINOR-1 fixed in 470c8fe, MINOR-2..5 recorded as phase-5 follow-ups). The full gate set runs at d410a46.
- Follow-up (lead-owned, before any ChuiFrames release): `scripts/changelog.jl fold` rejects fragments that hold Markdown headings, and that rule is by design. Fragments with `###` headings:
  - ChuiFrames: phase1-research, phase2-eager, phase2b-tidyr, phase2c-perf, phase3-lazy, and the phase-4 fragments;
  - coordinator: eco-amend, adr-0011-amend, frames-reqs, requests-p4p3, sync-027.

  Two fixes: rewrite those fragments as list items, and (factory 0.3.x) make `dod.jl`'s changelog requirement run the same heading check, so this is caught at lane time.
- tw-030 (test-writer Tasks 1–7): green on both versions (2216 tests on 1.13, 2211 on lts). Reviewer FINAL: REQUEST CHANGES, with three blockers where a guard falsely says OK:
  - **B1:** a typo inside a `@testset let` reads as BEHAVIOUR;
  - **B2:** `red --rev` evidence is keyed to HEAD;
  - **B3:** dod `tdd` passes with 0 commits;
  - plus majors M1–M3. Being fixed TDD-style, then re-review.
- The lead's rulings on tw-030:
  - **H6:** several consecutive reds may be closed by one green when every item passes. Written into spec §4.2 as a dated note.
  - **Renamed red item:** must not deadlock. The way out is a `TDD: test-fix` commit with fresh red evidence. Required before the 0.3.0 VERSION bump (Task 9).
  - **Scope:** owns extended to the spec and plan files.
- Needs the user: remove the stray gitignored worktree `.worktrees/tw-030-verify` (detached at e9b3249). Its only diff is an older, superseded `_tdd_backfill.jl` variant, so nothing is lost. bash_guard blocks `git worktree remove --force` from the agents. Command: `! git worktree remove --force .worktrees/tw-030-verify`.
- Process deviation (frames p4-bench): the lane made one python3 heredoc edit on new, uncommitted benchmark/compare files, against the Edit/Write rule. The reviewer checks the committed content. The p4-perf brief restates the rule.
- ChuiTypes TTFX: the dep-free guarded precompile workload, not PrecompileTools. No new dependency and no ADR-0005 change. Indicative numbers (loaded machine): 1.13.2 workload 1.69 s → 0.269 s; 1.10.12 1.23 s → 0.150 s.

**2026-10-26, new lead session:** the previous session's lanes sync-027-types (`08e9468`), sync-027-frames2 (`bc8c97a`) and requests-p4p3 (`3ef6d64`) were already merged.

**ChuiCore 0.0.1 release (user, 2026-10-26: "push, tag, register"):** bash_guard needs `FACTORY_ALLOW_PUSH=1`, which only the user sets. So the user runs `bash private/release-chuicore-001.sh` (gitignored) in their own terminal:
1. push the four mains;
2. wait for green ChuiCore CI on `aaca78f`;
3. clean clone, then tag `v0.0.1`;
4. LocalRegistry 0.5.7 `register(...; push=false)` into `ChuiRegistry/`;
5. confirm, then push the registry.

Redaction gate before the push: 0 hits in new history and in the tree for all four repos. Positive control: 12 hits on `private/reference-projects.md`.

## ★ ChuiFrames phase 4 joins (asked 2026-10-26; only lane p4-join is paused; group-by and codegen continue)

The critic on the phase-4 spec found that the join design departs from user-accepted ADRs and from the parity matrix. The contract lists joins as provisional, so no contract change is involved.
1. **Join keyword:** ADR-0002 rule 16 says `on = :k` / `on = [:a => :b]`. The spec uses dplyr's `by =`. Recommend `by =` with a dated ADR-0002 amendment: the brief targets dplyr parity, and rule 16's reason (`==` on nodes is structural) concerns the expression form, not the keyword's name. The alternative keeps `on =` with no amendment.
2. **ADR-0003 rules 4 and 11:** always build the hash table on y, and radix-partition only y. x probes per morsel in parallel, which keeps dplyr's row order without a sort. The accepted text has the cost stage choose the build side and partitions both sides. Recommend accepting this as a dated amendment, recorded in ADR-0023, with the thresholds checked in p4-bench. The alternative builds on the smaller side and restores the order with a sort.
3. **Parity:** ship `cross_join` and equality-only `join_by(:a => :b)` in phase 4. Defer `nest_join` and inequality/rolling joins, and update the parity-matrix rows. Also add the DataAPI `innerjoin`/`leftjoin`/… methods (ADR-0007, not a deviation). Recommend yes.

**Answered 2026-10-26 (user):** (1) `by =`, with a dated ADR-0002 rule 16 amendment. (2) **Keep ADR-0003** as written: build on the smaller side, partition both sides above the broadcast limit, and restore dplyr's order with a stable sort. (3) **The full matrix:** `nest_join`, `cross_join` and equality `join_by` in phase 4, plus the DataAPI methods. Inequality/rolling joins stay deferred because no design exists. Sent to frames-p4; p4-join starts after group-by tasks 1–2 merge.

**K4, asked and answered 2026-10-26 (user):** mixed `Int64`/`Float64` join keys are **allowed, like dplyr**: compared as Float64, with the precision loss above 2^53 documented. Date/DateTime and Int64/UInt64 pairs stay rejected because they hash inconsistently.

**ChuiFrames ADR-0003 rule 12, asked and answered 2026-10-26 (user): both changes accepted.** `INTERP_THRESHOLD` goes from 10⁵ to 5×10⁵ (measured 18–45 ms per new shape), and the limit counts operations, not depth: more than 50 `Call`/`case_when` nodes summed over a stage's steps. This is a dated note on rule 12, recorded in ADR-0025. ADRs 0023–0025 stay Proposed until the user accepts them at the phase-4 merge, after a critic FINAL on their final text. **Further user answers the same day, all accepted:** rule 12's third change (an unknown row count runs the interpreter unless cached); ADR-0024's phase-4 narrowing of rules 3 and 5 (only simple aggregates over plain keys stream; the rest gather and run eagerly; MapM/ReduceM keep untyped state; these go on the phase-5 follow-up list); rule 11's `:never` follows dplyr (NaN matches nothing; the DuckDB difference is noted); and an ADR-0002 rule-16 `join_by` addendum. The ADR critic's FINAL on 3bc2be9: ACCEPT WITH CHANGES, no blockers. A small fix lane (p4-joinfix) makes `DataAPI.innerjoin(...; on=, by=)` throw instead of silently using `by`.

**nest_join name clash, asked and answered 2026-10-26 (user):** replace the clashing x column like dplyr, and emit a warning that can be silenced. (The spec had an ArgumentError.) Other architect decisions accepted by the lead: `name = :y` default; `join_by` equality pairs only (the dotted form is deferred with inequality/rolling); `nest_join` reuses `nest`'s representation.

**Test-writer role (user request 2026-10-26: "separate the tester from the implementer to have separate contexts and valid testing as per TDD"; then "write any missing tests once done").** The design is MERGED into coordinator main as `87a0a7c`: spec `docs/superpowers/specs/2026-10-26-factory-test-writer-design.md`, plan `docs/superpowers/plans/2026-10-26-factory-test-writer.md`, **ADR-0015 Accepted** (user). History: 4 critic rounds, then the reviewer's APPROVE WITH NITS (nits fixed in `8b7e523`, checked by the lead). User decisions: topology (a), the coordinator dispatches a fresh test-writer and implementer per task; an implementer test edit FAILS; STUB commits; backfill proved by src mutation in a separate mutator agent (mutexp only as a justified fallback); a 2 h cap per backfill lane; the coverage floor is set by the user to measured − 1 point; 0.3.0 builds on 0.2.8. **Next:** the factory-028 lane (lane-cap fix, running) → review → the user restarts the lead with `FACTORY_ALLOW_T3=1` → sync 0.2.8 → 0.3.0 plan Task 0 (the agent_type probe, T3) → Tasks 1–13 → backfill lanes (ChuiCore first, after its v0.0.1 tag; ChuiTypes now that phase 5 is merged; ChuiFrames after phase 4).

**Factory 0.2.8 MERGED into coordinator main `c667a95` (template only, 2026-10-26).** The lane cap counts Agent dispatches. It adds `scripts/lane release <key>` for a gone agent, a dispatch lock, fail-closed on bad locks and payloads, and unknown statuses keep a lane counted. Reviews: the critic ACCEPT WITH FIXES, then the reviewer REQUEST CHANGES, then APPROVE WITH NITS on the delta; m1′ was fixed in `3501f3a` and reviewed by the lead (the race probe GREEN). Lead re-run: 1581/1581 factory tests on 1.13.2 (the lane: 1581/1581 on 1.10.12). Spec `docs/superpowers/specs/2026-10-26-factory-028-design.md`. **Not yet synced anywhere:** the coordinator sync (`add=1 update=10`, no conflicts in the dry run) and the package syncs are T3. **★ for the user:** restart the lead with `FACTORY_ALLOW_T3=1` in its environment. Restarting ends this session's in-process teammates (frames-p4 and its lanes), so pick a moment when frames-p4 has committed and reported; the lead asks it to checkpoint first. Never live-tested in a real session until the sync.

**Factory bug found 2026-10-26 (test-writer critic r3 m6; the lead verified it): the lane cap is not enforced.** `dispatch_limit.sh` counts open lanes from the ledger's `start` minus `stop` events. Since 2026-10-20, agents run as in-process teammates, which log no SubagentStart: the last `start` is 2026-10-20T14:12Z, against 709 `stop`s. The count is always 0, so the cap of 6 never fires. The hook does fail closed on a malformed ledger, but not on missing starts. Relatedly, the package roles (implementer, law-/property-/differential-tester) have never run: the lead session sees only the coordinator's `.claude/agents/`, so every package lane has been general-purpose with its rules in the brief. The fix is a factory change (T3, user). It goes into the test-writer 0.3.0 work or a 0.2.8 patch, as the user prefers. Until then the lead keeps the cap by hand (current: frames-p4 + its 3 sub-agents, testwriter-spec).

**Quiet-machine timings deferred (user, 2026-10-26):** the 1-min load never fell below 2, because another project's CI and a second Claude session were running, not Chui. ChuiTypes: ADR-0009 cites the p5-ttfx lane figures as measured under load, and a quiet TTFX re-run is required before v0.1.0. ChuiFrames: the ttfx.jl/run.jl timing checks re-run quietly before the phase-4 merge into main. Allocation checks are load-independent and stay binding per lane.

**ChuiTypes p5-perf (lead decisions, 2026-10-26; phase 5 has no ★):**
- Q1: accept the missed spec time targets. S1 is 3.8× Base collect (target ≤ 2.5×) and S2 is 22× Base foldl (target ≤ 10×). Both improve on the recorded 5.5×/43×. ADR-0009 records them as the budget, with "fold runfold into the fused pipeline" as a follow-up. ADR-0003's "costs what an iterator does" gets a dated note that the claim is **not met**; its decision text is the user's and is unchanged.
- Q2: `merge` over 4 Vector sources regressed by about 1.5×. One bounded fix attempt; otherwise a benchmark row and a known loss in ADR-0009.

**Lesson (2026-10-20):** a spawned agent's write_guard root is the lead's cwd when it is spawned. `cd` into the target repo or worktree before spawning a lane (the memory dir is outside the root, so this note lives here).

**Merged 2026-10-20 (afternoon), all with a final reviewer approval:**
- **ChuiCore 0.0.1 release** (`aaca78f`): changelog folded; seeded runtests skips `:doctest`/`:snapshot` by `VERSION < STABLE_MIN` (1.13) when CI_STABLE is unset (fresh-clone fix). Evidence: plain test with CI_STABLE unset passes on 1.13.2 (3369/3369) and 1.10.12 (3262/3262). **User runs** `scratchpad/release-chuicore-001.sh`: push all mains, wait for ChuiCore CI on `aaca78f`, tag v0.0.1, LocalRegistry register (push=false), confirm, push ChuiRegistry. Then the lead adds the releases.md row, runs integration, and fills in compat-matrix. ChuiCore's 0.2.7 sync waits until after the tag.
- **ChuiTypes phase 4, futures and streams** (`6ee5fac`): Queue, Stream, combinators, time operators, Subject, marbles; ADR-0008 accepted; ADR-0003 §5 and ADR-0004 §2 amended (user ★). `test -- all` 17227 (1.13.2) / 17212 (1.10.12). Phase-5 item 1: switch the Upstream stand-ins to ChuiCore 0.0.1; then the cost claim (fused ≈5.5× Base, runfold ≈43× foldl).
- **ChuiFrames phase 3, lazy engine and Part A** (`d3bcec8`): lazy/collect/optimize/explain/code_lowered; R-total (filters never move past mutate, accepted for v0); eager replay as CF-008's mechanism; grouped sinks deferred to phase 4; lazy budgets use the ADR-0022 rule-2 formula. Suites 8511 / 8473 / 8512 (-t 4). Pending: a -t 4 CI job (user-approved, T3: needs the user's `FACTORY_ALLOW_T3=1`); a quiet-machine ttfx re-run (1.13 loaded run: 421 of 500 ms); stale AirspeedVelocity mentions in ChuiFrames' benchmark/, ADR-0022 and HANDOFF.
- **Factory 0.2.7** (`961b764`), synced into the coordinator (`3501ac3`): ci.jl bench, `ci.jl --timeout` (kills the process group), signals in evidence, base fallback, runtests stable by version. **ADR-0011 amended** (`f71c76c`; wording confirmed by the user).
- User: coordinator `ratchets.toml` keeps its old comment (no T3 edit).

**Merged locally (earlier 2026-10-20), all reviewer-approved, tests re-run by the lead on 1.13.2 and 1.10.12:**
- **ChuiCore: all five phases done** (`e124ed3`): traits and law kits, schemes/transducers/optics/laziness, performance (ADR-0009/0010 accepted; PrecompileTools), docs site (10 tutorials, doctests), `__init__` banner (invokelatest; fires on any interactive load; user-accepted). 3369 tests. **Next: v0.1.0, needs the user** (release checklist in ChuiCore's HANDOFF).
- ChuiTypes: phases 1–3 (`bd8bcc0`): core data types; Reader/Writer/State (ADR-0007) and the effect runtime (structured concurrency, cancellation, resources, test mode). 875 / 860 tests (`test -- all`).
- ChuiFrames: phases 1–2 (`5896de6`): own Arrow IPC reader, dplyr/tidyr verbs, timestamps (ADR-0021), CSV/Arrow/Parquet, printing, budgets (ADR-0022), Polars/DuckDB differentials. 4833 tests. The 1.13 load budget (487 of 500 ms under load) needs a quiet re-run before release.
- Coordinator: contracts updated (`e206271`; ADR-0012/0013/0014), vendored copies refreshed in the packages; factory 0.2.6 everywhere.

**Documented, not filed (user):** Parquet2 1-ms timestamp bug (`ChuiFrames.jl/docs/research/upstream-parquet2-timestamps.md`); AirspeedVelocity cannot install with CSV.jl 1.x.

**Pending coordinator items:** a `chui-frames.md` note that `frame_equal` ignores the `drop` flag (T3, user); chui-types obligations 1–2 can become ID'd entries once phase-4 streams land (types-p3 request R-b).

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
- **AirspeedVelocity:** replaced by `ci.jl bench` (ADR-0011 amendment, 2026-10-20); the new Benchmark.yml has not run on a GitHub runner yet.
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

ADRs 0001–0011 Accepted; contracts binding; 0.0.x snapshots; Julia floor 1.10; Runic; `c` plain export; `papply`, fixed empty-input exceptions, `neutral`, retired stubs; MIT, AirspeedVelocity (warning-only at first; replaced by `ci.jl bench`, ADR-0011 amendment 2026-10-20), local coverage floor; CompatHelper/TagBot via ChuiRegistry; factory sync once reviewed; lane cap 6. Item 13 (permission mode) had no recommendation and stays unchanged. GitHub owner `bonmac`, all public: `Chui` (this coordinator, redacted first), `ChuiCore.jl`, `ChuiTypes.jl`, `ChuiFrames.jl`, `ChuiRegistry`.

Open factory notes for the user: the CHANGELOG rule suggests 0.3.0 for stricter guards (kept 0.2.x); `git reset --merge`/`--keep`, `checkout -- .` and `restore .` are not blocked by bash_guard (user's call).

## Next action

1. **User:** run the ChuiCore 0.0.1 release script (it also pushes every repo's main). Then the lead adds releases.md, runs integration, fills compat-matrix, and syncs 0.2.7 into ChuiCore.
2. Lead: merge sync-027-types and sync-027-frames2 after their final reviews; land requests-p4p3 through a coordinator-rooted agent. The user copies the contract drafts (`scratchpad/contracts-p3p4/`) into `contracts/` (T3).
3. ChuiFrames -t 4 CI job: needs the user's `FACTORY_ALLOW_T3=1`.
4. Next phases: ChuiTypes phase 5 (switch to ChuiCore 0.0.1, then cost); ChuiFrames phase 4 (grouped sinks, joins); ChuiCore post-0.0.1.
5. Unanswered offer: delete the unredacted `chui-rewrite` clone in the scratchpad. The coordinator still has no format job (low).
