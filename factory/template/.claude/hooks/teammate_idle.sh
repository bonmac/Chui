#!/bin/sh
# teammate_idle.sh: TeammateIdle. The first idle of a teammate without a report is blocked
# (exit 2: stderr goes back to the teammate, which keeps working) and a report is demanded.
# A report counts if `.lanes/reports/<name>.md` exists in the repo root OR in any lane worktree
# (.worktrees/*/, .claude/worktrees/*/; 0.2.6: a lane's session writes inside its own worktree,
# and write_guard lets a lane write <main>/.lanes/reports/ too). The second idle is allowed (a hook
# that blocks every idle is a loop) and logged as `idle-unreported` so the lead treats the
# lane as FAILED unless a SendMessage report arrived. Fails open.
. "$(dirname -- "$0")/_lib.sh"
have_jq || exit 0
name=$(field '.teammate_name')
[ -n "$name" ] || exit 0
safe=$(printf '%s' "$name" | tr -c 'A-Za-z0-9_.-' '_')
key="$(field '.session_id')/$(field '.team_name')/$safe"
seen="$ROOT/.lanes/teammate-idle.seen"

# 0.4.0 (D4, D5, critic): `<name>.md` or `<name>-<round>.md` (round: digits only, review round 1 m3:
# `f040-hooks.md` is the f040-hooks lane's, not f040's), and it counts only when its first line is the
# verdict line; any other first line is a PARTIAL report, blocked once like no report at all.
partial=""
for report in "$ROOT/.lanes/reports/$safe.md" "$ROOT/.lanes/reports/$safe"-[0-9]*.md \
    "$ROOT"/.worktrees/*/.lanes/reports/"$safe.md" "$ROOT"/.worktrees/*/.lanes/reports/"$safe"-[0-9]*.md \
    "$ROOT"/.claude/worktrees/*/.lanes/reports/"$safe.md" "$ROOT"/.claude/worktrees/*/.lanes/reports/"$safe"-[0-9]*.md; do
    [ -f "$report" ] || continue
    _round=${report##*/}; _round=${_round%.md}; _round=${_round#"$safe"}; _round=${_round#-}
    case $_round in *[!0-9]*) continue ;; esac
    IFS= read -r _first <"$report" || :
    case $_first in
        "Verdict: MAY MERGE" | "Verdict: MERGE WITH FIXES" | "Verdict: FIX FIRST") ledger idle-reported teammate "$safe"; exit 0 ;;
        *) partial=$report ;;
    esac
done
mkdir -p "$ROOT/.lanes" 2>/dev/null || exit 0
grep -qxF -- "$key unreported" "$seen" 2>/dev/null && exit 0 # 0.4.0: idle-unreported is logged once per key, not on every later idle
if grep -qxF -- "$key" "$seen" 2>/dev/null; then
    printf '%s unreported\n' "$key" >>"$seen" 2>/dev/null
    ledger idle-unreported teammate "$safe"
    exit 0
fi
printf '%s\n' "$key" >>"$seen" 2>/dev/null || exit 0 # cannot remember => never block
ledger idle-blocked teammate "$safe"
[ -z "$partial" ] || deny "$partial is a partial report: its first line is not the verdict line (Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST). Finish it, put the verdict on line 1, and send the full report to the lead with SendMessage. An idle lane with no final report is treated as FAILED."
deny "Before going idle, send your final report to the lead with SendMessage (summary, files changed, commands run with output, checks NOT run and why, scorecard), or write it to .lanes/reports/$safe.md (in your repo root or your lane worktree), first line 'Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST'. An idle lane with no report is treated as FAILED."
