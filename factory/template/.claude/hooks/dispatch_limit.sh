#!/bin/sh
# dispatch_limit.sh: PreToolUse(Agent|Task). Refuses a new subagent or teammate when this
# session already has MAX_OPEN_LANES open lanes, else records the dispatch in the lane ledger.
# 0.2.8: a lane is a `dispatch` this hook records, keyed by the agent's name (lane_key, _lanes.sh),
# and closed by lane_ledger.sh (a `completed` or failed call, a TaskStop, a background agent's
# SubagentStop) or by `scripts/lane release <key>`; see OPEN_LANES_JQ. 0.2.7 counted
# SubagentStart - SubagentStop, which in-process teammates never produce, so the cap never fired.
# Read, count and append run under a lock (.lanes/.dispatch.lock): parallel Agent calls in one
# message run their PreToolUse hooks concurrently, and without it all of them passed (critic M1).
# The cap comes from [lanes] max_open in .agents/agent-registry.toml (generated limits.env);
# FACTORY_MAX_OPEN_LANES in the session env overrides it. Fails closed without jq, a library,
# a writable .lanes/ or the lock.
d=$(dirname -- "$0") # a missing library must block (exit 2), not fail open
for _f in _lib.sh _lanes.sh _watchdog.sh; do
    [ -f "$d/$_f" ] || { printf '[factory] %s is missing; dispatch_limit fails closed.\n' "$d/$_f" >&2; exit 2; }
done
. "$d/_lib.sh"
. "$d/_lanes.sh"
. "$d/_watchdog.sh"
need_jq
payload_ok || deny "cannot parse the hook payload as a JSON object, so the dispatch cannot be keyed or counted (fails closed)."
max=${FACTORY_MAX_OPEN_LANES:-${MAX_OPEN_LANES:-4}}
lock="$(dirname "$LEDGER_FILE")/.dispatch.lock"
mkdir -p "$(dirname "$LEDGER_FILE")" 2>/dev/null || deny "cannot create $(dirname "$LEDGER_FILE"), so no dispatch can be recorded (fails closed)."
# 0.4.0: the whole hook runs under an in-hook watchdog (_watchdog.sh) from here: denied at
# FACTORY_WATCHDOG_SECS (default 8), inside the host's 10 s budget, which fails OPEN. The lock wait below
# (up to 5 s) alone could spend that budget, so the watchdog starts before it (critic).
watchdog "${FACTORY_WATCHDOG_SECS:-8}"
_n=0
until mkdir "$lock" 2>/dev/null; do
    # A lock left by a killed hook (older than a minute; the hook timeout is 10 s) is broken by moving
    # it aside, then checking that what moved is still the stale one. If another hook broke it and took
    # a fresh lock in between, what moved is that LIVE lock: put it back and deny, never remove it
    # (re-review m1′: removing it let a third hook enter alongside its holder). Not an empty
    # directory (a file, a non-empty dir): put it back and deny (reviewer B1: it spun).
    if [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
        _aside="$lock.stale.$$"
        if mv "$lock" "$_aside" 2>/dev/null; then
            [ -n "$(find "$_aside" -maxdepth 0 -mmin +1 2>/dev/null)" ] || {
                [ -e "$lock" ] || mv "$_aside" "$lock" 2>/dev/null
                deny "the lane ledger lock changed hands while breaking a stale one; retry the dispatch."
            }
            rmdir "$_aside" 2>/dev/null && continue
            [ -e "$lock" ] || mv "$_aside" "$lock" 2>/dev/null
            deny "cannot break the stale lock $lock: it is not an empty directory. Inspect and remove it by hand."
        fi
    fi
    _n=$((_n + 1))
    [ "$_n" -lt 50 ] || deny "the lane ledger lock $lock is held (waited 5 s), so the open-lane cap cannot be checked (fails closed). Retry; if no hook is running, remove that directory."
    sleep 0.1
done
_out="$lock.out.$$"
trap 'rmdir "$lock" 2>/dev/null; rm -f "$_out"; watchdog_stop' EXIT
trap 'exit 2' INT HUP
FACTORY_LEDGER_LOCKED=1 # ledger() appends without taking the lock again (0.4.0, _lib.sh)
open=0 names=""
if [ -f "$LEDGER_FILE" ]; then # a malformed line (a crash mid-write) is skipped, not fatal (0.2.3)
    # The count is a `watched` step (background + wait), the only form the watchdog's TERM can interrupt.
    # FACTORY_SLOW_JQ (seconds) is a test-only sleep inside that step, honoured only under FACTORY_TEST=1.
    _slow=""
    [ "${FACTORY_TEST:-}" != 1 ] || _slow=${FACTORY_SLOW_JQ:-}
    watched "$_out" sh -c '[ -z "$1" ] || sleep "$1"; shift; exec jq "$@"' sh "$_slow" -Rrn --arg s "$(session)" --argjson ttl "$LANE_TTL_SECS" \
        "[inputs | fromjson? // empty | objects] | $OPEN_LANES_JQ | \"\\(.count) \\(.ids | join(\" \"))\"" "$LEDGER_FILE" ||
        deny "cannot read the lane ledger $LEDGER_FILE, so the open-lane cap cannot be checked (fails closed). Repair or move the file."
    out=$(cat "$_out" 2>/dev/null)
    open=${out%% *} names=${out#* }
fi
case $open in '' | *[!0-9]*) deny "the lane ledger $LEDGER_FILE gave no open-lane count ($open); dispatch_limit fails closed." ;; esac
if [ "$open" -ge "$max" ]; then
    _first=${names%% *} _hint=""
    _nl=$(wc -l <"$LEDGER_FILE" 2>/dev/null | tr -d ' ') # 0.4.0 (critic): a ledger past 2,000 lines is named (before this append)
    [ "${_nl:-0}" -le 2000 ] 2>/dev/null || _hint=" The ledger has $_nl lines; run scripts/lane compact."
    ledger dispatch-denied open "$open" max "$max" subagent_type "$(field '.tool_input.subagent_type')"
    deny "$open lanes are open (cap $max): $names. Read a finished lane's report and close it with TaskStop <name>. If its agent is gone (TaskStop says no task found, or the dispatch never ran), release it: scripts/lane release ${_first:-<name>}. The cap is [lanes] max_open in .agents/agent-registry.toml.$_hint"
fi
ledger dispatch key "$(lane_key)" name "$(field '.tool_input.name')" desc "$(field '.tool_input.description')" \
    subagent_type "$(field '.tool_input.subagent_type')"
exit 0
