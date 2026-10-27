# shellcheck shell=sh
# shellcheck disable=SC2034,SC2154 # cwd is bash_guard.sh's; RO_CMDS is in _read_only_roots.sh; git_sub in _bash_guard_lib.sh
# _bash_guard_agents.sh: read-only agents (factory 0.4.0, spec D3, ADR-0016). Sourced by bash_guard.sh
# and write_guard.sh after _lib.sh (limits.env: READ_ONLY_AGENTS, rendered by gen.jl from every agent
# with default_mode = "read_only"). When the payload's agent_type is one of them, Bash may run only the
# allowlist below (ro_agent_check, one segment at a time, after the lead's rules) and Edit/Write may
# write only .lanes/reports/** and .lanes/scratch/<agent_type>/** (ro_agent_write_check). An empty
# agent_type (the lead) is unchanged. The check keys on the dispatch's agent type: see checks.toml.
AGENT=$(field '.agent_type')
RO_AGENT=""
if [ -n "$AGENT" ]; then
    [ -n "${READ_ONLY_AGENTS+set}" ] || deny "agent_type '$AGENT' cannot be checked: limits.env has no READ_ONLY_AGENTS line, so the guard cannot tell a read-only agent from a writer; it fails closed. Run \`julia scripts/gen.jl\`."
    case " $READ_ONLY_AGENTS " in *" $AGENT "*) RO_AGENT=1 ;; esac
fi
# Besides RO_CMDS (the read-only roots' list): tools that only print. sort is checked for -o; awk,
# sed, xargs, tee and the shells are out (their programs or arguments write or run commands).
RO_AGENT_CMDS=' echo printf true false test date diff cmp sort cut tr uniq basename dirname realpath which jq '
RO_AGENT_GIT=' log show diff status blame ls-files merge-base rev-parse '

ro_deny() {
    deny "agent_type '$AGENT' is read-only (ADR-0016 D3): $1. Its Bash allowlist, by subcommand, with no output redirection, no inline assignment and no --root: $RO_CMDS$RO_AGENT_CMDS(find without -delete/-exec/-ok/-fprint*/-fls; rg without --pre; sort without -o); git (no -c, --config-env, --exec-path, --git-dir, --work-tree or --output) with only${RO_AGENT_GIT}branch --show-current|--list, worktree list; julia scripts/dod.jl; julia scripts/ci.jl {test,guards,quality,docs}; julia scripts/evidence.jl latest, or <kind> -- <a command on this list>; julia scripts/test/runtests.jl; scripts/lane audit; cp/mkdir only into .lanes/scratch/$AGENT/. Write a report with the Write tool under .lanes/reports/."
}

