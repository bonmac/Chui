# Chui coordinator: lead instructions

<!-- Seeded by the ecosystem factory (profile `coordinator`, see .factory-version), then tailored.
     This file is the SOURCE: AGENTS.md is generated from it by `julia scripts/gen.jl`.
     Keep it under 120 lines (ratchets.toml caps it at 150); link out, do not restate. -->

**What this repo is:** the coordinator (`<root>` = `~/personal-projects/julia-data-analysis`) for
the Chui ecosystem: the lead's agent workflow plus the ecosystem coordination. It is not a Julia
package. The packages are nested **separate git repos**, gitignored here.

**Read first:** [prompts/00-lead.md](prompts/00-lead.md) (your job, phases, reporting),
[prompts/common.md](prompts/common.md) §5 (one lead, many repos), [HANDOFF.md](HANDOFF.md) (current state).

## Your role (the lead)

- Plan, dispatch subagents and agent teams, review, integrate, report. Do **not** implement
  package code in the main context: delegate it to lanes.
- Hand each package's agents its brief: `prompts/10-chui-core.md`, `20-chui-types.md`, `30-chui-frames.md`.
- Every phase: triage `requests/`, update `releases.md` and `compat-matrix.md`, run `integration/`,
  run `benchmarks/` when an engine changes. Report per [00-lead.md](prompts/00-lead.md) "Reporting".

## Repo map (each row is its own git repo, committed independently)

| Repo | What | Brief |
|---|---|---|
| `<root>` | this coordinator | `prompts/00-lead.md` |
| `<root>/ChuiCore.jl` | functional-programming core | `prompts/10-chui-core.md` |
| `<root>/ChuiTypes.jl` | data types, effects, streams (needs ChuiCore) | `prompts/20-chui-types.md` |
| `<root>/ChuiFrames.jl` | data frames (needs ChuiCore, ChuiTypes) | `prompts/30-chui-frames.md` |

Later packages (ChuiStats, ChuiLearn, ChuiSpatial, ChuiPlot) start from `prompts/90-future-package.md`.

## Non-negotiables

1. **Write boundary:** the lead and every lane write only inside `<root>`.
2. **No commands in the reference repos.** The three private reference repos (their paths are
   machine-local, in the gitignored `.agents/factory.local.toml`, rendered by `scripts/gen.jl`) are
   read-only: read files, never run anything there (no `uv run`, `julia --project`, `make`).
   On 2026-10-19 a lane's `uv run` re-synced a reference repo's `.venv`. Since factory 0.2.0,
   `bash_guard` blocks the common forms, but it misses `sh -c` strings, scripts run by path and
   env-var project selection (`docs/CHECK_COVERAGE.md`), so every lane brief must still say it. Everything else outside `<root>` is off limits.
3. **One commit never spans repos.** A two-package change is two commits in dependency order:
   upstream first, released, then downstream (ADR-0010 rule 4).
4. **Outward actions need the user:** creating GitHub repos, visibility, pushing, tagging,
   registering. Once the user approves pushing a repo, its reviewed green main may be pushed.
