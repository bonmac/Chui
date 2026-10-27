# ADR-0016: The harness fails closed, read-only agents are read-only in fact, and every review lands in one format

- **Status:** Accepted (2026-10-27, user, at the factory 0.4.0 ★). The user's six answers are
  recorded under "Decision". Implementation follows the plan, after factory 0.3.0.
- **Date:** 2026-10-27
- **Deciders:** the user. The change is T3 in every repo that takes it: the hooks, `settings.json`,
  the registry, the bodies and `gen.jl`.
- **Scope:** ecosystem: the factory template (0.4.0), the coordinator, and every package that
  syncs it.

The full design is `docs/superpowers/specs/2026-10-27-factory-040-design.md` (the spec); the plan
is `docs/superpowers/plans/2026-10-27-factory-040.md`. This ADR records D1, D3, D4, D5 and D9 only;
D2 and D6–D12 are implementation choices that live in the spec.

## Context

- **The guards fail open** (spec §1.1). The `settings.json` wrapper exits 2 only when a guard file
  is missing. A guard that exits 1, a splitter whose awk fails (`bash_guard.sh:41` never checks its
  status) or a hook past the 10 s timeout counts as "allow". `dispatch_limit` scans a never-rotated
  ledger (1,356 lines) with an O(dispatches × events) query, so it is the first guard to time out.
- **"Read-only" is a sentence** (spec §1.2). `reviewer` and `critic` disallow Edit/Write but keep
  unrestricted Bash; bash_guard polices commands only inside the reference roots. The critic's gate
  audit asks it to delete a gate in the tree.
- **Reviews have nowhere to land** (spec §1.3). A read-only agent cannot write
  `.lanes/reports/<name>.md`, no body says what to do without SendMessage, and nothing caps length.
  One review was lost whole to the output-token limit.
- **Verdict words differ** (spec §1.4) between the registry, the reports and the lead, so no check
  can read them.
- PreToolUse input carries `agent_type` for a lead-dispatched Agent-tool subagent and for an
  in-process teammate (the 0.3.0 Task-0 probe, `.lanes/archive/tw-task0/probe.jsonl`: four records
  with `agent_type: reviewer`). **UNVERIFIED** for a tmux-pane teammate. D3 depends on it.

## Decision

1. **D1: any non-zero guard exit blocks** (spec §2 D1).
   - The `settings.json` wrapper must exit 2 whenever a guard exits non-zero, including 1 and 143
     (SIGTERM); it must not treat a crash as "allow".
   - `bash_guard` must check the splitter's exit status and block when it fails.
   - `dispatch_limit` must deny from an in-hook watchdog at 8 s, inside Claude Code's 10 s budget,
     and log a `guard-timeout` ledger event. A host-side timeout remains a blind spot, stated in
     `checks.toml`.
2. **D3: read-only is enforced by the hooks** (spec §2 D3).
   - `gen.jl` must render `READ_ONLY_AGENTS` into `limits.env` from `default_mode = "read_only"`.
   - *(Amended 2026-10-27 after review rounds 1–4 and critic round 2; the earlier text listed
     `julia scripts/ci.jl` unqualified, `tdd.jl mutate`, `evidence.jl` unqualified, reports named
     `<agent_type>*.md` and a mutate-worktree gate audit.)* When the payload's `agent_type` is in
     that list, bash_guard must allow only, by subcommand, with fixed option sets for the text tools
     and `cp`/`mkdir`, with every redirect refused and no `--root`: the read-only command list for
     agents (`RO_AGENT_CMDS`, its own list), `git` read subcommands with `-C` only into a trusted
     checkout (the root, the main checkout, their lane worktrees; never `.lanes/`),
     `julia scripts/dod.jl`, `julia scripts/ci.jl {test,guards,quality,docs}`,
     `julia scripts/gen.jl --check`, `scripts/lane audit`, `julia scripts/evidence.jl latest` and
     `evidence.jl <kind> -- <cmd>` when `<cmd>` passes this same allowlist,
     `julia scripts/test/runtests.jl`, with `julia` taking only `--startup-file=no` and a
     `+channel`, and every script path resolved against the tracked cwd to a trusted checkout's
     own `scripts/`. `tdd.jl mutate` is not allowed. write_guard must allow only `.lanes/reports/**`
     and `.lanes/scratch/<agent_type>/**`.
   - A read-only agent's `file_scope` must be empty or a subset of those two globs.
   - The critic's gate audit of a hook must run in a copy of `.claude/hooks` under its scratch with
     `julia scripts/test/runtests.jl hooks --hooks-dir <copy>`; a gate script is audited by
     specification, run by the lead in a scratch copy.
   - Enforcement keys on the dispatch's `agent_type`: an agent of another type briefed as a
     reviewer is unrestricted (a stated blind spot). The property holds against a mistaken agent
     and against every adversarial route the four review rounds tried; `checks.toml` lists what
     remains unmodelled.
