- **factory 0.4.0, agents** (`factory/template/`; not yet versioned or synced). Plan Tasks 3 and 4 of
  `docs/superpowers/plans/2026-10-27-factory-040.md` (ADR-0016, D3, D4, D5, D8):
  - Read-only agents are enforced by the guards: `scripts/gen.jl` renders `READ_ONLY_AGENTS` into
    `factory/template/.claude/hooks/limits.env` from every `default_mode = "read_only"` agent, and the new
    sourced library `factory/template/.claude/hooks/_bash_guard_agents.sh` (a missing one blocks) makes
    `bash_guard.sh` allow such an agent (payload `agent_type`) only the D3 allowlist, by subcommand, with
    every output redirection, inline assignment and `--root` refused (the read-only commands; `find`
    without `-delete`/`-exec`/`-ok`/`-fprint*`/`-fls`; `git` read subcommands with no `-c`/`--config-env`/
    `--exec-path`/`--git-dir`/`--work-tree`/`--output`; `julia scripts/dod.jl`, `scripts/ci.jl
    {test,guards,quality,docs}`, `scripts/evidence.jl latest` or `<kind> -- <an allowed command>`,
    `scripts/test/runtests.jl`; `scripts/lane audit`; `cp`/`mkdir` into `.lanes/scratch/<agent_type>/`),
    and `write_guard.sh` allow it only `.lanes/reports/**` and `.lanes/scratch/<agent_type>/**`. The lead
    (no `agent_type`) is unchanged; a `limits.env` without the list fails closed for every agent. The
    registry rule is now "a read_only agent's `file_scope` is empty or a subset of those two globs";
    `reviewer` and `critic` own them and gain `Write` (Edit stays disallowed); the critic's gate audit
    mutates a copy under `.lanes/scratch/critic/hooks` and runs `julia scripts/test/runtests.jl hooks
    --hooks-dir <copy>` (new: `runtests.jl [NAME...] [--hooks-dir DIR]`). New check `read_only_agents`
    in `factory/template/.agents/checks.toml` (blind spots: keyed on the dispatch's agent_type; tmux-pane
    teammates UNVERIFIED; the allowlisted scripts are trusted). The f040-lane sibling's lane-stats helper
    (included by lane.jl) is T3 in `factory/template/risk.toml`. Tests: `factory/template/scripts/test/test_hooks_agents.jl`.
  - One review protocol in every agent: the fragments `factory/template/.agents/bodies/_preflight.md`
    (print `pwd`, `git rev-parse --show-toplevel`, `git branch --show-current`, `git worktree list`;
    compare with the brief; stop on a mismatch) and `_report.md` (findings written to
    `.lanes/reports/<name>.md` or `<name>-<round>.md` as they are confirmed, counted as a report only
    once line 1 is `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST` and line 2 `Head: <sha>`; the
    final message is the full report, SendMessage in addition; at most 80 lines, a command quoted as the
    command, its exit code and its last 20 lines, the full log under `.lanes/evidence/`) are rendered by
    `scripts/gen.jl` into every `.claude/agents/*.md` and `.codex/agents/*.toml` between the "Mode:" line
    and the body; an underscore-prefixed body is a fragment, never an agent, and a missing one fails
    `gen.jl`. Every `output_format` ends with `; at most 80 lines` (`gen.jl --check` fails otherwise);
    the reviewer's and critic's start with `verdict (MAY MERGE | MERGE WITH FIXES | FIX FIRST), head`.
    New read-only agent `verifier` (D8: runs `julia scripts/evidence.jl <job> -- julia scripts/ci.jl
    <job> --timeout 900`, reports counts from the evidence file; tools Read, Grep, Glob, Bash, Write,
    SendMessage; file scope as the reviewer's), so `READ_ONLY_AGENTS=" critic reviewer verifier "`.
