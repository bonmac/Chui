# shellcheck shell=sh
# shellcheck disable=SC2034,SC2154 # cwd is bash_guard.sh's; ROOT/MAIN* are _lib.sh's; ro_deny is in _bash_guard_agents.sh
# _bash_guard_agents_paths.sh: where a read-only agent's command runs, and which script it runs (factory 0.4.0
# review round 1, B2-B4). Sourced by bash_guard.sh after _bash_guard_agents.sh; costs no fork. The agent writes
# only its scratch and the reports, so a file there is the agent's own: a Manifest, a gitdir whose config runs a
# command (core.fsmonitor), a scripts/dod.jl. Hence a trusted script is the repo's own scripts/<name> (or
# factory/template/scripts/<name>) RESOLVED against the tracked cwd, and the scratch is never a cwd, a `cd` or
# `git -C` target, or a script source: every such directory is a literal path in a trusted checkout and not below
# its .lanes/. Trusted checkouts: ROOT, its main checkout when ROOT is a lane (MAIN, _lib.sh), and a lane worktree
# of either (.worktrees/<n>, .claude/worktrees/<n>): their scripts are the lead's or a writer lane's (T3 paths).

# ro_base ABS: true if ABS is in a trusted checkout; RO_REL is then the path below that checkout ('' at its root).
ro_base() {
    RO_REL=""
    for _r in "$ROOT" "$ROOT_P" "$MAIN" "$MAIN_P" "$MAIN_L"; do
        [ -n "$_r" ] || continue
        case $1 in
            "$_r") return 0 ;;
            "$_r"/.worktrees/?* | "$_r"/.claude/worktrees/?*) # <r>/.worktrees/<n>[/rest]: RO_REL is rest
                _x=${1#"$_r"/.worktrees/}
                [ "$_x" != "$1" ] || _x=${1#"$_r"/.claude/worktrees/}
                case $_x in */*) RO_REL=${_x#*/} ;; esac
                return 0 ;;
            "$_r"/?*) RO_REL=${1#"$_r"/}; return 0 ;;
        esac
    done
    return 1
}
# ro_dir RAW WHAT: RAW (a cwd, a cd target or a git -C target, relative to the tracked cwd) is a literal path in
# a trusted checkout and not below its .lanes/; sets RO_ABS.
ro_dir() {
    case $1 in *'$'* | *'`'*) ro_deny "$2 \`$1\` holds an expansion the guard cannot resolve" ;; esac
    RO_ABS=$(abspath "$1" "$cwd")
    ro_base "$RO_ABS" || ro_deny "$2 $RO_ABS is outside this checkout, its main checkout and their lane worktrees"
    case $RO_REL in .lanes | .lanes/*) ro_deny "$2 $RO_ABS is below .lanes/: the scratch and the reports hold the agent's own files (a Manifest, a gitdir, a script), so they are never a working directory, a git -C target or a script source" ;; esac
}
# ro_script RAW: RAW resolves to scripts/<name> or factory/template/scripts/<name> of a trusted checkout; sets RO_SCRIPT=<name>.
ro_script() {
    ro_dir "$1" "the script"
    RO_SCRIPT=""
    case $RO_REL in scripts/?* | factory/template/scripts/?*) RO_SCRIPT=${RO_REL#*scripts/} ;; esac
    [ -n "$RO_SCRIPT" ] || ro_deny "\`$1\` ($RO_ABS) is not a scripts/<name> of a trusted checkout: only the repo's own scripts/dod.jl, ci.jl, evidence.jl, gen.jl --check, test/runtests.jl, lane.jl audit and scripts/lane audit run"
}
