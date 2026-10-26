# shellcheck shell=sh
# _lanes.sh (0.2.8): how the lane ledger counts open lanes. Sourced after _lib.sh by
# dispatch_limit.sh, lane_ledger.sh and precompact.sh; never run. Split from _lib.sh to keep both
# under the 150-line hook budget (ratchets.toml).

# lane_key: the lane an Agent/Task call opens or closes. PreToolUse and PostToolUse of one call
# give the same key: tool_input.name (a teammate), else tu:<tool_use_id>, else desc:<description>.
lane_key() {
    _k=$(field '.tool_input.name')
    [ -z "$_k" ] || { printf '%s' "$_k"; return 0; }
    _k=$(field '.tool_use_id')
    [ -z "$_k" ] || { printf 'tu:%s' "$_k"; return 0; }
    printf 'desc:%s' "$(field '.tool_input.description')"
}

# LANE_TTL_SECS: a dispatch older than FACTORY_LANE_TTL_HOURS (default 24; 0 = never) stops counting.
# A value that is not a whole number falls back to 24.
_ttl=${FACTORY_LANE_TTL_HOURS:-24}
case $_ttl in '' | *[!0-9]*) _ttl=24 ;; esac
# shellcheck disable=SC2034 # used by the hooks that source this file
LANE_TTL_SECS=$((_ttl * 3600))

# OPEN_LANES_JQ (run with --arg s SESSION --argjson ttl "$LANE_TTL_SECS"): the `dispatch` events of
# this session that no later event closes. A later event closes a dispatch if it is a `close` with
# the same key, or a ref equal to its name, key or spawned agent_id, or (a TaskStop given an
# internal task id) a desc equal to its description; or a SubagentStop (`stop`) whose agent_id is
# its spawned agent_id. SubagentStart/Stop alone count nothing: in-process teammates do not balance
# them (0.2.7 counted start - stop, and the cap never fired). One count per key; a ts that does not
# parse counts as fresh (toward the cap).
# shellcheck disable=SC2034 # used by the hooks that source this file
OPEN_LANES_JQ='now as $now
  | [.[] | select(.session == $s)] as $all
  | [range(0; $all | length) as $i | $all[$i] + {_i: $i}] as $e
  | [$e[] | select(.ev == "dispatch") | . as $d
     | [$e[] | select(.ev == "spawned" and ._i > $d._i and .key == $d.key)
        | .agent_id | select(. != null and . != "-")] as $aids
     | select(([$e[] | select(._i > $d._i)
         | select(
             (.ev == "close" and (
                 .key == $d.key
                 or ((.ref // "-") as $r | $r != "-" and ($r == $d.name or $r == $d.key or any($aids[]; . == $r)))
                 or ((.desc // "-") as $c | $c != "-" and $c == $d.desc)))
             or (.ev == "stop" and (.agent_id as $a | any($aids[]; . == $a))))
         ] | length) == 0)
     | select($ttl == 0 or (try ($d.ts | fromdateiso8601) catch $now) > $now - $ttl)
     | $d.key] | unique as $ids
  | {ids: $ids, count: ($ids | length)}'
