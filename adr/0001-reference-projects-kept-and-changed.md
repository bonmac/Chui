# ADR-0001: What we kept and what we changed from the three reference projects

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint)
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem (root repo); implemented by `factory/` 0.1.0

## Context

`prompts/common.md` §3 asks for a versioned process template, adapted from three private local
projects: **reference project A** (the base process), **B** (the registry and scorecards project)
and **C** (the adversarial-agents project). They are read-only references and are not named here.
The study summarised in `research/reference-projects.md` checked §3 against their files and
corrected it. The corrections that matter here: all three have a registry generator; A's coverage
floor is fixed, and its real ratchets are size budgets; B documents risk tiers but never enforces
them (several disagreeing protected-path lists, a guard that always allows); every project's CI is
local-only or duplicated; and none has an automated definition of done.

Our constraints: Julia packages (ChuiCore.jl, ChuiTypes.jl, ChuiFrames.jl, later ChuiStats/ChuiLearn/
ChuiSpatial/ChuiPlot; the template itself is name-neutral, with `<Package>`/`<Ecosystem>` placeholders), one GitHub Actions pipeline, about 12 agents, each repo standing alone,
Homebrew Python broken (so `uv` or nothing), and hooks that run on every tool call.

## Decision

### Kept (ported nearly as-is)

| Mechanism | Source | In `factory/template/` |
|---|---|---|
| Registry → generated agent files, `--check` fails on drift/orphans | A | `.agents/agent-registry.toml`, `scripts/gen.jl` |
| Data in TOML, prose bodies concatenated verbatim | C | `.agents/bodies/*.md` |
| Codex agent files from the same registry | B | `.codex/agents/*.toml` |
| Per-agent `scorecard` + `output_format` | A, B | every registry entry (required) |
| CLAUDE.md is the source, AGENTS.md generated | C | `gen.jl`; `claude-only` markers |
| Flow Intake → … → Finish; tier picks the stages; specs/plans paths | A | `CLAUDE.md`, `/intake` |
| ADR template + index | A | `docs/adr/` (copy of `adr/0000-template.md`) |
| Lane CLI new/list/remove; refuse dirty or unmerged; base in git config | A | `scripts/lane.jl` (+ `scripts/lane`) |
| teammate_idle: block the first idle, demand a report, never loop | A | `.claude/hooks/teammate_idle.sh` |
| Lifecycle rules: close with the report, nudge once, idle = failed, simulated marked | B | `lane-lifecycle` skill (one copy) |
| Size budgets that only fall; refuse a raised budget | A, B | `ratchets.toml`, `scripts/ratchet.jl` |
| "Prevented by X" + declared blind spots | C | `.agents/checks.toml` → `docs/CHECK_COVERAGE.md` |
| Doc-reference checker | A, B | `scripts/check_docs.jl` |
| Handoff with "checks NOT run" and closure proof | A, B | `HANDOFF.md` (one template) |

### Adapted

| Mechanism | Source | Change |
|---|---|---|
| Coverage floor | B, C | Same rule (only rises), but checked against the merge base's `ratchets.toml` by script, not by comments |
| Risk tiers T0–T3 + protected paths | B (unenforced), A (warns) | **One** `risk.toml`; `write_guard.sh` *blocks* T3; `dod.jl` raises the tier from touched paths; the PR template is generated from it |
| Merge gate on the merged commit | C (a large local script) | GitHub `merge_group` + required checks; `scripts/dod.jl` (spec/plan ref or T0, tests with `src/`, CHANGELOG, ADR for T3) |
| Lane cap + ledger | C | Cap 4 from the registry; `dispatch_limit.sh` + a slim `.lanes/ledger.jsonl` from SubagentStart/Stop |
| bash_guard | A (a very large Python guard) | ~110-line sh denylist + "no writes outside the repo root"; tests list what it blocks and allows |
| write_guard | A (warns on protected paths) | Blocks writes outside the root and to T3 paths; matched per enclosing checkout (lanes, nested repos) |
| PreCompact advice | A (advice that PreCompact cannot inject) | Snapshot file `.lanes/precompact.md`, re-injected by a SessionStart(`compact`) hook |
| Hook language | A, B, C (Python hooks) | POSIX sh + jq (under 10 ms vs ~150 ms for Julia); Julia stdlib for scripts |
| Critic / red-team / adjudicator | C | One `critic` role; adjudication = reviewer + green CI |
| Meta-guard (every guard reachable) | A | Tests: every hook wired and registered in `checks.toml`; every workflow step calls a `ci.jl` job that exists |
| Factory vendoring | A | `sync_factory.jl`: dry-run diff, per-file hashes in `.factory-version`, local edits are conflicts |

