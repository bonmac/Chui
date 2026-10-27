#!/bin/sh
# precompact.sh: PreCompact. Writes .lanes/precompact.md, a short snapshot of the state that
# must survive compaction (branch, dirty files, worktrees, open lanes, what to preserve).
# PreCompact output cannot be injected into the summary, so session_start.sh (SessionStart,
# matcher "compact") prints this file back into context afterwards. Fails open.
. "$(dirname -- "$0")/_lib.sh"
out="$ROOT/.lanes/precompact.md"
mkdir -p "$ROOT/.lanes" 2>/dev/null || exit 0
{
    echo "# Pre-compaction snapshot ($(date -u +%Y-%m-%dT%H:%M:%SZ), trigger: $(field '.trigger'))"
    echo
    echo "- branch: $(git -C "$ROOT" branch --show-current 2>/dev/null)"
    echo "- head: $(git -C "$ROOT" log -1 --format='%h %s' 2>/dev/null)"
    echo "- dirty files (first 15):"
    git -C "$ROOT" status --short 2>/dev/null | head -15 | sed 's/^/    /'
    echo "- worktrees:"
    git -C "$ROOT" worktree list 2>/dev/null | head -10 | sed 's/^/    /'
    if have_jq && [ -f "$LEDGER_FILE" ] && [ -f "$HOOKS_DIR/_lanes.sh" ] && . "$HOOKS_DIR/_lanes.sh"; then
        echo "- open lanes (dispatched, not closed, this session):"
        jq -Rrn --arg s "$(session)" --argjson ttl "$LANE_TTL_SECS" "[inputs | fromjson? // empty | objects] | $OPEN_LANES_JQ | (.ids[] | \"    \" + .), \"    (count: \\(.count))\"" "$LEDGER_FILE" 2>/dev/null
    fi
    echo
    echo "Preserve: the task and its brief, file scopes in flight, decisions made, commands run"
    echo "with results, failures seen, checks NOT run, the agent roster, and the next action."
    echo "Update HANDOFF.md now if any of that is only in the conversation."
} >"$out" 2>/dev/null
# 0.4.0 (D2): a ledger over 2,000 lines is compacted after the snapshot (`scripts/lane compact`: every
# event of an open dispatch chain is kept, plus the last 200 others), so dispatch_limit's count stays
# inside its watchdog. Needs julia on PATH and scripts/lane.jl in the root; any failure is ignored.
# Detached (review round 1 m4: nohup, background, no fd of the hook): the hook returns at once, so the
# host's hook timeout cannot kill a compaction half-way and leave its .dispatch.lock behind.
if [ -f "$LEDGER_FILE" ] && [ -f "$ROOT/scripts/lane.jl" ] && command -v julia >/dev/null 2>&1 &&
    [ "$(wc -l <"$LEDGER_FILE" 2>/dev/null | tr -d ' ')" -gt 2000 ] 2>/dev/null; then
    nohup julia --startup-file=no "$ROOT/scripts/lane.jl" compact --repo "$ROOT" >/dev/null 2>&1 </dev/null &
fi
exit 0
