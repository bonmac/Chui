# shellcheck shell=sh
# _watchdog.sh (0.4.0): an in-hook watchdog for a guard. Sourced after _lib.sh by dispatch_limit.sh;
# never run. Claude Code's hook timeout (10 s, settings.json) fails OPEN: a guard the host kills
# never answered, and the call is allowed. So the guard denies itself first: `watchdog SECS` starts
# a sleeper that sends TERM to the hook after SECS seconds; the TERM trap logs `guard-timeout`,
# prints `[factory] <hook> exceeded SECS s; fails closed.` and exits 2.
# sh runs a trap only between foreground commands, so the slow step must run as
# `watched OUT CMD...` (background + `wait`, which a trapped TERM interrupts). The hook's EXIT trap
# must call `watchdog_stop`, which kills the sleeper and the watched command.
# shellcheck disable=SC2034 # WD_* are read by the functions below
WD_PID="" WD_CHILD="" WD_SECS=""
WD_HOOK=${0##*/}

# watchdog SECS: deny after SECS seconds; '' or 0 disables it.
watchdog() {
    case $1 in '' | *[!0-9]* | 0) return 0 ;; esac
    WD_SECS=$1
    # the sleeper gets no fd of the hook, or the host waits for it to exit before reading the verdict
    (sleep "$1"; kill -TERM "$$" 2>/dev/null) </dev/null >/dev/null 2>&1 &
    WD_PID=$!
    trap watchdog_fire TERM
}
watchdog_fire() {
    WD_PID=""
    watchdog_stop
    ledger guard-timeout hook "$WD_HOOK" secs "$WD_SECS"
    deny "$WD_HOOK exceeded $WD_SECS s; fails closed. The lane count took too long: a huge .lanes/ledger.jsonl? Run scripts/lane compact, or raise FACTORY_WATCHDOG_SECS (the host allows at 10 s)."
}
watchdog_stop() {
    [ -z "$WD_PID" ] || kill "$WD_PID" 2>/dev/null
    [ -z "$WD_CHILD" ] || kill "$WD_CHILD" 2>/dev/null
    WD_PID="" WD_CHILD=""
}
# watched OUT CMD...: run CMD with its stdout in file OUT, in the background, and wait for it (the
# watchdog's TERM interrupts the wait); returns CMD's status.
watched() {
    _wo=$1
    shift
    "$@" >"$_wo" 2>/dev/null </dev/null &
    WD_CHILD=$!
    wait "$WD_CHILD"
    _wrc=$?
    WD_CHILD=""
    return $_wrc
}