# ro_agent_check WORD...: one segment (bash_guard.sh: assignments, redirections and wrappers still in place).
ro_agent_check() {
    for _a in "$@"; do
        case $_a in *'>'*) ro_deny "the output redirection \`$_a\` is refused (every target, even /dev/null; use 2>&1 and a pipe)" ;; esac
        case $_a in --root | --root=*) ro_deny "--root is refused" ;; esac
    done
    while [ $# -gt 0 ]; do # input redirections and the wrappers that run their command as given
        case $1 in
            '<') shift $(($# > 1 ? 2 : 1)) ;;
            '<'* | time | nice | env | command) shift ;;
            timeout) shift; case ${1:-} in -*) ro_deny "timeout options are not modelled; write \`timeout SECS cmd\`" ;; esac; shift ;;
            *=*) ro_deny "the inline assignment \`$1\` is refused (GIT_PAGER, GIT_EXTERNAL_DIFF, GIT_CONFIG_PARAMETERS would run a command)" ;;
            *) break ;;
        esac
    done
    [ $# -gt 0 ] || return 0
    _c=$1
    shift
    case $_c in ./scripts/lane | scripts/lane) _c=scripts/lane ;; */*) ro_deny "\`$_c\` names a program by path; only a command name on the allowlist runs" ;; esac
    case $_c in
        scripts/lane) [ "${1:-}" = audit ] || ro_deny "\`scripts/lane ${1:-}\` (only audit)" ;;
        julia) ro_agent_julia "$@" ;;
        git) ro_agent_git "$@" ;;
        cp | mkdir) ro_agent_scratch "$_c" "$@" ;;
        find) for _a in "$@"; do case $_a in -delete | -exec | -execdir | -ok | -okdir | -fprint* | -fls) ro_deny "\`find $_a\` deletes, writes or runs a command" ;; esac; done ;;
        rg) for _a in "$@"; do case $_a in --pre | --pre=*) ro_deny "\`rg --pre\` runs a command" ;; esac; done ;;
        sort) for _a in "$@"; do case $_a in -o* | --output*) ro_deny "\`sort $_a\` writes a file" ;; esac; done ;;
        *) case "$RO_CMDS$RO_AGENT_CMDS" in *" $_c "*) ;; *) ro_deny "\`$_c\` is not on the allowlist" ;; esac ;;
    esac
}
# ro_agent_julia ARGS...: julia [+channel] [safe options] <allowlisted script> <its allowed arguments>.
ro_agent_julia() {
    _s=""
    while [ $# -gt 0 ]; do
        case $1 in
            +* | --startup-file=* | --project | --project=* | --color=* | --threads=*) shift ;;
            -t) shift $(($# > 1 ? 2 : 1)) ;;
            -*) ro_deny "\`julia $1\` (no -e/-E/-L: only an allowlisted script runs)" ;;
            *) _s=$1; shift; break ;;
        esac
    done
    case $_s in ./scripts/*) _s=${_s#./} ;; esac
    case $_s in
        scripts/dod.jl | scripts/test/runtests.jl) ;;
        scripts/lane.jl) [ "${1:-}" = audit ] || ro_deny "\`scripts/lane.jl ${1:-}\` (only audit)" ;;
        scripts/ci.jl) case ${1:-} in test | guards | quality | docs) ;; *) ro_deny "\`scripts/ci.jl ${1:-}\` (only test, guards, quality, docs)" ;; esac ;;
        scripts/evidence.jl) # D8: the verifier records a gate run; the wrapped command passes this same check
            case ${1:-} in
                latest) ;;
                '' | -*) ro_deny "\`scripts/evidence.jl ${1:-}\` (latest, or <kind> -- <a command on this list>)" ;;
                *) [ "${2:-}" = -- ] || ro_deny "\`scripts/evidence.jl $1 ${2:-}\` (latest, or <kind> -- <a command on this list>)"; shift 2; ro_agent_check "$@" ;;
            esac ;;
        *) ro_deny "\`julia ${_s:-(no script)}\` (only scripts/dod.jl, scripts/ci.jl, scripts/evidence.jl, scripts/test/runtests.jl, scripts/lane.jl audit)" ;;
    esac
}
# ro_agent_git ARGS...: no option that sets config, a program path, another repo or an output file; read subcommands only.
ro_agent_git() {
    for _a in "$@"; do
        case $_a in -c | -c?* | --config-env* | --exec-path* | --git-dir* | --work-tree* | --output | --output=*) ro_deny "\`git $_a\` sets config, a program path, another repository or an output file" ;; esac
    done
    _s=$(git_sub "$@")
    case $RO_AGENT_GIT in *" $_s "*) return 0 ;; esac
    _n="" _ok=""
    for _a in "$@"; do
        if [ -z "$_n" ]; then [ "$_a" != "$_s" ] || _n=1; continue; fi
        case $_s:$_a in
            branch:--show-current | branch:--list) _ok=1 ;;
            branch:-*) ro_deny "\`git branch $_a\` (only --show-current, or --list [pattern])" ;;
            branch:*) [ -n "$_ok" ] || ro_deny "\`git branch $_a\` (only --show-current, or --list [pattern])" ;;
            worktree:*) [ -n "$_ok" ] || { [ "$_a" = list ] || ro_deny "\`git worktree $_a\` (only list)"; _ok=1; } ;;
        esac
    done
    [ -n "$_ok" ] || ro_deny "\`git ${_s:-}\` (only${RO_AGENT_GIT}branch --show-current|--list, worktree list)"
}
# ro_agent_scratch NAME ARGS...: every target of cp (its last operand) or mkdir (every operand) is below .lanes/scratch/<agent_type>/.
ro_agent_scratch() {
    _n=$1 _t=""
    shift
    for _a in "$@"; do
        case $_a in -t | --target-directory*) ro_deny "\`$_n $_a\` (name the target last)" ;; -*) ;; *) [ "$_n" = mkdir ] && _t="$_t $_a" || _t=$_a ;; esac
    done
    [ -n "$_t" ] || ro_deny "\`$_n\` without a target"
    for _a in $_t; do
        _x=$(abspath "$_a" "$cwd")
        case $_x in "$ROOT/.lanes/scratch/$AGENT" | "$ROOT/.lanes/scratch/$AGENT"/?* | "$ROOT_P/.lanes/scratch/$AGENT" | "$ROOT_P/.lanes/scratch/$AGENT"/?*) ;;
            *) ro_deny "\`$_n\` target $_x is not below .lanes/scratch/$AGENT/" ;; esac
    done
}
# ro_agent_write_check ABS: write_guard.sh; a read-only agent writes only its reports and its scratch.
ro_agent_write_check() {
    [ -n "$RO_AGENT" ] || return 0
    case $1 in "$ROOT"/.lanes/reports/?* | "$ROOT_P"/.lanes/reports/?* | "$ROOT/.lanes/scratch/$AGENT"/?* | "$ROOT_P/.lanes/scratch/$AGENT"/?*) return 0 ;; esac
    if in_main "$1"; then case $1 in "$IN_MAIN"/.lanes/reports/?*) return 0 ;; esac; fi
    deny "agent_type '$AGENT' is read-only (ADR-0016 D3): it may write only .lanes/reports/** and .lanes/scratch/$AGENT/**, not $1."
}
