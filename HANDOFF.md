# HANDOFF — Chui coordinator (lead)

Updated: 2026-10-19 · Phase: **L0 setup, steps 0–4 written; waiting on contracts-critic and factory-maint, then step 5**

## State

- Branch: `worktree-lead-l0` (worktree `.claude/worktrees/lead-l0`), nothing committed since `8cbb474`. `main` = `8cbb474`.
- **Renamed 2026-10-19 (user decision): Junta → Chui.** ChuiCore, ChuiTypes, ChuiFrames; later ChuiStats, ChuiLearn, ChuiSpatial, ChuiPlot. Why: General's AutoMerge rejects names starting with "Ju" and requires at least 5 characters and DL distance > 2 (checked against all 14,576 General names).
- Julia: `release` 1.13.2 (default), `lts` 1.10.12, 1.11.7 (all juliaup; updated by the user).
- The lead runs interactively in tmux session `junta`; teammates open as panes.
- L0 steps:
  - 0: coordinator repo, plus the factory vendored at 0.1.0 (coordinator profile).
  - 1: environment check.
  - 2: reference research, factory 0.1.0, ADR-0001.
  - 3: ADRs 0002–0011, rename applied, critic findings fixed.
  - 4: v0 contracts, under critic review.
  - 5–6: not started.
- **Hooks are live for teammates.** Teammates spawned with cwd = the worktree run the coordinator's hooks from `.claude/settings.json`. `prompts/*` and `contracts/*` are T3, so write_guard blocks them unless the user sets `FACTORY_ALLOW_T3=1`. The lane cap is 4. The lead's own session (rooted at the main checkout) has no hooks until this lands on main.
- **User-authorized bypass:** the coordinator bootstrap (coord-setup) wrote its T3 files around write_guard, approved by the user on 2026-10-19. Files: CLAUDE.md, risk.toml, CHANGELOG.md, .gitignore, the registry and bodies, and the skeletons.

## Open lanes

| Lane | Agent | File scope | Status | Report |
|---|---|---|---|---|
| factory-patch | general-purpose | `factory/` → 0.2.1; coord bodies; the adr/README.md reference | running | — |

Closed this phase:
- **ref-research:** done. Incident: a sub-lane ran `uv run` in reference-project-b, which re-synced its gitignored `.venv`; the git tree stayed clean.
- **eco-architect:** done.
- **adr-critic:** done; 2 blockers and 14 should-fix items.
- **eco-reviser:** done; all findings resolved.
- **factory-builder:** done; 483/483 tests. Its own reviewer subagent found 14 issues, all fixed.
- **contracts-writer:** done; 22 stable entries. Its first idle without a report was blocked by the hook.
- **coord-setup:** done.
- **factory-maint:** done. Factory 0.2.0: 665/665 template tests (lead re-ran them on 1.13.2); bash_guard read-only roots; hooks fail closed; check_docs config; ADR dir per profile; contract_usage.jl. Its reviewer covered the guard and sync work but not contract_usage, which is in factory-patch's review scope.
- **Lead applied the 0.2.0 sync** to the coordinator (user-authorized T3): add=2 update=20 seed=1, no conflicts. Then the lead added `.agents/factory.toml` to the T3 globs, moved the stale docs/adr copies to the scratchpad, and regenerated (`gen --check` OK, 26 files). The incident command `cd ~/reference-project-b && uv run pytest` is now blocked by bash_guard (rc=2, lead-verified). Coordinator tests: 540 pass, 2 fail, 2 error (profile-coupled factory tests), handed to factory-patch.
- **contracts-fixer:** done. Every critic finding resolved. Stable entries: CC-001/002/004–007/010/011, CT-003, CF-001–009. Retired: CC-003/008/009, CT-001/002. The lead re-ran `check.jl` (0 errors, 17 value expectations) and `test_check.jl` (7/7) on 1.13.2 and 1.10.12. Guard bypassed (user-authorized): the files in contracts/.
- **contracts-critic:** done. CHANGES REQUESTED: 4 blockers (all entries rest on Proposed ADRs; empty-input exceptions differ between 1.10 and 1.13; float laws need tolerances; CC-003 is not a decision), 17 should-fix items, 7 nits. The lead re-verified B2 and S12 on both versions.

Closure proof: `scripts/lane list` is not used yet, because no package repo exists. `git worktree list` shows main plus `lead-l0`.

## Evidence

All entries below are actual runs (`subagent_mode: actual`).

- `julia scripts/gen.jl --check` (worktree root) → `OK (25 files)`. Lead re-run.
- `julia factory/template/scripts/test/runtests.jl` → `factory | 483 483`. Lead re-run on 1.13.2.
- `julia contracts/check.jl contracts` → `24 julia blocks parsed, 3 Base-only blocks executed, 0 error(s)`. Lead re-run.
- write_guard probe on `contracts/chui-core.md` → rc=2, a T3 block (lead re-run).
- Name check: the `names.jl` OSA distance script against General's Registry.toml; see `research/ecosystem-verification.md` E-21.

## Checks NOT run, and why

- The coordinator's `scripts/test/runtests.jl` has 2 failures, both factory bugs fixed in 0.2.0 (in progress): test_ci is not aware of profiles, and the repo-wide check_docs fails.
- Repo-wide `check_docs.jl` reports 163 stale refs, which needs the check_docs config from 0.2.0.
- The package CI jobs (format/docs/jet/contracts/bench/coverage) have never run end to end, because no package exists yet. Step 5 is their first run.
- Hooks in a live session: only teammate_idle and write_guard have been seen firing. Whether teammates emit SubagentStart (which decides if they count toward the lane cap) is UNVERIFIED.

## Blockers and decisions waiting (★ L0 checkpoint)

1. **Accept the ADRs.** All are Proposed, and the contracts rest on them.
2. GitHub owner and visibility; create and push ChuiRegistry plus the three package repos (ADR-0005 gate). Until then, everything stays local-only.
3. Version-0 snapshots as 0.0.x instead of brief 20's `v0.1.0-DEV` (ADR-0004).
4. Julia floor: 1.10 (proposed) or 1.12 (ADR-0006).
5. Formatter: Runic (recommended; changes common.md §1.7) or JuliaFormatter (ADR-0007).
6. How `c` is exported: plain export (recommended), opt-in import, or a submodule (ADR-0009).
7. `partial` naming: `papply` for partial application (recommended), or rename the protocol to `absorb`/`step!`. Also confirm: fixed exception types for empty input (not mirroring Base per version); `neutral` as the monoid element; DRAFT-period withdrawals as retired stubs.
8. License MIT; benchmark tool AirspeedVelocity; local coverage-floor file (ADR-0011).
9. Benchmark CI: block at 10%, or warning-only at first (recommended).
10. CompatHelper and TagBot registry settings, which follow from item 2.
11. The permission mode for the rest of the run. (T3 edits: on 2026-10-19 the user gave one-time approval for exactly two, the contract fixes after contracts-critic and the factory 0.2.0 sync into the coordinator. Other T3 edits still need approval.)

## Next action

1. Read the contracts-critic and factory-maint final reports. Fix the contracts, which needs T3 approval.
2. Apply the factory 0.2.0 sync to the coordinator, which also needs T3 approval.
3. Step 5: three scaffold lanes in parallel, one per package repo (`git init`, vendor the factory, ECOSYSTEM.md/BRIEF.md/HANDOFF.md, an empty package, CI; `]test` green; one initial commit each).
4. Commit the coordinator work on `worktree-lead-l0`, merge it to main, then stop at ★.
