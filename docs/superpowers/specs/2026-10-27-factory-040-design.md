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
    `bash_guard` denies when the splitter exits non-zero, and when it returns nothing for a non-empty
    command (an `awk` that exits 0 with empty output would otherwise allow everything). `dispatch_limit`
    gets an in-hook watchdog that starts before the lock loop, kills the hook's foreground child (a
    POSIX sh defers a trapped TERM until that child returns) and denies at 8 s from start, inside
    Claude Code's 10 s budget. A guard that times out at the host is still a blind spot (the host
    decides; the hook option `onFailure: "block"` is UNVERIFIED for PreToolUse timeouts), stated in
    `checks.toml`.
D2. **The ledger is compacted, not grown.** `scripts/lane compact` rewrites `.lanes/ledger.jsonl`
    keeping every `dispatch`, `spawned`, `unknown-result`, `close`, `release`, `verdict`,
    `dispatch-denied` and `guard-timeout` event, so no session's open chain and no `$known` name is
    lost, and dropping only `stop` events whose agent_id matches no `spawned` or `unknown-result`
    record (the query closes on either) and `idle-*` events older than the last 200 lines. It rewrites atomically under the dispatch lock, and the
    `ledger()` appender in `_lib.sh` takes the same lock, so no append is lost between read and
    rename; `lane.jl`'s own appends (`release`, `verdict`, `new`) take it too. `lane_ledger.sh`
    writes a `stop` only when the agent_id appears in a `spawned` or `unknown-result` record.
    `precompact.sh` runs `compact` when the ledger exceeds 2,000 lines, and `dispatch_limit`'s denial
    names `scripts/lane compact` when it does.
D3. **Read-only is enforced by the hooks.** `gen.jl` renders `READ_ONLY_AGENTS` into `limits.env`
    from `default_mode = "read_only"`. When the payload's `agent_type` is in that list (the Task-0
    probe recorded `agent_type` for Agent-tool subagents and in-process teammates; tmux-pane
    teammates are UNVERIFIED), bash_guard allows only, by SUBCOMMAND and with no `--root` anywhere:
    the read-only command list with every redirect target refused (not only targets outside the
    root), `find` without `-delete`/`-exec`/`-fprint`, `git` with no `-c`/`--output` and only
    `log show diff status blame ls-files merge-base rev-parse`, `branch --show-current|--list`,
    `worktree list`; `julia scripts/dod.jl`; `julia scripts/ci.jl {test,guards,quality,docs}`;
    `scripts/lane audit`; `julia scripts/evidence.jl latest`; `julia scripts/test/runtests.jl`.
    `evidence.jl <kind> -- <cmd>` and `tdd.jl mutate` are NOT allowed (both run arbitrary commands or
    write worktrees). write_guard allows `.lanes/reports/**` and `.lanes/scratch/<agent_type>/**`,
    and bash_guard allows `cp`/`mkdir` whose targets are under that scratch. The registry rule
    becomes: a read-only agent's `file_scope` is empty or a subset of those two globs. The critic's
    gate audit of a hook: copy `.claude/hooks` into its scratch, mutate the copy with Write, run
    `julia scripts/test/runtests.jl hooks --hooks-dir <scratch>`; a mutation no test catches is the
    finding. A gate script (`dod.jl`, `ci.jl`) is audited by specification: the critic names the
    mutation and the test expected to go red, and the lead runs it in a scratch copy. Enforcement
    keys on the dispatch's agent type, so an agent of another type briefed as a reviewer is
    unrestricted: a blind spot in `checks.toml`.
D4. **One review protocol, rendered into every body.** Two fragments, `_preflight` and `_report`, kept
    beside the agent bodies under `.agents/bodies/`, are inserted by `gen.jl` before each body. Pre-flight: print `pwd`,
    `git rev-parse --show-toplevel`, `git branch --show-current`, `git worktree list`; compare with
    the brief's checkout, branch and base; stop on mismatch. Report: write findings to
    `.lanes/reports/<name>.md` or `<name>-<round>.md` as they are confirmed, where `<name>` is the
    dispatch name (`teammate_name` / `tool_input.name`), else the agent type; the one rule is shared
    by write_guard, teammate_idle and `/lane-review`. A file counts as a report only once its first
    line is the Verdict line (teammate_idle reads it), so a partial file is not "reported". The final
    message is the full report; SendMessage only in addition. Reports are at most 80 lines; a
    command is quoted as the command, its exit code and its last 20 lines, with the full log under
    `.lanes/evidence/`.