### Dropped

| Dropped | Where it was | Why |
|---|---|---|
| Hand-maintained twin instruction files | B | Drift; AGENTS.md is generated, CLAUDE.md capped at 150 by ratchet |
| Dozens of agents (mostly specialist reviewers) | B | 12 roles; prune by "unused for N phases" |
| Local / duplicated CI | A, B, C | One GitHub Actions pipeline calling `scripts/ci.jl` |
| Top-level logs and plans | B, C | ADRs + index, HANDOFF.md, git history |
| Inline `CORRECTED <date>` notes | A | Git history and ADRs carry corrections |
| Root junk, tracked context logs | A, B | Template `.gitignore`; tests write to temp dirs |
| Absolute `core.hooksPath`, `.git/info/exclude`-only ignores, `approval_mode = "never"` | B, C | Not portable / unsafe |
| A large hand-edited debt register | B | Not built in 0.1.0 (see Consequences) |

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Copy A wholesale | Too many agents (few demonstrably used), a very large Python bash_guard, non-GitHub CI, Python hooks: too big for a Julia package and needs a working Python |
| Hooks in Julia | ~150 ms start-up on every tool call, measured; sh+jq is under 10 ms |
| Hooks in Python via `uv run` | Start-up cost plus a uv dependency inside every hook; Homebrew Python is broken here |
| No generator (hand-written agent files) | The drift every reference project hit; even one project's generator ignored fields it read |
| Git submodule for the factory | Repos must evolve separately and stand alone; a vendored copy + `sync_factory` keeps updates deliberate |

## Consequences

- Every package repo carries about 100 factory files (97 in 0.1.0, generated ones included). They are managed by `sync_factory.jl`, so the cost is a
  reviewed diff per factory version.
- JET (0.12 needs Julia >= 1.12) gets its own environment `test/jet/` and a stable-only `jet` CI job;
  `:doctest`/`:snapshot` test items run on stable only (`CI_STABLE`), so the LTS job resolves and stays green.
- jq becomes a dependency of the hooks (present on macOS and on GitHub runners).
- Not built in 0.1.0: a debt register (`docs/debt.toml`), a Stop-hook gate stamp (from A),
  spec `Status:` checking (from A), paired regression cases for checks (from C).
- Blind spots are listed per check in `docs/CHECK_COVERAGE.md`. The important ones: bash_guard
  cannot see commands built at runtime; teammates may not emit SubagentStart (lane counting UNVERIFIED).

## Verification

- The reference-project study (summary in `research/reference-projects.md`; the full study, with
  file paths, line counts and quotes for every Source above, is kept privately outside the repo).
- `factory/template`: `julia scripts/gen.jl --check`, `julia scripts/test/runtests.jl` (483 tests, on Julia 1.13.2 and 1.10.12), and a
  read-only reviewer pass whose 14 findings were fixed with regression tests,
  shellcheck, actionlint and a PyYAML parse (outputs in the factory lane's report).
- Hook payload fields (TeammateIdle `teammate_name`, SubagentStart/Stop `agent_id`, PreCompact cannot
  inject) come from code.claude.com/docs/en/hooks (fetched 2026-10-19). UNVERIFIED in a live session:
  the SessionStart `compact` matcher re-injection, and whether teammates fire SubagentStart.

## Revisit when

- A lane hits a guard false positive twice, or a blind spot causes a real incident.
- Claude Code changes hook payloads, or teammates get stable ids in hook input.
- The open-lane cap of 4 proves too low or too high over a phase.
