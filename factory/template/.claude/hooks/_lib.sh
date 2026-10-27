# shellcheck shell=sh
# _lib.sh: shared helpers for the factory hooks. Sourced, never run.
# POSIX sh + jq, because a hook runs on every tool call: sh+jq starts in ~5 ms, `julia` in ~150 ms warm (2026-10-19).
# Guards (bash_guard, write_guard, dispatch_limit) fail CLOSED when jq is missing;
# advisory hooks (ledger, idle, precompact) fail OPEN.

HOOKS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=${CLAUDE_PROJECT_DIR:-$(pwd)}
ROOT=${ROOT%/}
ROOT_P=$(CDPATH='' cd -- "$ROOT" 2>/dev/null && pwd -P || printf '%s' "$ROOT")
PAYLOAD=$(cat)
# MAIN (0.2.6): when ROOT is a linked worktree (a lane: its .git is a file `gitdir: <main>/.git/worktrees/<n>`),
# the main checkout, also as MAIN_P (symlinks resolved) and MAIN_L (ROOT minus /.worktrees/<n>, if the same
# directory). Its lane worktrees and .lanes/reports/ count as in-repo (`allowed`): sub-lanes are siblings.
MAIN="" MAIN_P="" MAIN_L=""
if [ -f "$ROOT/.git" ] && read -r _gl <"$ROOT/.git" 2>/dev/null; then
    _gd=${_gl#gitdir: } _back=""
    case $_gl in "gitdir: /"*/.git/worktrees/?*) read -r _back <"$_gd/gitdir" 2>/dev/null || _back="" ;; esac
    # trusted only when the main repo's record of this worktree points back at this root (a crafted .git file does not)
    case $_back in "$ROOT/.git" | "$ROOT_P/.git")
        MAIN=${_gd%/.git/worktrees/*}
        MAIN_P=$(CDPATH='' cd -- "$MAIN" 2>/dev/null && pwd -P) || MAIN_P=$MAIN
        case $ROOT in */.claude/worktrees/?*) _ml=${ROOT%/.claude/worktrees/*} ;; */.worktrees/?*) _ml=${ROOT%/.worktrees/*} ;; *) _ml="" ;; esac
        [ -z "$_ml" ] || [ "$(CDPATH='' cd -- "$_ml" 2>/dev/null && pwd -P)" != "$MAIN_P" ] || MAIN_L=$_ml
        ;;
    esac
fi
# in_main ABS: ABS is in a lane worktree of MAIN (.worktrees/<n>/, .claude/worktrees/<n>/) or MAIN/.lanes/reports/;
# sets IN_MAIN to that MAIN spelling. MAIN's own files stay outside: a lane writes only its repo's lanes and reports.
# shellcheck disable=SC2034 # IN_MAIN is read by t3_check (_bash_guard_write.sh)
in_main() {
    IN_MAIN=""
    [ -n "$MAIN" ] || return 1
    for _m in "$MAIN" "$MAIN_P" "$MAIN_L"; do
        [ -n "$_m" ] || continue
        case $1 in "$_m"/.worktrees/?* | "$_m"/.claude/worktrees/?* | "$_m"/.lanes/reports/?*) IN_MAIN=$_m; return 0 ;; esac
    done
    return 1
}

have_jq() { command -v jq >/dev/null 2>&1; }
need_jq() { have_jq || deny "jq not found on PATH; this guard fails closed. Install jq."; }
field() { printf '%s' "$PAYLOAD" | jq -r "($1) // empty" 2>/dev/null; }
# payload_ok: the payload parses as a JSON object (0.2.4: a guard that cannot read it fails closed).
payload_ok() { printf '%s' "$PAYLOAD" | jq -e 'type == "object"' >/dev/null 2>&1; }
session() { _s=$(field .session_id); printf '%s' "${_s:--}"; }
deny() { printf '[factory] %s%s\n' "$*" "$(root_hint)" >&2; exit 2; }

# root_hint: when the session root is a factory template (factory/template, next to
# MANIFEST.toml), its hooks treat the TEMPLATE as the repo root. Say so in every denial.
root_hint() {
    if [ -f "$ROOT/../MANIFEST.toml" ] && [ "${ROOT##*/}" = template ]; then
        printf ' Note: this session runs with project root %s, a factory template, so the template'"'"'s own hooks apply. Dispatch lanes from the repo root (see factory/README.md).' "$ROOT"
    fi
}

if [ -f "$HOOKS_DIR/limits.env" ]; then . "$HOOKS_DIR/limits.env"; fi
LEDGER_FILE="$ROOT/${LEDGER:-.lanes/ledger.jsonl}"
PENDING_FILE="$(dirname "$LEDGER_FILE")/ledger.pending.jsonl" # appends made while the lock was held (ledger(), below)

# owning_ledger CHECKOUT (0.3.1 F2; Julia's Tdd.owning_ledger is the same rule): prints the TDD ledger of the main
# checkout owning CHECKOUT, <dirname of git's absolute common dir>/.lanes/ledger.jsonl; exit 1, nothing, outside a repo.
owning_ledger() {
    _gcd=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && [ -n "$_gcd" ] || return 1
    printf '%s/.lanes/ledger.jsonl\n' "${_gcd%/*}"
}

