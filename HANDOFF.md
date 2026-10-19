# HANDOFF — Chui coordinator (lead)

Updated: 2026-10-19 · Phase: **★ L0 answered (2026-10-19): "accept all recommendations; GitHub owner bonmac, public, push yes".** Applying the decisions; factory 0.2.3 is in progress.

## State

- **Coordinator:**
  - branch `worktree-lead-l0` (worktree `.claude/worktrees/lead-l0`), fast-forwarded to `main` after coord-review's fixes; see `git log`;
  - spec: `docs/superpowers/specs/2026-10-19-coordinator-bootstrap.md`;
  - factory 0.2.1 vendored, profile coordinator.
- **Renamed 2026-10-19 (user decision): Junta → Chui.** ChuiCore, ChuiTypes, ChuiFrames; later ChuiStats, ChuiLearn, ChuiSpatial, ChuiPlot. Why: General's AutoMerge rejects names starting with "Ju", needs ≥ 5 characters and DL distance > 2. Every name was checked against all 14,576 General names (E-21).
- **Package repos** (step 5), each `git init -b main` with no remote, factory 0.2.1 (package profile), and `]test` green on 1.13.2 and 1.10.12 and from a fresh clone:

  | Repo | Commits | Notes |
  |---|---|---|
  | `ChuiCore.jl` | `80a7e8a` scaffold · `21a3fba` check_docs exclude · `70a17ec` HANDOFF path fix | 4 test items |
  | `ChuiTypes.jl` | `b3149cc` scaffold (includes the check_docs exclude) | 3 test items; JET and docs jobs ran OK |
  | `ChuiFrames.jl` | `4b8cfa9` scaffold · `012bb68` check_docs exclude · `45564e4` HANDOFF path fix | 3 test items; JET and docs jobs ran OK |

- **Julia:** `release` 1.13.2 (default), `lts` 1.10.12 and 1.11.7, all via juliaup.
- **Session:** the lead runs interactively in tmux session `junta`; teammates open as panes.
- **Where to run the L1 lead (coord-review S5):** from the main checkout `<root>`, not from this worktree. From the worktree, write_guard blocks writes into `<root>/Chui*.jl/`, which are outside the worktree root. From `<root>`, nested repos are checked against their own protected paths. Spawn package lanes with cwd = the package repo.
- **Hooks:** live for teammates rooted in any vendored checkout. In the coordinator, `prompts/*` and `contracts/*` are T3, so write_guard blocks them unless the user sets `FACTORY_ALLOW_T3=1`. The lane cap is 6 (decision 12) <!-- claim: max_open=6 -->.
- **User-authorized T3 bypasses on 2026-10-19 (complete list):**
  1. **coord-setup:** the coordinator bootstrap. Files written around the guard: `.agents/agent-registry.toml` and the `coord_*` bodies, `risk.toml`, and the skeletons. Other files it touched, such as `CLAUDE.md`, are not T3.
  2. **The 0.2.0 sync** into the coordinator, plus the lead's follow-up edit adding `.agents/factory.toml` to the T3 globs. The 0.2.1 sync, which writes only `.factory-version`, is counted under this one.
  3. **contracts-fixer:** the `contracts/` fixes after contracts-critic.
  4. **One `[check_docs] exclude`** in each package's `.agents/factory.toml` at scaffold time.

## Open lanes

| Lane | Agent | File scope | Status | Report |
|---|---|---|---|---|
| factory-024 | general-purpose | `factory/` → 0.2.4 (8 hardening items from the reference-project study, plus hermetic tests and exec bits) | running | — |