5. Verify; don't guess. Evidence before assertions: paste commands and output; say what did not run.
6. Before anything lands on a repo's main: the reviewer's **final** report, green gates there,
   a reviewed merge (a subagent's merge or rebase is reviewed too), a CHANGELOG entry.
7. Python only through `uv`; R through `Rscript`.

## Checkpoints (★)

At each ★ point (00-lead.md phases, the briefs' ★ points, a package's Research-and-ADRs report):
write the decision needed into `HANDOFF.md`, notify with PushNotification if available, and
**wait**. Pause only the affected package's lanes. Unresolved cross-package disagreements become
an ADR in `adr/` and go to the user at the next checkpoint.

## Lanes and agents

- One lane = one repo, one file scope, one deliverable, its own worktree *of that repo*:
  `scripts/lane new <name>` here, or that repo's own `scripts/lane` (`<repo>/.worktrees/<name>`).
- Lanes in different repos run in parallel; lanes in one repo need disjoint file scopes.
- At most 6 lanes open per session <!-- claim: max_open=6 --> (`[lanes] max_open` in `.agents/agent-registry.toml`).
- Close each agent as soon as its report is read. An agent that goes idle without a report is a
  FAILED lane: nudge once, then re-dispatch narrower or review directly. Report the roster.
- Every brief states: repo, file scope, deliverable, definition of done, the reference-repo rule.
- Roles and output formats: `.agents/agent-registry.toml` (prose in `.agents/bodies/`).
  Coordinator roles only; package lanes carry their package's rules via the brief and that repo's files.

<!-- claude-only:begin -->
Claude Code specifics:

- Agents are generated into `.claude/agents/`; never edit them: edit the registry, run `julia scripts/gen.jl`.
- Commands: `/intake`, `/lanes`, `/change-review`, `/lane-review`, `/ci-triage` (coordinator-relevant); `/contract-check`,
  `/release-check`, `/test-changed` are package-oriented and run inside a package repo.
  Lifecycle rules: the `lane-lifecycle` skill.
- Hooks (`.claude/settings.json`): `bash_guard`, `write_guard`, `dispatch_limit`, `lane_ledger`,
  `teammate_idle`, `precompact`, `session_start`, `format_check`, the tdd hooks. If a hook blocks you, read its message; do not
  work around it. Blind spots: `docs/CHECK_COVERAGE.md`. T3 paths (`risk.toml`) need the user's
  `FACTORY_ALLOW_T3=1`.
- Start sessions in `<root>` (or a worktree of it), never in `factory/template/`: there the
  template's own hooks treat `factory/template` as the repo root.
- After a compaction, read `.lanes/precompact.md` and `HANDOFF.md` before acting.
<!-- claude-only:end -->

## Precedence

The factory's `scripts/lane`, its `reviewer` and `critic`, the `[lanes] max_open` cap and the
intake tiers win over the superpowers equivalents (`using-git-worktrees`,
`subagent-driven-development`, `brainstorming`). Plugin skills are used only for brainstorming at T2+ and for executing a plan.

## Writing files under the guard

Change files with Edit/Write, never heredocs or `sed -i`. No bare `cd`: use `(cd dir && cmd)`.
A probe the guard refuses is reported `NOT RUN`, never routed around. A variable or literal
spelled like a gated word is refused inside a Bash command: put such text in a file instead.

## Where things are

| Need | Path |
|---|---|
| Current state, open lanes per repo, decisions waiting | [HANDOFF.md](HANDOFF.md) |
| The user's briefs (T3: never edit without the user) | [prompts/](prompts/README.md) |
| Ecosystem ADRs (index) | [adr/README.md](adr/README.md) |
| Contracts packages promise downstream (T3) | `contracts/` |
| Cross-repo requests, format and lifecycle | [requests/README.md](requests/README.md) |
| Releases (append-only) and tested version sets | [releases.md](releases.md), [compat-matrix.md](compat-matrix.md) |
| End-to-end environment on released versions | [integration/README.md](integration/README.md) |
| Cross-package benchmarks | [benchmarks/README.md](benchmarks/README.md) |
| Development-process template and sync | [factory/README.md](factory/README.md) |
| Research and evidence log | `research/` |
| Data-frame prototype and its lessons | [reference/prototype/DESIGN.md](reference/prototype/DESIGN.md) |
| Risk tiers, protected paths; one-way limits | `risk.toml`, `ratchets.toml` |
| What each check misses | `docs/CHECK_COVERAGE.md` |

## Commands

```sh
julia scripts/gen.jl --check            # generated files (agents, AGENTS.md, hooks lists) in sync
julia scripts/test/runtests.jl          # tests for the scripts and hooks
julia scripts/check_docs.jl             # stale doc references
julia scripts/dod.jl --base main        # definition of done for the current branch
julia scripts/ci.jl guards --timeout 900  # bound a job (or CI_TIMEOUT=900): kills its whole process group, exit 124
                                        # never an outer `perl -e alarm`/`timeout` around ci.jl: they orphan the group
julia factory/template/scripts/sync_factory.jl --from factory --to . --profile coordinator  # dry run
```
