#!/bin/sh
# shellcheck disable=SC1091
# tdd_commit_post.sh (factory 0.3.0, spec §0.5): PostToolUse(Bash) and PostToolUseFailure(Bash), the
# authoritative half of the commit guard. A call that commits and then fails fires only PostToolUseFailure,
# so both events run it. For the call's .lanes/tdd-pending/<tool_use_id> entry (written by tdd_boundary.sh
# before every allowed `git commit`), each commit since the recorded HEAD (`git rev-list <before>..HEAD`; an
# amend yields the amended commit) is checked: author against the caller, the `TDD:` phase against its role,
# a role's `TDD-Mode:` line, and the changed paths against the role. Each is appended to the session ledger
# as tdd-commit {agent_id, agent_type, checkout, sha}; a broken rule also as tdd-commit-violation {..., rule,
# reason} and printed (exit 2: PostToolUse cannot undo a commit; audit E5 fails the lane). First, entries
# of other calls older than TDD_STALE_MIN minutes (a cancelled call fires neither event) are swept: recorded
# with late=true and deleted. `tdd_commit_post.sh sweep` (run by tdd_boundary.sh) only sweeps.
# Advisory: it fails open (exit 1) without jq or a library; E5 then fails the unrecorded commits.
case $0 in */*) d=${0%/*} ;; *) d=. ;; esac
for _l in _lib.sh _bash_guard_lib.sh _tdd_commit_guard.sh; do
    [ -f "$d/$_l" ] || { printf '[factory] %s is missing: tdd_commit_post cannot record commits (audit E5 will fail them).\n' "$d/$_l" >&2; exit 1; }
done
. "$d/_lib.sh"
. "$d/_bash_guard_lib.sh"
. "$d/_tdd_commit_guard.sh"
for _f in "$PEND"/*; do [ -e "$_f" ] || exit 0; break; done # the common path: no commit pending, no fork
have_jq || { printf '[factory] jq not found: tdd_commit_post cannot record commits (audit E5 will fail them).\n' >&2; exit 1; }
tu=$(field '.tool_use_id | strings')
case $tu in *[!A-Za-z0-9_-]*) tu="" ;; esac
VIOL=""

# check_commit CHECKOUT SHA AGENT_TYPE AGENT_ID LATE: record one commit, and any rule it breaks
check_commit() {
    _id=$(git -C "$1" log -1 --format='%an <%ae>' "$2" 2>/dev/null)
    _msg=$(git -C "$1" log -1 --format=%B "$2" 2>/dev/null)
    id_rule "$3" "$_id"
    _rule=$IDR
    case $3 in test-writer | implementer)
        _ph=$(printf '%s\n' "$_msg" | awk 'tolower($1) == "tdd:" { print $2; exit }')
        _md=$(printf '%s\n' "$_msg" | awk 'tolower($1) == "tdd-mode:" { print "m"; exit }')
        case "$3:$_ph" in
            *: | test-writer:red | test-writer:test-fix | test-writer:test-refactor | test-writer:backfill) ;;
            implementer:stub | implementer:green | implementer:refactor) ;;
            *) _rule=${_rule:-phase-not-role} ;;
        esac
        [ -z "$_md" ] || _rule=${_rule:-mode-trailer}
        [ -z "$(git -C "$1" diff-tree --no-commit-id --name-only -r --root "$2" 2>/dev/null | role_paths "$3")" ] || _rule=${_rule:-path-not-role} ;;
    esac
    if [ -n "$5" ]; then
        ledger tdd-commit agent_id "$4" agent_type "$3" checkout "$1" sha "$2" late true
    else
        ledger tdd-commit agent_id "$4" agent_type "$3" checkout "$1" sha "$2"
    fi
    [ -n "$_rule" ] || return 0
    ledger tdd-commit-violation agent_id "$4" agent_type "$3" checkout "$1" sha "$2" rule "$_rule" reason "$_rule"
    VIOL="$VIOL $_rule: $2 (author $_id, caller $3, in $1);"
}
# record FILE LATE: every commit made since the entry's HEADs, then delete the entry (claimed by mv first,
# so a sweep and a post hook never record one entry twice)
record() {
    _c="$1.claim$$"
    mv "$1" "$_c" 2>/dev/null || return 0
    _at=- _aid=-
    while read -r _h _co; do
        case $_h in @) _at=${_co%% *} _aid=${_co#* }; continue ;; esac
        [ -d "$_co" ] || continue
        case $_h in none) _r=HEAD ;; *) _r="$_h..HEAD" ;; esac
        for _s in $(git -C "$_co" rev-list --max-count=100 "$_r" 2>/dev/null); do
            check_commit "$_co" "$_s" "${_at:--}" "${_aid:--}" "$2"
        done
    done <"$_c"
    rm -f "$_c"
}

# shellcheck disable=SC2044 # entry names are tool_use_ids ([A-Za-z0-9_-], checked by tdd_boundary.sh)
for _f in $(find "$PEND" -mindepth 1 -maxdepth 1 -type f -mmin +"$TDD_STALE_MIN" 2>/dev/null); do
    [ "${_f##*/}" = "$tu" ] || record "$_f" true
done
[ "${1:-}" = sweep ] || [ -z "$tu" ] || [ ! -f "$PEND/$tu" ] || record "$PEND/$tu" ""
[ -z "$VIOL" ] && exit 0
printf '[factory] tdd commit violation (spec §0.5):%s PostToolUse cannot undo a commit: tdd.jl audit (E5) fails this lane until it is replaced by a commit that fits the role.\n' "$VIOL" >&2
exit 2
