# Factory 0.4.0: a harness that fails closed, agents that are what they claim, reviews that land

Date: 2026-10-27. Status: draft for the user (★). Source: the 2026-10-27 workflow evaluation (three
read-only reviewers over the agents, the skills and commands, and the hooks) and the October usage
report. Plan: `docs/superpowers/plans/2026-10-27-factory-040.md`.

## 1. Problem

The factory's process is strong and its enforcement is porous. Five findings carry the release:

1. **The guards fail open.** The settings.json wrapper exits 2 only when a guard file is missing.
   A guard that crashes (exit 1), a splitter whose awk fails (`bash_guard.sh:41` never checks its
   status) or a hook past the 10 s timeout is treated by Claude Code as "allow". `dispatch_limit`
   scans a never-rotated ledger (1,356 lines, 1,043 `stop` events) with an O(dispatches × events)
   query, so the lane cap is the first guard that will time out.
2. **"Read-only" is a sentence, not a property.** `reviewer` and `critic` disallow Edit/Write but
   keep unrestricted Bash, and bash_guard polices commands only inside the reference roots. The
   critic's gate audit even asks it to delete a gate to see whether a test goes red.
3. **Reviews have nowhere to land.** A read-only agent cannot write `.lanes/reports/<name>.md`, no
   body says what to do when SendMessage is absent, and no output format caps length. One review
   was lost whole to the output-token limit.
4. **The review routine lives in briefs.** Scope audit, base-vs-lane comparison, mutant sweep,
   gates and verdict have no command, and verdict words differ between the registry
   ("approve | changes requested"), the reports ("APPROVE WITH NITS", "ACCEPT WITH FIXES") and the
   lead ("MAY MERGE / yes-with-fixes / fix first"), so nothing can check them.
5. **Rules are restated and drift.** The lane cap is written in CLAUDE.md, the skill ("default 4")
   and a global rule; the registry says 6. Plugin skills (`using-git-worktrees`,
   `subagent-driven-development`, `brainstorming`) conflict with `scripts/lane`, the project
   reviewer and intake tiers, with no stated precedence.

Smaller items, fixed in passing: bare `cd` does not move the tracked cwd to `$HOME`; the read-only
root denial never says "cd back"; the unterminated-heredoc fallback can still match `pkill` in a
heredoc body; `teammate_idle` logs `idle-unreported` on every later idle; `MultiEdit` in a matcher
names a tool that no longer exists; the `Monitor` tool and the codex plugin run commands outside the
Bash matcher; package-only commands (`contract-check`, `release-check`, `test-changed`) are synced
into the coordinator; there is no advisory format check after an edit; lane duration and verdict are
not recorded, so HANDOFF's open-lanes table is typed by hand.

## 2. Decisions

D1. **Any non-zero guard exit blocks.** The wrapper becomes `sh "$f"; rc=$?; [ "$rc" -eq 0 ] || exit 2`.
    `bash_guard` checks the splitter's status. `dispatch_limit` gets an in-hook watchdog that denies at
    8 s, inside Claude Code's 10 s budget. A guard that times out is still a blind spot (the host
    decides), stated in `checks.toml`.
D2. **The ledger is compacted, not grown.** `scripts/lane compact` rewrites `.lanes/ledger.jsonl`
    keeping every event of an open dispatch chain and the last 200 others, atomically, under the
    dispatch lock. `lane_ledger.sh` writes a `stop` only when the agent_id appears in a `spawned`
    record. `precompact.sh` runs `compact` when the ledger exceeds 2,000 lines.
D3. **Read-only is enforced by the hooks.** `gen.jl` renders `READ_ONLY_AGENTS` into `limits.env`
    from `default_mode = "read_only"`. When the payload's `agent_type` is in that list, bash_guard
    allows only the read-only command list plus `julia scripts/dod.jl`, `julia scripts/ci.jl`,
    `scripts/lane audit`, the 0.3.0 `tdd.jl mutate` subcommand, `julia scripts/evidence.jl`, and write_guard
    allows only `.lanes/reports/<agent_type>*.md`. The registry rule becomes: a read-only agent's
    `file_scope` is empty or a subset of `.lanes/reports/**`. The critic's gate audit mutates in
    `tdd.jl mutate`'s scratch worktree, never the tree.
D4. **One review protocol, rendered into every body.** Two fragments, `_preflight` and `_report`, kept
    beside the agent bodies under `.agents/bodies/`, are inserted by `gen.jl` before each body. Pre-flight: print `pwd`,
    `git rev-parse --show-toplevel`, `git branch --show-current`, `git worktree list`; compare with
    the brief's checkout, branch and base; stop on mismatch. Report: write findings to
    `.lanes/reports/<name>.md` as they are confirmed; the final message is the full report;
    SendMessage only in addition. Reports are at most 80 lines; a command is quoted as the command,
    its exit code and its last 20 lines, with the full log under `.lanes/evidence/`.
