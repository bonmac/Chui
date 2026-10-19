# HANDOFF — Chui coordinator (lead)

Updated: 2026-10-20 · Phase: **L0 done (★ answered 2026-10-19: all recommendations accepted).** Redaction, factory 0.2.4 and package follow-ups are done; next is the approved push, then L1.

## State

- **Coordinator:** `main` (the main checkout `<root>`); the lead's worktree `.claude/worktrees/lead-l0` (branch `worktree-lead-l0`) trails it and can be removed at L1. Factory 0.2.4, profile coordinator. Spec: `docs/superpowers/specs/2026-10-19-coordinator-bootstrap.md`.
- **History rewritten (2026-10-19)** with `git filter-repo` so no tracked file or commit names the private reference projects. Content was unchanged by the rewrite (same tree). Commit hashes from before the rewrite no longer exist publicly; provenance comments now cite `ff0100a`. The unredacted history is only on the local branch `pre-redaction-backup`: **never push it**; delete it once the user confirms the push.
- **Machine-local, gitignored:** `.agents/factory.local.toml` (the real read-only roots, rendered by `scripts/gen.jl` into `.claude/hooks/read-only-roots.txt`) and `private/` (the full reference study, rewrite inputs, `redaction-patterns.txt`). `require_read_only_roots = true`, so bash_guard fails closed in a checkout without them.
- **Renamed 2026-10-19 (user decision): Junta → Chui.** ChuiCore, ChuiTypes, ChuiFrames; later ChuiStats, ChuiLearn, ChuiSpatial, ChuiPlot. Every name was checked against General's names (E-21).
- **Package repos:** each on `main`, factory 0.2.4 (package profile), history rewritten, no remote yet:

  | Repo | HEAD | Tests |
  |---|---|---|
  | `ChuiCore.jl` | `88291e5` | 4/4 (1.13.2) |
  | `ChuiTypes.jl` | `7d10c7a` | 3/3 (1.13.2, 1.10.12); JET OK |
  | `ChuiFrames.jl` | `f118874` | 3/3 (1.13.2, 1.10.12); JET OK |

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

None. Closed this session (all reported; none went idle without a report):
- **pkg-core-024, pkg-types-024, pkg-frames-024:** 0.2.4 sync and history rewrite per package.
- **fix-core** (`acaec8c`), **fix-types** (`7d10c7a`), **fix-frames** (`f118874`): seeded-file gaps (runtests `:contract` filter, JET compat, `.gitignore`, untracked roots file in ChuiFrames), provenance re-pinned to `ff0100a`, HANDOFFs refreshed. The lead re-ran the diffs and the redaction gate.
- Lead: re-synced 0.2.4 into ChuiCore (`88291e5`) and the coordinator so `source_commit` no longer names a pre-rewrite commit.
- Earlier L0 lanes (ref-research, eco-architect, adr-critic, eco-reviser, factory-builder, contracts-writer/critic/fixer, coord-setup, factory-maint, factory-patch, factory-022/023/024, guard-rereview, coord-redact, cc-lessons, coord-review, scaffold-*, checkpoint-apply): done; see git history.

## Evidence

All actual runs (`subagent_mode: actual`).

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

## L0 checkpoint decisions (answered 2026-10-19: all recommendations accepted)

ADRs 0001–0011 Accepted; contracts binding; 0.0.x snapshots; Julia floor 1.10; Runic; `c` plain export; `papply`, fixed empty-input exceptions, `neutral`, retired stubs; MIT, AirspeedVelocity (warning-only at first), local coverage floor; CompatHelper/TagBot via ChuiRegistry; factory sync once reviewed; lane cap 6. Item 13 (permission mode) had no recommendation and stays unchanged. GitHub owner `bonmac`, all public: `Chui` (this coordinator, redacted first), `ChuiCore.jl`, `ChuiTypes.jl`, `ChuiFrames.jl`, `ChuiRegistry`.

Open factory notes for the user: the CHANGELOG rule suggests 0.3.0 for stricter guards (kept 0.2.x); `git reset --merge`/`--keep`, `checkout -- .` and `restore .` are not blocked by bash_guard (user's call).

## Next action

1. Create the five public repos under `bonmac` and push each `main` (coordinator: `main` only, never `pre-redaction-backup`). Create ChuiRegistry empty (LocalRegistry); packages are registered at their first release, not now.
2. After the user confirms the push: delete `pre-redaction-backup`.
3. L1: relaunch the lead from `<root>` and start each package's phase 1 (Research and ADRs) as parallel lanes.
