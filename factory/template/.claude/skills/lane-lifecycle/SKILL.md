---
name: lane-lifecycle
description: Rules for dispatching, monitoring, closing and reporting agent lanes (subagents, teammates, worktree lanes). Use whenever you dispatch an agent or a lane goes quiet.
---
<!-- Factory-managed (see .factory-version). -->
# Lane lifecycle

**Dispatch**
- One lane = one repo, one file scope, one deliverable, one definition of done. No two open
  lanes share a file.
- Give the agent its brief, its scope, and the output format from its registry entry.
- Worktree lanes: `scripts/lane new <name> --owns '<globs>' [--base main]` creates
  `.worktrees/<name>` and records the globs the lane may touch (`changelog.d/<name>.md` is
  added). The brief's file scope and `--owns` are the same list. It copies the machine-local,
  gitignored `.agents/factory.local.toml` into the lane and runs `scripts/gen.jl` there (the
  user's own file; without it a repo that requires read-only roots blocks every Bash call in the lane).
- Sub-lanes: `scripts/lane new` run inside a lane creates a SIBLING, `<repo>/.worktrees/<sub>`.
  A session rooted in a lane worktree may write the repo's other lane worktrees (`.worktrees/*`,
  `.claude/worktrees/*`) and `<repo>/.lanes/reports/`, not the main checkout; T3 paths stay
  blocked there. Do not work in scratch copies. The parent lane still owns the merge.
- The brief says: change files with Edit/Write only, never `sed -i`, redirects or heredocs.
- Each lane records its change in `changelog.d/<name>.md`, never in `CHANGELOG.md`.
- The cap is `[lanes] max_open` (default 4). `dispatch_limit.sh` refuses the next spawn. A lane
  is an Agent dispatch, open until its call returns (foreground), its background agent stops, or
  you `TaskStop <name>` it (a teammate). Give every teammate a `name`. A lane whose agent is gone
  (TaskStop says no task found; a dispatch that never ran) is released with
  `scripts/lane release <name>`. A spawned teammate or background agent is never dropped by time.

**Test-first lanes (factory 0.3.0, ADR-0015)**
- Each task gets two agents, each a fresh `subagent_type` dispatch (Agent call, the brief as
  `prompt`): `test-writer` (RED, test-fix, test-refactor, backfill) then `implementer` (STUB,
  GREEN, REFACTOR). Never a fork, never one agent switching roles, never one resumed with the other's transcript, no
  `team_name`: subagents only, not teammates. A `name` is allowed (`tw-<lane>-<task>`,
  `impl-<lane>-<task>`): a named teammate's payloads still carry `agent_type`. Continue an agent
  only within its own task.
- The hooks key the role on `agent_type` only, never `agent_id` (a named dispatch has none). The
  lead is the caller with no `agent_type`. SubagentStart/SubagentStop never fired here; nothing
  relies on them.
- A new agent type added mid-session is not dispatchable until the session restarts: after
  syncing 0.3.0 and adding the registry entries, restart the session before the first TDD dispatch.
- Dispatch only on a clean lane. `julia scripts/tdd.jl brief --role test-writer|implementer --root
  <lane checkout>` prints the header, the public API and the stub diffs, and saves the brief under
  `<main>/.lanes/briefs/<lane>/`; add the rest by hand. `tdd_boundary` checks the header (role,
  `checkout=` a lane worktree, `head=` its HEAD) and saves the prompt under `dispatched/`.
- **The brief is the only channel.** Never relay src beyond the stub diffs, a GREEN/REFACTOR diff,
  or the other agent's report or reasoning. A test-fix request passes on verbatim.
- test-writer brief:

  ```
  <!-- tdd-brief role=test-writer lane=<lane> checkout=<abs path of the lane worktree> head=<sha> -->
  ## Task    (the plan task text)
  ## Spec    (the path)
  ## Public API   (tdd.jl api output; docs/src pages)
  ## Stub diffs   (git show of each stub commit, only if H5 passed)
  ## Test-fix requests   (verbatim, if any)
  ## Boundary  (spec §0.4 and §0.6, quoted)
  ```

- implementer brief: the same header with `role=implementer`, then `## Task`, `## Spec`,
  `## Red tests` (paths and shas), `## Red evidence` (paths) and `## Boundary`. Never the
  test-writer's report or messages.
- **Mode.** The lead records it as a `TDD-Mode: required|refactor|skip — <reason>` trailer on a
  commit authored `lead <lead@factory.invalid>` (e.g. `git commit --allow-empty --author "lead
  <lead@factory.invalid>"`). The commit guard denies that identity and trailer to any caller with
  an `agent_type`. Default `required`; no `src/`/`ext/` change needs none.
- Before the merge: `/change-review` runs `tdd.jl audit --ledger` and `dod.jl`.
  **Merge, never rebase:** evidence is keyed by sha; after a rebase run `tdd.jl green` at the tip, and audit
  lists the missing reds for the lead to decide.

**Monitor**
- Wait for completion notifications; do not poll output files.
- Bound every long run with `julia scripts/ci.jl <job> --timeout SECONDS` (or `CI_TIMEOUT`), and
  put that in the brief. Never use `perl -e 'alarm N; exec @ARGV'` or `timeout`: they kill only
  ci.jl, and Pkg.test's child julia runs on (a hung property test ran ~6 h at 97% CPU). On expiry
  ci.jl kills the whole process group and exits 124, which is TIMED OUT, not a pass. Ctrl-C does the
  same and exits 130. Killing ci.jl with any other signal (`kill`, `timeout`) orphans the group.
- Reviewers may send a preview first. Wait for the final report.

**Idle**
- An agent idle without a report is unproven: nudge it once (SendMessage) asking for the report.
- Still nothing: it is a FAILED lane. Re-dispatch with a narrower brief, or review its diff
  yourself, and say which you did. Never count its work as reviewed.

**Close**
- Before a lane lands, `scripts/lane audit <name> --reported <file>` (the changed files the lane
  reported) must pass; a path outside `--owns` is a finding, not a formality. It diffs against
  the local base when that contains `origin/<base>` (local merges not yet pushed are not the
  lane's); `--base B` audits against another base.
- A lane's report: SendMessage, or `.lanes/reports/<name>.md` in its worktree or the repo root
  (`teammate_idle` reads both).
- Close the agent (TaskStop) in the same step as reading its report. A listing is not proof of
  closure. Before recording a lane as `no_report`, check once more for a late message: a report
  can arrive after the stop.
- Remove a merged worktree lane with `scripts/lane remove <name>`; show `git worktree list`.

**Report**
- `subagent_mode: actual | simulated | mixed`. Simulated means the pass was not spawned.
- The roster: which agents ran, which lanes were skipped and why, which failed or went idle.
- Verify a lane's claims (re-run its test command) before building on them. Test counts come
  from an evidence file (`julia scripts/evidence.jl tests -- <cmd>`); cite it.
