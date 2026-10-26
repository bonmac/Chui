#!/bin/sh
# dispatch_limit.sh: PreToolUse(Agent|Task). Refuses a new subagent or teammate when this
# session already has MAX_OPEN_LANES open lanes, else records the dispatch in the lane ledger.
# 0.2.8: a lane is a `dispatch` this hook records, keyed by the agent's name (lane_key, _lib.sh),
# and closed by lane_ledger.sh (the call's result or failure, a TaskStop, a background agent's
# SubagentStop); see OPEN_LANES_JQ. 0.2.7 counted SubagentStart - SubagentStop, which in-process
# teammates never produce, so the cap never fired.
# The cap comes from [lanes] max_open in .agents/agent-registry.toml (generated limits.env);
# FACTORY_MAX_OPEN_LANES in the session env overrides it. Fails closed without jq.
d=$(dirname -- "$0") # a missing library must block (exit 2), not fail open
for _f in _lib.sh _lanes.sh; do
    [ -f "$d/$_f" ] || { printf '[factory] %s is missing; dispatch_limit fails closed.\n' "$d/$_f" >&2; exit 2; }
done
. "$d/_lib.sh"
. "$d/_lanes.sh"
need_jq
max=${FACTORY_MAX_OPEN_LANES:-${MAX_OPEN_LANES:-4}}
open=0 names=""
if [ -f "$LEDGER_FILE" ]; then # a malformed line (a crash mid-write) is skipped, not fatal (0.2.3)
    out=$(jq -Rrn --arg s "$(session)" --argjson ttl "$LANE_TTL_SECS" \
        "[inputs | fromjson? // empty | objects] | $OPEN_LANES_JQ | \"\\(.count) \\(.ids | join(\", \"))\"" "$LEDGER_FILE" 2>/dev/null) ||
        deny "cannot read the lane ledger $LEDGER_FILE, so the open-lane cap cannot be checked (fails closed). Repair or move the file."
    open=${out%% *} names=${out#* }
fi
case $open in '' | *[!0-9]*) deny "the lane ledger $LEDGER_FILE gave no open-lane count ($open); dispatch_limit fails closed." ;; esac
if [ "$open" -ge "$max" ]; then
    ledger dispatch-denied open "$open" max "$max" subagent_type "$(field '.tool_input.subagent_type')"
    deny "$open lanes are open (cap $max): $names. Read a finished lane's report and close it (TaskStop <name>; this also clears a lane whose agent is gone) before dispatching another. A lane stops counting after FACTORY_LANE_TTL_HOURS (default 24). The cap is [lanes] max_open in .agents/agent-registry.toml."
fi
ledger dispatch key "$(lane_key)" name "$(field '.tool_input.name')" desc "$(field '.tool_input.description')" \
    subagent_type "$(field '.tool_input.subagent_type')"
exit 0
