#!/bin/sh
# lane_ledger.sh: appends one slim JSON line per lane event to the lane ledger (.lanes/ledger.jsonl).
# - SubagentStart / SubagentStop: {ev: start|stop, agent_id, agent_type}. A stop closes a background
#   subagent's lane (its agent_id was recorded as `spawned`); starts and stops alone count nothing.
# - PostToolUse / PostToolUseFailure (Agent|Task|TaskStop), 0.2.8:
#   Agent|Task whose result is teammate_spawned or async_launched: {ev: spawned, key, agent_id}
#   (the lane stays open); any other result, or a failure: {ev: close, key} (the agent already ran,
#   or never started). TaskStop, done or failed: {ev: close, ref: task_id, desc: the stopped
#   task's command}; a TaskStop that fails still closes: an agent that cannot be stopped is gone.
# dispatch_limit.sh (which writes `dispatch`) and precompact.sh read it. Advisory: fails open.
. "$(dirname -- "$0")/_lib.sh"
have_jq || exit 0
[ -f "$HOOKS_DIR/_lanes.sh" ] || exit 0 # `.` of a missing file would exit 1 in sh
. "$HOOKS_DIR/_lanes.sh"
ev=$(field '.hook_event_name')
case $ev in
    SubagentStart) ledger start agent_id "$(field '.agent_id')" agent_type "$(field '.agent_type')" ;;
    SubagentStop) ledger stop agent_id "$(field '.agent_id')" agent_type "$(field '.agent_type')" ;;
    PostToolUse | PostToolUseFailure)
        case $(field '.tool_name') in
            TaskStop)
                why=stopped
                [ "$ev" = PostToolUse ] || why=stop-failed
                ledger close ref "$(field '.tool_input.task_id')" desc "$(field '.tool_response.command?')" why "$why"
                ;;
            Agent | Task)
                st=$(field '.tool_response.status?')
                if [ "$ev" = PostToolUse ] && { [ "$st" = teammate_spawned ] || [ "$st" = async_launched ]; }; then
                    ledger spawned key "$(lane_key)" agent_id "$(field '.tool_response.agentId? // .tool_response.agent_id?')"
                else
                    why=returned
                    [ "$ev" = PostToolUse ] || why=failed
                    ledger close key "$(lane_key)" why "$why"
                fi
                ;;
        esac
        ;;
esac
exit 0
