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
# 0.4.0: the whole hook runs under an in-hook watchdog (_watchdog.sh) from here: denied at FACTORY_WATCHDOG_SECS
# (default 8), inside the host's 10 s budget, which fails OPEN. It starts before the TDD dispatch check (fix7, review m1:
# its git reads are `watched`) and the lock wait (up to 5 s alone could spend that budget: critic).
watchdog "${FACTORY_WATCHDOG_SECS:-8}"
trap 'watchdog_stop; rm -f "${TD_OUT:-}"' EXIT # review round 1 m2: a denial in the lock wait exits before the lock is ours: kill the sleeper, keep the lock
# 0.3.0 (review 1 M1): a TDD role's dispatch (tdd_role, _lib.sh) tdd_boundary.sh denies is denied here too, unrecorded:
# the two hooks run in parallel, so recording it would leave a phantom open lane (tdd_dispatch, _lanes.sh)
st=$(field '.tool_input.subagent_type | strings')
! tdd_role "$st" || tdd_dispatch "$st" "$(field '.agent_type | strings')" || deny "tdd_boundary §0.6 ($TD_RULE): $TD_MSG (no lane recorded)."
max=${FACTORY_MAX_OPEN_LANES:-${MAX_OPEN_LANES:-4}}
lock="$(dirname "$LEDGER_FILE")/.dispatch.lock"
mkdir -p "$(dirname "$LEDGER_FILE")" 2>/dev/null || deny "cannot create $(dirname "$LEDGER_FILE"), so no dispatch can be recorded (fails closed)."
_n=0
until mkdir "$lock" 2>/dev/null; do
    # A lock left by a killed hook (older than a minute; the hook timeout is 10 s) is broken by moving
    # it aside, then checking that what moved is still the stale one. If another hook broke it and took
    # a fresh lock in between, what moved is that LIVE lock: put it back and deny, never remove it
    # (re-review m1′: removing it let a third hook enter alongside its holder). Not an empty
    # directory (a file, a non-empty dir): put it back and deny (reviewer B1: it spun). Its `owner`
    # token (this hook's, lane.jl's with_lock: final review n1) does not count as content.
    if [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
        _aside="$lock.stale.$$"
        if mv "$lock" "$_aside" 2>/dev/null; then
            [ -n "$(find "$_aside" -maxdepth 0 -mmin +1 2>/dev/null)" ] || {
                [ -e "$lock" ] || mv "$_aside" "$lock" 2>/dev/null
                deny "the lane ledger lock changed hands while breaking a stale one; retry the dispatch."
            }
            { [ ! -f "$_aside/owner" ] || rm -f "$_aside/owner"; rmdir "$_aside"; } 2>/dev/null && continue
            [ -e "$lock" ] || mv "$_aside" "$lock" 2>/dev/null
            deny "cannot break the stale lock $lock: it is not an empty directory. Inspect and remove it by hand."
        fi
    fi
    _n=$((_n + 1))
    [ "$_n" -lt 50 ] || deny "the lane ledger lock $lock is held (waited 5 s), so the open-lane cap cannot be checked (fails closed). Retry; if no hook is running, remove that directory."
    sleep 0.1
done
_out="$lock.out.$$" _tok="$$.$(date +%s)"
# n1 (final review): the lock holds this hook's `owner` token and is removed at exit only while it is still ours
# (a lock broken as stale and taken by another hook is that hook's); no token written: release it and deny
printf '%s\n' "$_tok" >"$lock/owner" 2>/dev/null || { rmdir "$lock" 2>/dev/null; deny "cannot write $lock/owner (fails closed)."; }
trap '[ "$(cat "$lock/owner" 2>/dev/null)" != "$_tok" ] || { rm -f "$lock/owner"; rmdir "$lock"; } 2>/dev/null; rm -f "$_out"; watchdog_stop' EXIT
trap 'exit 2' INT HUP
FACTORY_LEDGER_LOCKED=1 # ledger() appends to pending and folds it, without taking the lock again (critic round 3 M1, _lib.sh)
fold_pending            # review round 1 B1: pending lines go into the ledger first (they are newer than its tail)
open=0 names=""
set -- # the ledger, then pending as its tail (lines that timed out into it after the fold above, while this lock is held)
for _lf in "$LEDGER_FILE" "$PENDING_FILE"; do [ ! -f "$_lf" ] || set -- "$@" "$_lf"; done
if [ $# -gt 0 ]; then # a malformed line (a crash mid-write) is skipped, not fatal (0.2.3)
    # The count is a `watched` step (background + wait), the only form the watchdog's TERM can interrupt.
    # FACTORY_SLOW_JQ (seconds) is a test-only sleep inside that step, honoured only under FACTORY_TEST=1.
    _slow=""
    [ "${FACTORY_TEST:-}" != 1 ] || _slow=${FACTORY_SLOW_JQ:-}
    watched "$_out" sh -c '[ -z "$1" ] || sleep "$1"; shift; exec jq "$@"' sh "$_slow" -Rrn --arg s "$(session)" --argjson ttl "$LANE_TTL_SECS" \
        "[inputs | fromjson? // empty | objects] | $OPEN_LANES_JQ | \"\\(.count) \\(.ids | join(\" \"))\"" "$@" ||
        deny "cannot read the lane ledger $LEDGER_FILE, so the open-lane cap cannot be checked (fails closed). Repair or move the file."
    out=$(cat "$_out" 2>/dev/null)
    open=${out%% *} names=${out#* }
fi
case $open in '' | *[!0-9]*) deny "the lane ledger $LEDGER_FILE gave no open-lane count ($open); dispatch_limit fails closed." ;; esac
if [ "$open" -ge "$max" ]; then
    _first=${names%% *} _hint=""
    _lim=${FACTORY_LEDGER_LINES:-2000} # 0.4.0 (critic; round 4 A8): a ledger past the line budget is named (before this append)
    _nl=$(wc -l <"$LEDGER_FILE" 2>/dev/null | tr -d ' ')
    [ "${_nl:-0}" -le "$_lim" ] 2>/dev/null || _hint=" The ledger has $_nl lines; run scripts/lane compact. If it stays above $_lim lines it holds that many live chains: raise FACTORY_LEDGER_LINES (default 2000, read by precompact.sh and this hint)."
    ledger dispatch-denied open "$open" max "$max" subagent_type "$st"
    deny "$open lanes are open (cap $max): $names. Read a finished lane's report and close it with TaskStop <name>. If its agent is gone (TaskStop says no task found, or the dispatch never ran), release it: scripts/lane release ${_first:-<name>}. The cap is [lanes] max_open in .agents/agent-registry.toml.$_hint"
fi
ledger dispatch key "$(lane_key)" name "$(field '.tool_input.name')" desc "$(field '.tool_input.description')" \
    subagent_type "$st"
exit 0
