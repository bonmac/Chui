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
  - Critic corrections (applied in the lane): `bash_guard.sh` also denies when the splitter returns
    nothing for a non-blank, non-comment command; the dispatch watchdog starts before the lock wait
    (so the whole hook answers within `FACTORY_WATCHDOG_SECS`) and the count runs as one background
    `sh -c '…exec jq…'` step that the watchdog's TERM interrupts; every `ledger()` append takes
    `.lanes/.dispatch.lock` for up to about 1 s (then appends anyway; `FACTORY_LEDGER_LOCKED=1` skips
    it for the holder), so `scripts/lane compact` cannot lose an append; a cap denial on a ledger over
    2,000 lines names the line count and `scripts/lane compact`; `teammate_idle.sh` counts a report
    (`<name>.md` or `<name>-*.md`) only when its first line is `Verdict: MAY MERGE | MERGE WITH FIXES
    | FIX FIRST`, else it is partial and the idle is blocked once; no `permissions.deny` list is added.
  - The 0.4.0 hook testsets live in the new `scripts/test/test_hooks_040.jl`, included from
    `test_hooks.jl`: that file and `test_hooks_lifecycle.jl` had passed the 400-line `scripts/*.jl`
    budget of `ratchets.toml` (the full gate's `test_ratchet.jl` caught it).
  - Review round 1 fixes: heredoc terminators are exact again (a line equal to WORD, leading tabs
    stripped for `<<-`), plus WORD followed by `)` only inside `"$(...)"`; the lenient match above
    (trailing blanks, a CR, leading blanks, a top-level `EOF)`) ended a body where bash does not, so
    a later body line could open a second heredoc that hid the lines bash runs (B1, a bypass: such a
    body now stays open and the fallback checks it as commands). `_watchdog.sh` sets
    `FACTORY_LEDGER_LOCKED=1` before its `guard-timeout` append (a fire during the lock wait answered
    at 2 s, not 1 s; m1); `dispatch_limit.sh` sets an EXIT trap with `watchdog_stop` as soon as the
    watchdog starts (a denial during the lock wait left the sleeper alive; m2); `teammate_idle.sh`
    counts `<name>-<digits>.md` only (`f040` no longer claims `f040-hooks.md`; m3); `precompact.sh`
    runs the compaction detached (`nohup ... &`), so the hook returns at once and the host's timeout
    cannot kill it half-way (m4). Also: the awk records, when a heredoc opens, whether it is inside
    an open `$(` (the `EOF)` terminator is accepted from that flag only); a heredoc whose `$(...)`
    closes or opens on the `<<` line (`"$(cat <<EOF)"`) is denied outright, since bash 5 reads its
    body from the next lines while bash 3.2 and zsh run them as commands (a pre-existing gap: those
    lines were a dropped body); `lane_ledger.sh` writes a `stop` for an agent_id that a `spawned` OR
    an `unknown-result` record names (the open-lane query closes a lane on either; sibling review).
