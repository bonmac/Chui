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
- **UNVERIFIED:** that PreToolUse input carries `agent_type` for a lead-dispatched subagent on this
  machine (ADR-0015 "Verification"; plan 0.3.0 Task 0's probe). D3 depends on it.

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
   - When the payload's `agent_type` is in that list, bash_guard must allow only the read-only
     command list plus `julia scripts/dod.jl`, `julia scripts/ci.jl`, `scripts/lane audit`,
     `tdd.jl mutate` and `julia scripts/evidence.jl`, and write_guard must allow only
     `.lanes/reports/<agent_type>*.md`.
   - A read-only agent's `file_scope` must be empty or a subset of `.lanes/reports/**`.
   - The critic's gate audit must mutate in `tdd.jl mutate`'s scratch worktree, never the tree.
3. **D4: one review protocol in every body** (spec §2 D4).
   - `gen.jl` must insert `_preflight` and `_report` (in `.agents/bodies/`) before each body.
   - Pre-flight: print `pwd`, `git rev-parse --show-toplevel`, `git branch --show-current`,
     `git worktree list`; on a mismatch with the brief the agent must stop.
   - Findings must be written to `.lanes/reports/<name>.md` as they are confirmed; the final
     message is the full report; SendMessage is in addition, never instead.
   - A report must not exceed **80 lines** (★4); a command is quoted as the command, its exit code
     and its **last 20 lines**, with the full log under `.lanes/evidence/`.
4. **D5: one verdict vocabulary** (spec §2 D5; ★2).
   - The first line of every reviewer and critic report must be
     `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST`, exact case.
   - `scripts/lane audit --report FILE` must fail on a file without that line and must record
     `{ev: verdict, lane, verdict}` in the ledger.
5. **D9: defence in depth in `settings.json`** (spec §2 D9).
   - `permissions.deny` must list `Bash(git push --force*)`, `Bash(git push -f*)` and Edit/Write of
     the T3 globs; the hooks remain the primary check.
   - `Monitor` must join the Bash matcher; a payload without `tool_input.command` must be denied
     until a probe records the field name. The codex plugin is documented as uncovered.

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
| Claude Code `permissions.deny` alone | Applies to the whole session, with no per-agent scope: it cannot let the lead write while denying the reviewer. Kept as a second layer (D9), not the mechanism. |
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
- **UNVERIFIED:** PreToolUse `agent_type` for a subagent here; whether frontmatter `Bash(...)`
  allowlists work for subagents; the `Monitor` payload's command field name.

## Revisit when

- The ledger records a `guard-timeout` event: the watchdog's 8 s or the ledger query is wrong.
- A review is lost to the output-token limit after 0.4.0: the 80-line cap or D4's write-as-you-go
  rule is not holding.
- `lane audit` finds a write by a read-only agent outside `.lanes/reports/`: D3's hook has a gap.