3. **D4: one review protocol in every body** (spec §2 D4).
   - `gen.jl` must insert `_preflight` and `_report` (in `.agents/bodies/`) between the Mode line
     and each body, and `_verdict` only into read-only agents *(amended 2026-10-27, critic round 2:
     a write agent's line 1 is `Status: DONE | PARTIAL | BLOCKED`, never a verdict)*.
   - Pre-flight: print `pwd`, `git rev-parse --show-toplevel`, `git branch --show-current`,
     `git worktree list`; on a mismatch with the brief the agent must stop.
   - Findings must be written to `.lanes/reports/<name>.md` as they are confirmed; the final
     message is the full report; SendMessage is in addition, never instead.
   - A report must not exceed **80 lines** (★4); a command is quoted as the command, its exit code
     and its **last 20 lines**, with the full log under `.lanes/evidence/`.
4. **D5: one verdict vocabulary** (spec §2 D5; ★2).
   - The first line of every reviewer and critic report must be
     `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST`, exact case.
   - Line 2 must be `Head: <sha>` naming the lane HEAD the review covered *(amended 2026-10-27)*.
   - `scripts/lane audit --report FILE` must fail on a file without those two lines, on a Head that
     is not the lane's current HEAD, on a dirty lane worktree, and on a report whose name is not a
     ledger dispatch of a read-only agent (reviewer, critic, verifier); it records
     `{ev: verdict, lane, verdict, head, report}` in the ledger.
5. **D9: coverage, not a second rule set** (spec §2 D9; *amended 2026-10-27, critic round 1 M4:
   the earlier text mandated a `permissions.deny` list*).
   - There must be no static `permissions.deny` list: it would defeat the user's
     `FACTORY_ALLOW_T3=1` and block `--force-with-lease`, and its glob semantics are UNVERIFIED.
   - `Monitor` must join the Bash matcher; a payload without `tool_input.command` must be denied.
     The codex plugin is documented as uncovered.

**The user's answers (★, 2026-10-27).**
- ★1: D1 ships in 0.4.0, after 0.3.0. Lane f040 starts now and is rebased (reviewed) after tw-031
  merges.
- ★2: the verdict words above.
- ★3: the superpowers conflicts are resolved by a precedence note only (spec D7); no skill is
  disabled.
- ★4: 80-line report cap, 20-line output tail.
- ★5: the global `reviewer` and `tester` agents are the user's hand; no lane touches them.
- ★6: `.worktrees/tw-030-verify` is left to the other session.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Claude Code `permissions.deny` alone, or as a second layer | Applies to the whole session, with no per-agent scope: it cannot let the lead write while denying the reviewer. As a second layer it is static, so it would defeat `FACTORY_ALLOW_T3=1` and block `--force-with-lease` (critic round 1, M4); dropped. |
| `Bash(pattern)` allowlists in agent frontmatter | UNVERIFIED that subagent frontmatter honours `Bash(...)` patterns; a silent no-op would leave the hole open while reading as closed. |
| A separate `write_guard` per agent | Multiplies hook files and the per-call cost; one guard keyed on `agent_type` keeps one tested path and one list rendered by `gen.jl`. |
| Leaving read-only as a written rule | It is today's state, and spec §1.2 shows it failing: the critic's own brief asks it to edit the tree. |

## Consequences

- Easier: a guard bug denies instead of allowing; reviews survive the token limit; the lead and
  `lane audit` can parse verdicts.
- Harder: a guard bug now blocks work until fixed; read-only agents need any new tool added to the
  allowlist first.
- Files: `factory/template/.claude/settings.json`, `hooks/{bash_guard,write_guard,dispatch_limit,_lib}.sh`,
  `.agents/checks.toml`, `.agents/agent-registry.toml`, `.agents/bodies/_preflight.md`,
  `_report.md`, `scripts/gen.jl`, `scripts/lane.jl`, and `scripts/test/test_hooks.jl`.

## Verification

- Spec §1 records the measurements (ledger size, wrapper behaviour, `bash_guard.sh:41`).
- Spec §5 lists the acceptance tests that will prove D1, D3, D4 and D5 (plan Tasks 1, 3, 4, 5).
- Fourteen review rounds on the sub-lanes (reports in `.lanes/reports/f040-*.md`) each closed
  their findings with the same reproducer quoted RED then GREEN: two heredoc bypasses, four
  read-only escapes, three option-spelling bypasses, one `rg` program-execution route, one
  `cp -s` symlink write.
- **UNVERIFIED:** PreToolUse `agent_type` for a tmux-pane teammate; whether frontmatter
  `Bash(...)` allowlists work for subagents; `onFailure: "block"` on a PreToolUse timeout; whether
  tmux-pane teammates honour the registry `tools:` list.

## Revisit when

- The ledger records a `guard-timeout` event: the watchdog's 8 s or the ledger query is wrong.
- A review is lost to the output-token limit after 0.4.0: the 80-line cap or D4's write-as-you-go
  rule is not holding.
- A commit, a changed file or a ledger event shows a write by a read-only agent outside
  `.lanes/reports/` and its scratch (the lane audit cannot see scratch writes; a reviewer's
  `git status` in the lane, or a changed T3 file, can): D3's hook has a gap.
- A new release of an allowlisted tool adds an option that writes or runs a program (as ripgrep
  15.2 added `--hostname-bin`): its fixed option set needs a review.
