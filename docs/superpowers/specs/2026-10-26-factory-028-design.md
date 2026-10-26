# Factory 0.2.8: the lane cap counts dispatches, not SubagentStart

Status: proposed (factory-028 lane, 2026-10-26). Tier: factory template change (hooks).

## Problem

`dispatch_limit.sh` (PreToolUse `Agent|Task`) counted open lanes from the ledger as
`SubagentStart` minus `SubagentStop` per session (`OPEN_LANES_JQ` in `_lib.sh`). In the
coordinator's `.lanes/ledger.jsonl` (843 lines, read 2026-10-26):

- 32 `start`, 716 `stop`. The last `start` is 2026-10-20T14:12:09Z.
- The lead session `5afff6eb…` has 77 `stop` lines, each with a different `agent_id` and
  `agent_type` `-`, and no `start` at all. In that session the lead made 8 Agent dispatches
  (all `name`d in-process teammates) and 5 `TaskStop` calls (transcript
  `5afff6eb-….jsonl`).
- The teammates' ids in the Agent results are `<name>@session-5afff6eb`. None of the 77 stop
  ids matches one, so the stops cannot be tied to lanes. What these stops are is UNVERIFIED
  (perhaps teammate turns or internal agents). The Claude Code hooks docs (Context7
  `/websites/code_claude`, 2026-10-26) say SubagentStart fires "each time an in-process agent
  team teammate handles a new message". The ledger shows no such starts since 2026-10-20, so
  docs and behaviour disagree here, and the factory cannot rely on either event for teammates.

So the open count is always ≤ 0 and the cap (`max_open` 6 in the coordinator) never fires.

## Evidence used for the design (real payloads, from this machine's transcripts)

| Call | What Claude Code returned | Source |
|---|---|---|
| `Agent` with `name` (teammate) | `tool_input.name`, `.subagent_type`, `.description`; result `status: "teammate_spawned"`, `agent_id: "<name>@session-<id>"` | 76 results across transcripts |
| `Agent` without `name` (background) | result `status: "async_launched"`, `agentId: "a…"` (hex), `description` | 25 results |
| `TaskStop` | `tool_input.task_id` = the teammate's **name** (lead session, 5 of 5); result `task_id: "t…"` (an internal id), `command` = the dispatch's `description` | 5afff6eb transcript; older results |
| background subagent end | `SubagentStop` with `agent_id` = the `agentId` above | ledger: `a1fe551924b42e788` start/stop in `fef4cd0a`, same id as that session's `async_launched` |

Hook payload field names (`tool_input`, `tool_response`, `tool_use_id`, `hook_event_name`) are
from the hooks docs. **UNVERIFIED:** that a CLI PostToolUse payload's `tool_response` has the
same shape as the transcript's `toolUseResult` above; that `PostToolUseFailure` fires for a
failed `Agent`/`TaskStop` call; what a foreground (non-background) `Agent` result's status is.
The design does not depend on the last one (see rule 2).

## Design

A lane is a **dispatch**, recorded where the cap is checked, and closed by the events that the
lead's own tool calls produce. SubagentStart/SubagentStop stay in the ledger for the record
but no longer count.

Key of a lane: `tool_input.name` if set, else `tu:<tool_use_id>`, else `desc:<description>`.
PreToolUse and PostToolUse of the same call compute the same key.

1. **Open** (`dispatch_limit.sh`, PreToolUse `Agent|Task`): count open lanes; if below the cap,
   append `{ev: "dispatch", key, name, desc, subagent_type}` and allow. The record is written
   before the call runs, so N parallel Agent calls in one message are counted one by one
   (PreToolUse runs per call; whether Claude Code serialises the N hooks is UNVERIFIED, see
   blind spots).
2. **Spawned or returned** (`lane_ledger.sh`, PostToolUse `Agent|Task`): if
   `tool_response.status` is `teammate_spawned` or `async_launched`, append
   `{ev: "spawned", key, agent_id}`: the lane stays open. Any other result means the agent
   already ran to completion (a foreground call), so append `{ev: "close", key, why: "returned"}`.
3. **Dispatch failed** (`lane_ledger.sh`, PostToolUseFailure `Agent|Task`): `close`, why `failed`.
4. **Stopped** (`lane_ledger.sh`, PostToolUse and PostToolUseFailure `TaskStop`):
   `{ev: "close", ref: tool_input.task_id, desc: tool_response.command}`. A failed TaskStop
   closes too: an agent that cannot be stopped is not running. This is the manual way to clear a
   lane whose agent crashed: `TaskStop <name>`.
5. **Background subagent finished** (`lane_ledger.sh`, SubagentStop): its `stop` line closes the
   lane whose `spawned.agent_id` equals the stop's `agent_id`. Teammate turns never match
   (their ids differ), so a teammate stays open until TaskStop.

A `dispatch` is open when no later event in the same session closes it. A later event closes
it if it is a `close` with the same `key`, or a `ref` equal to its name, key or spawned
agent_id, or (fallback, for a TaskStop given the internal `t…` id) a `desc` equal to its
description; or a `stop` whose `agent_id` is its spawned agent_id. Open dispatches are grouped
by key, so re-dispatching an open name counts once.

### Decisions the brief asked for

- **No start record (fail open or closed?)** A close that matches no dispatch is ignored; the
  count never goes negative and old `start`/`stop`-only ledgers count 0 open lanes. That is
  fail-open for a ledger written before 0.2.8, on purpose: the old records are exactly the ones
  that cannot be trusted. Fail-closed stays where it was: no jq, a missing `_lib.sh`, or a
  ledger that cannot be read blocks the dispatch.
- **Stale lanes (a crashed agent).** (a) `TaskStop <name>` closes it, even when the stop fails;
  (b) a dispatch older than `FACTORY_LANE_TTL_HOURS` (default 24) no longer counts. A `ts` that
  does not parse counts as fresh (toward the cap). The denial lists the open lane names, so
  the lead knows what to stop.
- **Resumes and double counting.** Re-dispatching an open key counts once. A teammate resumed
  by SendMessage after a TaskStop is not a new dispatch and is not counted (blind spot). A
  closed key dispatched again is open again.
- **Scope:** per `session_id`, as before. A teammate's own dispatches count in its own session.

### Not changed

`teammate_idle.sh` (an idle teammate still holds a lane until it is stopped);
`limits.env` generation (the TTL is an env override with a default in `_lib.sh`, no new
registry key). `precompact.sh` keeps reading `OPEN_LANES_JQ` (`.ids`, `.count`); the ids are
now lane keys (names).

## Blind spots (for CHECK_COVERAGE)

- A teammate resumed with SendMessage after TaskStop is not counted.
- A dispatch whose call never runs and produces no PostToolUse/PostToolUseFailure (the user
  denies the permission prompt; another PreToolUse hook denies it after dispatch_limit allowed
  it) stays open until TaskStop or the TTL. UNVERIFIED whether PostToolUseFailure fires then.
- Parallel Agent calls in one message: correct only if Claude Code runs their PreToolUse hooks
  one after another (UNVERIFIED); otherwise the cap can be exceeded by the batch size minus 1.
- The `desc` fallback can close the wrong lane when two open lanes share a description.
- Workflow-tool fan-out is not counted (unchanged).
- A foreground subagent counts only while its Agent call runs (correct), but a foreground call
  whose PostToolUse never arrives (session killed) stays until the TTL.
