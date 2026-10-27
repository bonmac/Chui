- **factory 0.4.0, hooks** (`factory/template/`; not yet versioned or synced). Plan Task 1 and the
  hook parts of Task 2 of `docs/superpowers/plans/2026-10-27-factory-040.md` (ADR-0016, D1, D2):
  - Every non-zero guard exit blocks: the three `settings.json` wrappers exit 2 on any failure of
    `bash_guard.sh`, `write_guard.sh` and `dispatch_limit.sh` (a crash, exit 1, SIGTERM 143), not
    only when the script is missing. `bash_guard.sh` denies when its command splitter fails (awk
    missing or crashed): the empty segment list used to pass everything. `dispatch_limit.sh` runs
    its count under an in-hook watchdog (new library `.claude/hooks/_watchdog.sh`,
    `FACTORY_WATCHDOG_SECS`, default 8 s, inside the host's 10 s budget, which fails open) and
    logs `guard-timeout`. The Bash matcher also covers `Monitor` (its input is `command`, or `ws`
    with no command, which is denied); `MultiEdit` leaves the Edit matcher. `checks.toml` states
    the remaining blind spot: a host-side timeout still allows.
  - Quiet stops, bare `cd`, heredoc terminators, "cd back": `lane_ledger.sh` writes a `stop` only
    for an agent_id that a `spawned` record names (teammate turns wrote 1,043 noise lines);
    `precompact.sh` runs `julia scripts/lane.jl compact --repo <root>` after its snapshot when the
    ledger exceeds 2,000 lines (the subcommand is the `f040-lane` sibling's; the hook is tested with
    a `julia` stub); `bash_guard.sh` moves the tracked cwd to `$HOME` on a bare `cd`, ends a heredoc
    body at a terminator with trailing blanks, a CR, leading blanks or a following `)` (so `pkill`
    in such a body is a body, not a command, and what follows is still checked), and its read-only
    root denial says to cd back to the repo root; `teammate_idle.sh` logs `idle-unreported` once
    per teammate key, not on every later idle.