Closed this phase:
- **ref-research:** done. Incident: one of its sub-lanes ran `uv run` in a reference repo, which re-synced the gitignored `.venv`; the git tree there stayed clean.
- **eco-architect:** done.
- **adr-critic:** done; 2 blockers and 14 should-fix items.
- **eco-reviser:** done; all findings resolved.
- **factory-builder:** done; its own reviewer found 14 issues, all fixed.
- **contracts-writer:** done.
- **contracts-critic:** done; 4 blockers and 17 should-fix items.
- **contracts-fixer:** done; all resolved.
- **coord-setup:** done.
- **factory-maint:** done (0.2.0).
- **factory-patch:** done (0.2.1); its reviewer covered contract_usage.
- **scaffold-core, scaffold-types, scaffold-frames:** done.
- **checkpoint-apply:** done (`c32cbbc`).
- **factory-023:** done. Factory 0.2.3 committed `15280a8` (1006/1006 tests; M1–M3 re-verified by the lead).
- **coord-redact:** done. 0.2.3 synced into the coordinator and the reference projects redacted, committed `ac62485`. Coordinator runtests: 861/863 (2 tests not hermetic under `require_read_only_roots`; fixed in 0.2.4). History-rewrite inputs are in `private/`.
- **cc-lessons:** done. Studied a 4th private reference project for lessons; the study is in `private/`, and 8 recommendations were accepted by the user and go into 0.2.4.
- **coord-review:** done; changes requested, fixed in `604115e` (dod.jl: DONE).
- **factory-022:** done. Factory 0.2.2 committed `1aa6117` (807/807 tests; ratchet OK, verified by the lead). Not synced into any repo yet. Its reviewer requested changes, all fixed.
- **guard-rereview:** done. Changes requested: M1 is a regression from 0.2.2 (`unset TMPDIR; rm -rf $TMPDIR/opt` passes); M2: shell keywords and wrappers hide `rm`; M3: a false heredoc start hides every later line. The lead reproduced M1 and M2 (rc=0). **Do not sync 0.2.2**; factory-023 is fixing them in 0.2.3.

None went idle without reporting. Several lanes' first idle was blocked by the teammate_idle hook while they waited on their own sub-agents; that's expected.

Closure proof: `git worktree list` shows main plus `lead-l0`. No package lanes are open, so `scripts/lane list` is empty in each package repo.

## Evidence

All entries below are actual runs (`subagent_mode: actual`). The lead re-ran the key checks itself.

- **Coordinator:**
  - `julia scripts/gen.jl --check` → OK (26 files)
  - `julia scripts/test/runtests.jl` → 581/581
  - `julia scripts/check_docs.jl` → OK
- **Factory template:** 683/683 tests on 1.13.2 (and on 1.10.12, per the lane).
- **Contracts:** `julia contracts/check.jl contracts` → 0 errors, 17 value expectations (1.13.2 and 1.10.12); `contracts/test_check.jl` → 7/7.
- **Packages:**
  - `Pkg.test()` on `julia +lts` → ChuiCore 4/4, ChuiTypes 3/3, ChuiFrames 3/3 (lead re-run);
  - `check_docs.jl` → OK in all three (lead re-run).
- **bash_guard:** blocks `cd <a reference repo> && uv run pytest` (rc=2); write_guard blocks `contracts/chui-core.md` (rc=2).

## Checks NOT run, and why

- **`ratchet.jl` / `ci.jl guards`:** red in every repo, because `bash_guard.sh` has 210 lines against the seeded 150-line cap. This is a factory bug, fixed in 0.2.2 (in progress); its sync into the repos is a T3 change waiting on the user.
- **GitHub Actions:** no remotes exist, so nothing has run; the workflows were only linted with actionlint.
- **`ci.jl contracts`:** skipped, because no upstream is released.
- **`ci.jl format` (Runic):** the formatter is a ★ decision.
- **Benchmarks:** none exist yet.
- **Package scaffolds not reviewed:** no separate reviewer pass. Each lane verified its own repo, and the lead re-ran tests and check_docs. They are initial scaffolds on main with no remote.
- **Lane cap:** whether teammates emit SubagentStart, and so count toward the cap, is UNVERIFIED.

## L0 checkpoint decisions (answered 2026-10-19: all recommendations accepted)