# ledger EVENT [KEY VALUE]...: append one JSON line to $LEDGER_FILE (tdd_commit_post repoints it); never fails the hook.
ledger() {
    have_jq || return 0
    mkdir -p "$(dirname "$LEDGER_FILE")" 2>/dev/null || return 0
    ev=$1; shift
    args=""
    while [ $# -ge 2 ]; do
        _v=$(printf '%s' "$2" | tr -c 'A-Za-z0-9_./:@-' '_')
        args="$args --arg $1 ${_v:--}"
        shift 2
    done
    # 0.4.0 (final review M1): never appends to the ledger itself (`lane compact` rewrites it under .lanes/.dispatch.lock).
    # Critic round 3 M1: every event goes to PENDING_FILE and a lock holder then folds it (fold_pending), so the ledger's
    # order is arrival order (a holder's direct append overtook a line that had timed out into pending meanwhile). The lock
    # is waited for about 1 s; without it the event waits in pending. FACTORY_LEDGER_LOCKED=1: the caller holds the lock
    # (dispatch_limit); =pending: append only (the watchdog, which may fire during the lock wait: n1). Not its lock: it stays.
    # The lock and pending file are those beside the CURRENT LEDGER_FILE (0.3.1 merge): a tdd-commit record for
    # another checkout's owning ledger locks and folds that ledger, never the session's.
    _lk="$(dirname "$LEDGER_FILE")/.dispatch.lock" _mine="" _i=0 _to="$(dirname "$LEDGER_FILE")/ledger.pending.jsonl" _fold=""
    case ${FACTORY_LEDGER_LOCKED:-} in
        1) _fold=1 ;;
        pending) ;;
        *) until mkdir "$_lk" 2>/dev/null; do _i=$((_i + 1)); [ "$_i" -lt 10 ] || break; sleep 0.1; done
            [ "$_i" -ge 10 ] || _mine=1 _fold=1 ;;
    esac
    # 0.2.8: after a truncated last line (a crash mid-write) start a new line, or this record is lost
    [ ! -s "$_to" ] || [ -z "$(tail -c 1 "$_to" 2>/dev/null)" ] || printf '\n' >>"$_to" 2>/dev/null
    # shellcheck disable=SC2086 # the line is built first, then appended in one printf (a short open-to-write window)
    _line=$(jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg ev "$ev" --arg session "$(session)" $args '$ARGS.named' 2>/dev/null) &&
        printf '%s\n' "$_line" >>"$_to" 2>/dev/null
    [ -z "$_fold" ] || fold_pending
    [ -z "$_mine" ] || rmdir "$_lk" 2>/dev/null
}
# fold_pending: the caller holds the lock (review round 1 B1, B2). Pending lines are newer than the ledger's tail, so
# a lock taker appends them first, each file (a crash's leftover `.<epoch>.<pid>` first) renamed, appended, removed:
# a writer's `>>` after the rename makes a new pending file. dispatch_limit, ledger() and lane.jl's with_lock call it.
fold_pending() {
    _pp="$(dirname "$LEDGER_FILE")/ledger.pending.jsonl" # beside the current LEDGER_FILE, as in ledger()
    [ ! -f "$_pp" ] || mv "$_pp" "$_pp.$(date +%s).$$" 2>/dev/null
    for _pf in "$_pp".*; do
        [ -f "$_pf" ] || continue
        [ ! -s "$LEDGER_FILE" ] || [ -z "$(tail -c 1 "$LEDGER_FILE" 2>/dev/null)" ] || printf '\n' >>"$LEDGER_FILE" 2>/dev/null
        _sz=$(wc -c <"$_pf" | tr -d ' '); head -c "$_sz" "$_pf" >>"$LEDGER_FILE" 2>/dev/null || continue # then re-read: a write that opened it before the mv
        tail -c +"$((_sz + 1))" "$_pf" >>"$LEDGER_FILE" 2>/dev/null && rm -f "$_pf"
    done
}
# Lane counting (lane_key, OPEN_LANES_JQ, LANE_TTL_SECS) lives in _lanes.sh (0.2.8).
# normpath, abspath and phys live in _paths.sh (split for the 150-line cap); a missing one blocks.
[ -f "$HOOKS_DIR/_paths.sh" ] || deny "$HOOKS_DIR/_paths.sh is missing; the hook fails closed. Restore it (julia scripts/sync_factory.jl)."
# shellcheck source=_paths.sh
. "$HOOKS_DIR/_paths.sh"

# test_role ROLE / tdd_role ROLE (factory 0.3.0, critic C1): the one list of test-side roles (they author the test
# phases and share the test-writer's boundary); a TDD role is a test-side role or the implementer.
test_role() { case $1 in test-writer | law-tester | property-tester | differential-tester) return 0 ;; esac; return 1; }
tdd_role() { [ "$1" = implementer ] || test_role "$1"; }

# allowed ABS: true if ABS is inside the repo root, a lane worktree or the reports of its main checkout (in_main), or a scratch location.
allowed() {
    in_main "$1" && return 0
    case $1 in
        "$ROOT" | "$ROOT"/* | "$ROOT_P" | "$ROOT_P"/*) return 0 ;;
        /dev/null | /dev/stdout | /dev/stderr | /dev/tty | /dev/fd/*) return 0 ;;
        /tmp | /tmp/* | /private/tmp | /private/tmp/* | /var/folders/* | /private/var/folders/*) return 0 ;;
    esac
    if [ -n "${TMPDIR:-}" ]; then
        case $1 in "${TMPDIR%/}" | "${TMPDIR%/}"/* | /private"${TMPDIR%/}"/*) return 0 ;; esac
    fi
    return 1
}