D5. **One verdict vocabulary.** `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST`, the first line
    of every reviewer and critic report, matched anchored and case-exact
    (`^Verdict: (MAY MERGE|MERGE WITH FIXES|FIX FIRST)$`; the literal template line and a bold
    variant are rejected), followed by `Head: <sha>` naming the lane HEAD the review covered.
    `scripts/lane audit --report FILE` fails when either line is missing or the Head is not the lane's
    current HEAD (a stale round), and records `{ev: verdict, lane, verdict, head, report}`.
D6. **The review routine is a command.** `/lane-review <lane>` runs, in order: `lane audit`, the
    base-vs-lane test comparison, a mutant sweep, `ci.jl guards`, then dispatches the reviewer with
    the protocol of D4 and D5. The test gate depends on the repo: a `Project.toml` → `ci.jl test` on
    base and lane with the evidence files diffed, and `tdd.jl mutate` per new `@testitem`; a
    `factory/` → the factory suite on both, and the hook-mutation route of D3; neither → `NOT RUN`.
    A `not applicable` result from `ci.jl` is printed as `NOT RUN`, never as a green comparison. `/change-review` step 2 calls it. `/ci-triage [run-id]` lists the
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
D9. **Coverage, not a second rule set.** A `permissions.deny` list was rejected: it is static, so
    it would defeat the user's `FACTORY_ALLOW_T3=1` and block `--force-with-lease`, and its glob
    semantics are UNVERIFIED. `Monitor` joins the Bash matcher; a payload without
    `tool_input.command` is denied (fails closed) until a probe records the field name. The codex
    plugin is documented as uncovered.
D10. **An advisory format hook.** PostToolUse(Edit|Write) on `*.jl` runs `runic --check FILE` when a
    `runic` executable exists and exits 2 with the diff summary when the file is unformatted; it
    exits 0 silently otherwise. Advisory by design: the gate still formats.
D11. **Lanes are measured.** `scripts/lane stats` prints, per lane of the ledger: dispatched at,
    closed at, duration, verdict, `dispatch-denied` and `idle-unreported` counts. `scripts/lane handoff`
    prints the open-lanes Markdown table HANDOFF uses, from `git worktree list` and the ledger.
D12. **Coordinator profile excludes package-only commands.** `MANIFEST.toml` `[profiles.coordinator]`
    excludes `.claude/commands/{contract-check,release-check,test-changed}.md`.

## 2a. Critic round 1 (2026-10-27, FIX FIRST; resolved above)

Errors accepted and folded in: `evidence.jl -- <cmd>` and `tdd.jl mutate --root` escaped D3 (B1);
the inherited read-only allowlist let `cat a > src/x`, `find -delete`, `git -c core.fsmonitor`,
`git branch -f` and `git worktree remove` through (B2); `tdd.jl mutate` cannot target hooks and the
coordinator has no `Project.toml`, so the gate audit and `/lane-review` would have read "did not
run" as green (B3); the splitter test was not RED and the real gap was empty output (B4); the
watchdog could not pre-empt a trapped TERM and started after the lock wait (B5); per-session
compaction dropped other sessions' chains and `$known` (M1); four report-name rules disagreed and a
partial file counted as reported (M2); a stale verdict file passed (M3); static deny rules defeated
`FACTORY_ALLOW_T3` (M4). Disagreement noted: enforcement keys on agent type (m1), now a stated
blind spot. Still UNVERIFIED: `agent_type` for tmux-pane teammates; `onFailure: "block"` on a
PreToolUse timeout; whether the host waits on a stderr pipe held by an orphaned child.

**Review rounds on f040-hooks (2026-10-27):** a lenient heredoc terminator (leading or trailing
blank, CR, or `WORD)` at top level) let a nested heredoc hide the lines the shell actually runs
(B1, a regression from 0.2.8); and `WORD)` inside `$(...)` ends the body in bash but not in zsh,
which the Bash tool runs here (B2). Rule: a body ends only on an exact terminator line (tab-strip
for `<<-`); a `WORD)` or `WORD )` line inside a `$(...)` body is refused as ambiguous, with the
closing `)` to be put on its own line. The guard models no shell's leniency it cannot prove in both.

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