Owner `bonmac`, public visibility; push the three package repos and ChuiRegistry once their mains are green after the 0.2.3 sync. The coordinator is pushed too, as public `bonmac/Chui` (user, 2026-10-19), **but only after redaction**: no names, paths or details of the private reference projects anywhere in the tree or the git history of any Chui repo. The full research moves to a gitignored `private/` folder, and the real read-only roots go in a gitignored .agents/factory.local.toml. factory-023 makes the factory itself name-free. Item 13 (permission mode) had no recommendation, so it stays unchanged.

The list as it was asked:

1. **Accept the ADRs** (0001–0011, all Proposed). The DRAFT contracts become binding once 0002/0004/0007/0009/0010 are Accepted.
2. **GitHub:** owner and visibility, and whether to create and push ChuiRegistry plus the three package repos (the ADR-0005 gate). Until then, everything stays local.
3. **Versions:** 0.0.x snapshots instead of brief 20's `v0.1.0-DEV` (ADR-0004).
4. **Julia floor:** 1.10 (proposed) or 1.12 (ADR-0006).
5. **Formatter:** Runic (recommended; changes common.md §1.7) or JuliaFormatter (ADR-0007).
6. **`c` export:** plain export (recommended), opt-in import, or a submodule (ADR-0009).
7. **`partial` naming:** `papply` for partial application (recommended), or rename the protocol. Also confirm: fixed exception types for empty input; `neutral` as the monoid element; retired-stub withdrawals.
8. **License, benchmarks, coverage:** MIT, AirspeedVelocity, and a local coverage-floor file (ADR-0011).
9. **Benchmark CI:** block at 10%, or warning-only at first (recommended).
10. **Registry settings:** CompatHelper and TagBot settings follow from item 2.
11. **Factory sync (T3), now 0.2.3 instead of 0.2.2** (0.2.2 has a guard regression; factory-023 is fixing it):
    - Coordinator: the sync writes 7 hook/version files; then replace risk.toml with `factory/profiles/coordinator/risk.toml` and run gen.
    - Each package: the sync writes the hooks, CI.yml and `.factory-version`; then copy the template risk.toml, add one `.gitignore` line, add JET compat, add a runtests filter line, and run gen.
    - This turns the ratchet green, so `main` can be fast-forwarded. Version note: the factory's own rule suggests 0.3.0 for stricter guards; the lead kept 0.2.2.
12. **Lane cap for L1:** keep 4, or raise it (`max_open`, a T3 change). L1 runs implementer, test and review lanes in three repos at once.
13. **Permission mode** for the rest of the run.

## Push sequence (after factory-023 and checkpoint-apply)

1. **Redaction lane (coordinator):**
   - generic labels in `prompts/common.md` §3/§5, `00-lead.md`, CLAUDE.md, the bodies, ADR-0001 and `research/environment.md`;
   - `research/reference-projects.md` moves to `private/`;
   - the real roots move into .agents/factory.local.toml;
   - history rewritten with `git filter-repo` (via `uvx`), done in a fresh clone; the lead reviews it before pushing.
2. **Sync 0.2.3** into the coordinator and the three packages, refresh the packages' `docs/agent` copies from the redacted sources, and rewrite the package histories, which still hold the old `ECOSYSTEM.md`.
3. **Gate:** `git log -p --all | grep -i -E -f private/redaction-patterns.txt` (gitignored) must be empty in every repo. Then create `bonmac/Chui`, `ChuiCore.jl`, `ChuiTypes.jl`, `ChuiFrames.jl` and `ChuiRegistry` (all public) and push.

## Next action

1. When factory-022 reports: review it, then put its sync to the user as item 11.
2. At ★: wait for the user's answers. Then flip the ADR statuses and the contracts' DRAFT banners, and apply the approved syncs.
3. L1: relaunch the lead from `<root>` (main checkout) and start each package's phase 1 (Research and ADRs) as parallel lanes.