D5. **One verdict vocabulary.** `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST`, the first line
    of every reviewer and critic report. `scripts/lane audit --report FILE` fails when the file has no
    such line, and records `{ev: verdict, lane, verdict}` in the ledger.
D6. **The review routine is a command.** `/lane-review <lane>` runs, in order: `lane audit`, the
    base-vs-lane test comparison (`ci.jl test` on base and lane, diffing the evidence files), a mutant
    sweep (`tdd.jl mutate` for each new `@testitem`), `ci.jl guards`, then dispatches the reviewer
    with the protocol of D4 and D5. `/change-review` step 2 calls it. `/ci-triage [run-id]` lists the
    failed jobs with `gh run view`, groups them by first failing assertion, reproduces each locally
    with `julia scripts/ci.jl <job> --timeout 900`, and labels each `flake | guard | defect`.
D7. **Numbers live once.** The cap is written only in the registry; the skill and CLAUDE.md carry
    `<!-- claim: max_open=N -->` markers and `check_claims` requires `max_open` in both. The template
    CLAUDE.md gains two short sections: "Precedence" (the factory's lane tool, reviewer, critic, cap
    and intake tiers win over the superpowers equivalents; the plugin skills are used only for
    brainstorming at T2+ and for executing a plan) and "Writing files under the guard" (Edit/Write,
    never heredocs; no bare `cd`; a refused probe is reported `NOT RUN`, never routed around).
D8. **A Julia-aware verifier replaces the global tester here.** New read-only agent `verifier`: runs
    `julia scripts/ci.jl <job> --timeout`, records `scripts/evidence.jl`, reports counts from the
    evidence file. The global `~/.claude/agents/reviewer.md` and `tester.md` are outside the write
    boundary: the plan asks the user to rename the first `code-reviewer` and delete the second.
D9. **Defence in depth in settings.json.** `permissions.deny` lists `Bash(git push --force*)`,
    `Bash(git push -f*)`, and Edit/Write of the T3 globs; the hooks remain the primary check.
    `Monitor` joins the Bash matcher; a payload without `tool_input.command` is denied (fails
    closed) until a probe records the field name. The codex plugin is documented as uncovered.
D10. **An advisory format hook.** PostToolUse(Edit|Write) on `*.jl` runs `runic --check FILE` when a
    `runic` executable exists and exits 2 with the diff summary when the file is unformatted; it
    exits 0 silently otherwise. Advisory by design: the gate still formats.
D11. **Lanes are measured.** `scripts/lane stats` prints, per lane of the ledger: dispatched at,
    closed at, duration, verdict, `dispatch-denied` and `idle-unreported` counts. `scripts/lane handoff`
    prints the open-lanes Markdown table HANDOFF uses, from `git worktree list` and the ledger.
D12. **Coordinator profile excludes package-only commands.** `MANIFEST.toml` `[profiles.coordinator]`
    excludes `.claude/commands/{contract-check,release-check,test-changed}.md`.

## 3. Out of scope

A parallel review swarm with a synthesizer; a persistent CI watcher; a self-healing gate loop;
instruction-token budgeting per agent. Each is a later release once D4–D6 have run for a phase.
The 0.3.0 test-writer work (tw-031, Tasks 8–12) ships first; 0.4.0 starts from its sync. Task 1 of
the plan (D1) is kept self-contained so the user may pull it into 0.3.0.

## 4. Decisions for the user (★)

1. Ship D1 inside 0.3.0, or wait for 0.4.0?
2. The verdict words of D5 (or your own three).
3. D7's precedence: disable the three conflicting superpowers skills in this project, or keep them
   behind the stated precedence?
4. The report cap (80 lines) and the evidence tail (20 lines).
5. Rename the global `reviewer` and delete the global `tester` (outside the write boundary: your hand).
6. Housekeeping: remove `.worktrees/tw-030-verify` (it has uncommitted edits to `tdd.jl` and
   `_tdd_backfill.jl` on a detached HEAD: keep or drop?) and `.claude/worktrees/lead-l0`; replace
   `junta` with `chui` in `prompts/common.md:164` and `prompts/README.md:35,44,45` (T3).

## 5. Acceptance

- A guard that exits 1, or whose splitter fails, blocks (tests in `scripts/test/test_hooks.jl`).
- `dispatch_limit` on a 20,000-line ledger answers in under 8 s or denies.
- A reviewer subagent's `sed -i`, `git commit` and `tee` are denied; its `git diff`, `dod.jl` and a
  Write to `.lanes/reports/reviewer.md` are allowed.
- Every generated agent file starts with the pre-flight and report fragments.
- `lane audit --report` rejects a report without a verdict line.
- `check_claims --strict` fails when the skill's cap disagrees with the registry.
- `gen.jl --check`, the factory suite on `julia` and `julia +lts`, `check_docs`, `dod.jl` green;
  reviewer and critic final reports `MAY MERGE`.
