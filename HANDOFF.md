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
| ~~frames-p4~~ | ChuiFrames.jl | **MERGED 2026-10-27: ChuiFrames main `7dea782`** (phase 4: joins, fast group-by, compiled kernels). The final reviewer gave APPROVE WITH CONDITIONS at 365a3d0. The user accepted ADRs 0023–0025 and the ADR-0022 rule 1 note. Gates passed at d410a46; later commits are docs only. The lead re-ran the tests at 35ec523: 14788/14788 (1.13) and 14740/14740 (1.10), evidence `tests{,-lts}-lead-35ec523.txt`, copied to the main checkout's `.lanes/evidence/`. dod DONE. The worktree is removed and the branch kept; reports are in `.lanes/archive/phase4/`. The sub-lead is closed. **Before the first release:** the quiet timing run (ttfx and run.jl `--check` on 1.13 and LTS, `ci.jl bench` against main), which also decides the met revisit triggers in ADRs 0023/0024; the changelog `###` fix. Phase-5 follow-ups are in ChuiFrames HANDOFF | was: `.worktrees/phase4` / `feat/phase4` (integration); sub-lanes p4-groupby, p4-join, p4-codegen, then p4-bench | phase 4: grouped sinks, fast group-by, joins, codegen (plan `ChuiFrames.jl/docs/superpowers/plans/2026-10-26-phase4.md`) | re-dispatched 2026-10-26 by the new lead (sub-lead teammate, max 3 sub-agents). Inherits `b51ca4e` (spec, plan, seam; unreviewed; the first execute.jl edit was made by a script, so the reviewer diffs it line by line). First: seam gate + critic + reviewer |
| ~~types-p5~~ | ChuiTypes.jl | **MERGED 2026-10-26: ChuiTypes main `57b78d7`** (user approved; ADR-0009 Accepted). The lead re-ran the suite on `a42e929`: 17283/17283 (1.13.2) and 17268/17268 (1.10.12), evidence `tests-lead-a42e929.txt` / `tests-lts-lead-a42e929.txt`; dod DONE. The worktree was removed, the branch kept, and the evidence copied to the main checkout's `.lanes/evidence/`. Agent closed. Open: item 1 (the ChuiCore 0.0.1 switch, blocked on the release); a quiet TTFX re-run before v0.1.0; follow-ups in ADR-0009 | was: its own `scripts/lane` worktrees → integration `feat/phase5` | phase 5 item 2 onward: sink pre-sizing, `fromiter` Vector fast path, per-chunk boxing, JET sites; TTFX dep-free workload + ADR-0009 budgets. Item 1 (the ChuiCore switch) waits for the 0.0.1 registration | re-dispatched 2026-10-26 by the new lead (sub-lead teammate, max 2 sub-agents). Inherits measurements only (`.lanes/reports/types-p5.md`, evidence `*p5*-08e9468.txt`) |
| ~~tw-030~~ | coordinator | **MERGED 2026-10-26 into coordinator main as 0769a01** (factory 0.3.0 part 1, test-writer Tasks 1–7; not versioned or synced). Reviewer: REQUEST CHANGES (B1–B3, M1–M3), all fixed test-first, then APPROVE WITH NITS. The lead re-ran 2283/2285 (1.13.2) and 2278/2280 (1.10.12), with 2 version-gated skips; evidence `.lanes/evidence/tests{,-lts}-lead-fc3aa23.txt`. The lead fixed the fragment (root paths, no `###`) in b216903. 19 sub-agents ran, all closed. Worktree removed; report in `.lanes/archive/tw-030/`. Remaining: Task 0 (T3 probe), Tasks 8–10 (Task 9 must fix the renamed-red deadlock), 11, 12 | was: `.worktrees/tw-030` / `feat/tw-030` | `factory/template/scripts/**`, `factory/template/test/runtests.jl`, `factory/template/risk.toml`, `factory/template/.gitignore` (added by the lead: test_ci needs a root-level Manifest ignore line for the fixture Project.toml), plus the gen.jl-rendered `factory/template/.claude/hooks/protected-paths.txt` and `factory/template/.github/pull_request_template.md` (added by the lead: Task 7's risk.toml change regenerates them) | started 2026-10-26 (sub-lead teammate tw-build, max 2 sub-agents). Test-writer plan Tasks 1–7 only. Task 0, the T3 probe, is still owed and Task 8 waits on its result. Dogfood: fresh test subagents, then the implementer; reviewer FINAL before the lead merges |
| f040 | coordinator | `.worktrees/f040` / `feat/f040` | `factory/**`, `adr/0016*`, `docs/superpowers/**`, `changelog.d/f040.md` | factory 0.4.0: the harness fails closed, read-only agents are enforced, and a review protocol. Started 2026-10-27 by the **second coordinator session `julia-data-analysis-e1`**, which reports the user asked for it and chose "start now, reviewed rebase after tw-031 merges". This lead session did not see that request. Its scope overlaps tw-031 (`factory/**`), so f040 rebases after tw-031 and the 0.3.0 coordinator sync; the lead will message e1 then.

**Agreement with e1 (user: "do not conflict", 2026-10-27):**
- e1 merges only inside `.worktrees/f040` and never runs `git merge` in `<root>`.
- Nothing under `factory/**` goes to main until the lead's OK, and each session asks the other before any merge into main.
- VERSION 0.4.0 sits on top of 0.3.0.
- The rebase gets its own reviewer, and e1 also runs `test_hooks_tdd*.jl`.
- HANDOFF stays the lead's.
- e1's f040-hooks fixes a heredoc-terminator bypass in bash_guard's splitter. That bypass is in the 0.2.8 hooks running now |
| ~~tw-034 (factory 0.3.1)~~ | coordinator | **MERGED 2026-10-27 into coordinator main as b4aeda3.**
- Reviewer: REQUEST CHANGES ×1 (FIX-1: an untested `must_pass` removal, now pinned by 85251d8), then APPROVE FINAL. tw-034 reported 3581/3583 (1.13, T3 set) and 3576/3578 (1.10) at e96d382, plus FACTORY_GUARD_FULL 772/0/0. The lead re-ran the factory suite at the tip 85251d8: 3591 pass, 2 broken, rc 0.
- A scratch package-profile sync passed `ci.jl format`.
- The named resolver is `owning_ledger`. e1 is told; sync-frames-030 is told to re-sync to 0.3.1.
- Breaches, recorded in the CHANGELOG: a python edit of `tdd_commit_post.sh`, reviewed line by line; an untested clause, removed and pinned.
- Reviewer NOTEs 1–4, 7 and 8 are open, minor; NOTE-3 (LEDGER_FILE not restored) is passed to e1.
- Worktree removed, report in `.lanes/archive/tw-034/`.
- 0.3.1 sync lanes:
  - **sync-031 (coordinator)**: `.worktrees/sync-031`, agent sync-031-coord, also fixing spec §0.5 and the E5 row;
  - **sync-031 (ChuiTypes)**: `ChuiTypes.jl/.worktrees/sync-031`, agent sync-031-types; fixes main's red `ci.jl format`;
  - **ChuiFrames:** sync-frames-030 re-syncs to 0.3.1.

The original row follows. | — | — |
| (was) tw-034 | coordinator | `.worktrees/tw-034` / `feat/tw-034` | `factory/**` | started 2026-10-27 (sub-lead tw-034). It fixes what the live smoke lane exposed in 0.3.0:
1. `ci.jl format` FAILS in every package on 0.3.0, because the template scripts are not Runic-clean and the broken fixture has a ParseError. ChuiTypes main fails today; nothing is pushed.
2. `tdd-commit` records land in different ledgers depending on dispatch. The fix is `owning_ledger` (shell and Julia, with a parity test), written through `ledger()` (agreed with e1 for 0.4.0's lock and pending file).
3. The TDD roles have no report channel. Fix: dispatch them unnamed, with the final reply as the report, for TDD roles only (agreed with e1).
4. A deletion-only test-fix deadlocks E1. Fix: recorded-removal evidence.
5. Skill and brief text.
6. CHECK_COVERAGE gets two blind spots.

**The ChuiFrames 0.3.0 sync is held:** re-sync it to 0.3.1 instead. |
| ~~smoke lane scan-widen~~ | ChuiTypes.jl | **MERGED 2026-10-27, ChuiTypes main 252b6f1.** It is the first test-first lane, and it fixes ADR-0009 follow-up 4 (`scan` widens like `Base.accumulate`).
- Red b7d6694 by a test-writer: 5 items, all BEHAVIOUR. Green fd22a4a by an implementer: 17210/17210 on 1.13. The lead ran LTS 17197/17197. tdd audit OK; reviewer APPROVE FINAL.
- A first test-writer attempt was reset: the lead's brief let already-passing items into the red commit.
- Follow-ups:
  - F1: add a `scan` perf budget row to `test/test_perf.jl`;
  - F2: ChuiCore's `Scan` keeps the narrow slot, so the ADR-0004 switch would lose the widening (a request to ChuiCore);
  - F3: a docstring note on two-step widening;
  - F6: ADR-0009 lines 93 and 115 are stale. | — | — |
| ~~factory 0.3.0~~ | coordinator | **DONE 2026-10-27: factory 0.3.0 is final and synced into the coordinator, main 979c495.**
- **Merges:**
  - tw-031 7195240: Tasks 8–9 and critic C1–C8, with reviewer FINAL ×2.
  - tw-032 1722a44: the tests became coordinator-safe; FULL guard 771/0/0.
  - sync-030 979c495: Task 10, reviewer APPROVE FINAL.
- **Lead re-runs:**
  - 3375/3377 (1.13, T3 set) and 3370/3372 (1.10, T3 unset) at d03d9f2;
  - coordinator 3042/3045 at 39cb7c4.
- **Registry:** test-writer and implementer are registered. The lead's hand edits (308b00b) were authored `lead <lead@factory.invalid>`, the only such commit on main. The coordinator has no `tdd` requirement, so it has no effect; it is kept as is, and future non-TDD lead commits use the real author.
- **Next:** the user restarts the session (new agent types load at start), then a live smoke lane (critic C5), then Task 11 (package syncs; ChuiCore after its tag), then Task 12 (backfill).
- **Factory follow-ups (next factory change):**
  - CHECK_COVERAGE: sync_factory writes T3 paths without T3, and teammates without T3 cannot discard an applied sync;
  - wfcheck coverage of Agent and Edit;
  - reviewer NIT-A/NIT-B (octopus merges, a branch cut from a sub-lane tip);
  - lts flake: test_ci.jl:166 and the hook timing checks under load above 25.
- **Process:** teammates do not inherit `FACTORY_ALLOW_T3`, so T3 hand edits are the lead's.

The original row follows. | — | — |
| (was) tw-031 | coordinator | `.worktrees/tw-031` / `feat/tw-031` | `factory/**`, the test-writer plan | started 2026-10-27 (sub-lead tw-build2): test-writer Tasks 8–9 plus required 0.3.0 items: (a) the renamed-red deadlock, (b) the dod heading check on modified fragments, (c) the factory tests unset `FACTORY_ALLOW_T3`/`PUSH` (today 101 hook tests fail when it is set). After it: Task 10 (the lead syncs 0.3.0 into the coordinator; a restart loads the new agents), Task 11, Task 12 |
| ~~sync-028 (coordinator)~~ | coordinator | **MERGED 2026-10-27 as 8d56a1b** (reviewer APPROVE WITH NITS FINAL; the lead re-ran 1339/1339 on both versions with T3 unset). Nits: ADR-0001 line 51 and the revisit trigger are stale since 0.2.8 (dated note owed, lead); the factory-028 fragment text gets fixed at fold time. **Test-writer Task 0: DONE**, probe PASS, recorded in the plan (2a338f3) | — | — |
| ~~sync-028 (packages)~~ | ChuiTypes.jl, ChuiFrames.jl | **MERGED 2026-10-27: ChuiTypes main 177674d, ChuiFrames main 3cba230** (both reviewers APPROVE FINAL).
- **ChuiTypes:** `-- all` passed 17283/17283 on 1.13 and 17268/17268 on 1.10, at a tree identical to the merge.
- **ChuiFrames:** 14788/14788 on 1.13 and 14740/14740 on 1.10 at 6fa31b0.
- **Guards:** the lead re-ran them in both repos with T3 unset: OK.
- The snapshot worktree is removed; recreate it at c667a95 for ChuiCore after its tag.
- Open: the coordinator `releases.md` has no factory 0.2.8 row.

The original row follows. | — | — |
| (was) sync-028 ×2 | ChuiTypes.jl, ChuiFrames.jl | `<repo>/.worktrees/sync-028` / `feat/sync-028` | factory-managed files (`.claude/**`, `.agents/**`, `scripts/**`, `.github/**`, `test/runtests.jl`, `.factory-version`, AGENTS/CLAUDE, CHECK_COVERAGE) | started 2026-10-27 after the T3 restart (`FACTORY_ALLOW_T3=1` confirmed by `printenv`). Agents sync-coord, sync-types and sync-frames sync **from the 0.2.8 snapshot**, the detached worktree `.worktrees/factory-028-src` at c667a95, because main's factory/template already holds unreleased 0.3.0 work. ChuiCore is skipped until its v0.0.1 tag. Test-writer Task 0 waits for the coordinator sync to merge, since both touch `.agents/agent-registry.toml` and `.claude/settings.json` |
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
- Full phase-4 gates were green at frames d410a46, with `dod.jl --base main` DONE and no waiver:
  - tests: 14788 / t4 14789 / lts 14740 / diff 1970 / slow-t4 35;
  - quality, JET, guards, docs: all OK;
  - bench-check: 138/138 on both versions.
- **User, 2026-10-26: defer the quiet timing run.** Load is about 8, all of it from outside Chui (Chrome, mediaanalysisd). The phase-4 time rows are INCONCLUSIVE. The quiet run (ttfx and run.jl `--check` on 1.13 and LTS, plus `ci.jl bench` against main) becomes a gate before ChuiFrames' first release. Next: the final reviewer FINAL, then the ★ (ADRs 0023–0025 and the ADR-0022 rule 1 note), then the lead's main merge.
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

**As of 2026-10-27 17:20 (supersedes everything below where they differ).**

**Factory.** 0.3.2 is final.
- Merges into coordinator main:
  - tw-034 → 0.3.1 (b4aeda3);
  - tw-035 → 0.3.2 (6d66187). This fixes `ci.jl format` in the coordinator profile: fixtures are excluded at any depth, the Runic item is scoped to managed scripts, and the guard vendors factory/.
- The lead re-ran the 0.3.2 suite with T3 set: 3608 pass, 2 broken.
- Process note for tw-034 and tw-035: the TDD steps were general-purpose agents carrying the test-writer and implementer rules, not the registry roles. Briefs were not saved. Package lanes use the registry roles.

**Per repo.**

| Repo | Factory | Main | Notes |
|---|---|---|---|
| Coordinator | 0.3.2 | 5d8227b (sync-031) | Its own `ci.jl format` flags `contracts/` (T3) and `reference/prototype/`: a known limit, and there is no coordinator format CI job. |
| ChuiTypes | 0.3.1 | cc10db3 | format OK |
| ChuiFrames | 0.3.1 | 3ad98af | format OK |
| ChuiCore | 0.2.6 | a4f86e7 | ci-cov fixed the coverage-only test failure |

ChuiCore's ci-cov fix: `classes_unit_tests.jl` drops the `:code_coverage_effect` counters before the fold check. The lead re-ran the suite with coverage on: 3177/0.

**ChuiCore 0.0.1 release.** The first run of `private/release-chuicore-001.sh` pushed all four mains: coordinator 14cf35c, Core aaca78f, Types cc10db3, Frames 3ad98af. It then stopped, because CI was red on the Julia 1 / ubuntu coverage job. There is no tag and no registry entry yet.
- The script now points at a4f86e7.
- The redaction scan found 0 hits on all pushed history, the trees and the unpushed commits. The positive control gave 12.
- ★ **User:** re-run the script and say "released".

**e1 (factory 0.4.0, lane f040). LANDED 2026-10-27 as coordinator main 3e90f8e.**
- The lead re-ran the suite at aa37741 with T3 set: 4906 pass, 2 broken. The coordinator guard gave 763/0.
- Four reviews, all MAY MERGE: integrate, release (fixes done), release2 and critic4. The lead reviewed 0eb7d16 (test-only).
- ChuiTypes is on 0.3.2 at 71a7fdd.
- **Next:** e1 runs the 0.4.0 coordinator sync in its own lane, and tells the lead before it touches `<root>/.claude/` and `.agents/`. **After it lands, the user restarts every session**: hooks, agents and limits.env only load at start.

**0.4.0 migration notes for the packages** (from e1; also in factory/CHANGELOG.md "## 0.4.0"):
1. Restart every session after the sync.
2. Fail-closed:
   - Any guard that crashes, exits non-zero or times out inside its 8 s watchdog now BLOCKS with exit 2.
   - A missing jq, awk, sourced hook library or parseable payload means every Bash, Write and Agent call is denied.
   - A limits.env without READ_ONLY_AGENTS denies every dispatch. Run `julia scripts/gen.jl` after the sync.
3. Read-only agents (reviewer, critic, verifier) are enforced by agent_type:
   - They may write only `.lanes/reports/**` and `.lanes/scratch/<type>/**`.
   - They may run only an allowlist.
   - Briefs must not ask them to edit, commit or run `tdd.jl mutate`.
4. Report headers:
   - Read-only agents: line 1 is `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST`, line 2 is `Head: <sha>`.
   - Write agents: line 1 is `Status: DONE | PARTIAL | BLOCKED`.
   - **Name every reviewer dispatch.** `lane audit --report` accepts only `<name>.md` or `<name>--r<N>.md`.
   - TDD roles stay unnamed.
5. Seeded hand edits:
   - **CLAUDE.md:** the cap line `<!-- claim: max_open=N -->`, plus the "Precedence" and "Writing files under the guard" sections.
   - **agent-registry.toml (T3):** add the `verifier` agent. Give reviewer and critic `Write` plus `.lanes/reports/**` and `.lanes/scratch/<slug>/**`. Every output_format ends `; at most 80 lines`. Keep the implementer and test_writer stanzas.
   - **risk.toml (T3):** add `scripts/_lane_stats.jl`.
6. Heredocs end only at an exact terminator line (`EOF)` is refused). A `.git` path component is matched case-insensitively.
7. Ledger appends go through `.lanes/ledger.pending.jsonl`. Use `scripts/lane compact` if a ledger is huge.
8. New commands: /lane-review and /ci-triage, plus an advisory runic check after edits.

**Next steps for the lead.**
1. After the release: the releases.md rows, including factory 0.2.8/0.3.x; integration; compat-matrix; the ChuiTypes Upstream switch; sync ChuiCore to 0.3.2.
2. Sync ChuiTypes and ChuiFrames to 0.3.2.
3. Task 12 backfill: ChuiTypes, then ChuiFrames, then ChuiCore.
4. Smoke-lane follow-ups F1–F3 and F6.

**As of 2026-10-27 (earlier):** no lanes are open, and both ChuiFrames phase 4 and test-writer part 1 are merged.
1. ★ **User:** restart the lead with `FACTORY_ALLOW_T3=1`, after merging this branch (feat/lead-1026) into coordinator main. Then:
   - sync factory 0.2.8 into the coordinator, ChuiTypes and ChuiFrames;
   - test-writer Task 0 (the agent_type probe), then Tasks 8–10 (Task 9 fixes the renamed-red deadlock);
   - Task 11, the package syncs;
   - Task 12, backfill lanes: ChuiTypes first, ChuiFrames next, ChuiCore after its tag.
2. **User:** run `bash private/release-chuicore-001.sh` and say "released". Remove `.worktrees/tw-030-verify` (`git worktree remove --force`).
3. ~~Lead: the changelog `###` fragment fix~~ DONE 2026-10-27:
   - **ChuiFrames:** main 86bd9c3 (T0; the lead reviewed it: ignoring whitespace, only heading lines changed; fold accepts all 21 fragments).
   - **Coordinator:** main 8de730c (fragments rewritten, and factory template `dod.jl` now rejects added headed fragments; reviewer APPROVE FINAL; the lead re-ran 2289/2291).
   - **Spec:** `docs/superpowers/specs/2026-10-27-cl-headings-design.md`.
   - **0.3.0 item (reviewer minor):** dod should also check modified fragments, not only added ones.
   - **The coordinator's own `scripts/dod.jl`** gets the rule when it syncs to 0.3.0.

1. **User:** run the ChuiCore 0.0.1 release script (it also pushes every repo's main). Then the lead adds releases.md, runs integration, fills compat-matrix, and syncs 0.2.7 into ChuiCore.
2. Lead: merge sync-027-types and sync-027-frames2 after their final reviews; land requests-p4p3 through a coordinator-rooted agent. The user copies the contract drafts (`scratchpad/contracts-p3p4/`) into `contracts/` (T3).
3. ChuiFrames -t 4 CI job: needs the user's `FACTORY_ALLOW_T3=1`.
4. Next phases: ChuiTypes phase 5 (switch to ChuiCore 0.0.1, then cost); ChuiFrames phase 4 (grouped sinks, joins); ChuiCore post-0.0.1.
5. Unanswered offer: delete the unredacted `chui-rewrite` clone in the scratchpad. The coordinator still has no format job (low).
