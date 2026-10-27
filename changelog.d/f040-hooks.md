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
