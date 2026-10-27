# shellcheck shell=sh
# shellcheck disable=SC2034,SC2154 # cwd is bash_guard.sh's; RO_AGENT_CMDS/ro_* are in _bash_guard_agents_lib.sh; git_sub/git_dir/newdir in _bash_guard_lib.sh
# _bash_guard_agents.sh: read-only agents (factory 0.4.0, spec D3, ADR-0016). Sourced by bash_guard.sh
# and write_guard.sh after _lib.sh (limits.env: READ_ONLY_AGENTS, rendered by gen.jl from every agent
# with default_mode = "read_only"). When the payload's agent_type is one of them, Bash may run only the
# allowlist below (ro_agent_check, one segment at a time, after the lead's rules) and Edit/Write may
# write only .lanes/reports/** and .lanes/scratch/<agent_type>/** (ro_agent_write_check). An empty
# agent_type (the lead) is unchanged. The check keys on the dispatch's agent type: see checks.toml.
# Review rounds 1-4, helpers in _bash_guard_agents_lib.sh: text tools, cp and mkdir take a fixed option set each (ro_opts,
# ro_agent_scratch: uniq IN OUT, sort -o, rg --hostname-bin, cp -s wrote or ran); the scratch holds the agent's OWN files, so a
# cwd, cd or git -C target and a script resolve to a trusted checkout, never below .lanes/ (ro_dir, ro_script); julia loads nothing.
AGENT=$(field '.agent_type')
RO_AGENT=""
if [ -n "$AGENT" ]; then
    [ -n "${READ_ONLY_AGENTS+set}" ] || deny "agent_type '$AGENT' cannot be checked: limits.env has no READ_ONLY_AGENTS line, so the guard cannot tell a read-only agent from a writer; it fails closed. Run \`julia scripts/gen.jl\`."
    case " $READ_ONLY_AGENTS " in *" $AGENT "*) RO_AGENT=1 ;; esac
fi
RO_AGENT_GIT=' log show diff status blame ls-files merge-base rev-parse '
RO_NOCD="" # set while checking the command evidence.jl wraps: a cd there would move the gate run (m2)

ro_deny() {
    deny "agent_type '$AGENT' is read-only (ADR-0016 D3): $1. Its Bash allowlist, by subcommand, with no output redirection, no inline assignment, no --root, and every cwd, cd or git -C target and script a literal path in this checkout, its main checkout or a lane worktree of either, never below .lanes/: $RO_AGENT_CMDS(find without -delete/-exec/-ok/-fprint*/-fls; rg, sort, uniq, file and less with a fixed option set each, uniq with one operand, less without +cmd); git (no -c, --config-env, --exec-path, --git-dir, --work-tree or --output) with only${RO_AGENT_GIT}branch --show-current|--list, worktree list; julia [+channel] [--startup-file=no] with the repo's own scripts/dod.jl; scripts/ci.jl {test,guards,quality,docs}; scripts/evidence.jl latest, or <kind> -- <a command on this list>; scripts/test/runtests.jl; scripts/gen.jl --check; scripts/tdd.jl audit; scripts/lane audit <lane> [--base B] [--owns GLOBS] [--reported FILE] (no --report, no --repo); cp (-R -r -p) and mkdir (-p) only into .lanes/scratch/$AGENT/, never through a symlink. Write a report with the Write tool under .lanes/reports/."
}

# ro_lane_audit NAME ARGS...: `audit <lane>` [--base B] [--owns GLOBS] [--reported FILE: a literal path in a trusted checkout, only
# read]. Never --report (final review m3: it appends a self-certified `verdict`), --repo (critic round 3 B1: lane.jl runs git -C
# there, and a scratch gitdir's core.fsmonitor ran) or any other option; no value that starts with -.
ro_lane_audit() {
    [ "${2:-}" = audit ] || ro_deny "\`$1 ${2:-}\` (only audit)"; _n=$1 _ln=""; shift 2
    while [ $# -gt 0 ]; do
        case $1:${2:-} in
            --report:* | --report=*) ro_deny "\`$_n audit $1\` records a verdict in the ledger (a write); the lead runs it" ;;
            --base: | --owns: | --reported: | --base:-* | --owns:-* | --reported:-*) ro_deny "\`$_n audit $1\` needs a value that is not an option" ;;
            --reported:*'$'* | --reported:*'`'* | '--reported:~'*) ro_deny "\`$_n audit --reported $2\` holds an expansion the guard cannot resolve" ;;
            --reported:*) ro_base "$(abspath "$2" "$cwd")" || ro_deny "\`$_n audit --reported $2\` is outside this checkout, its main checkout and their lane worktrees"; shift ;;
            --base:* | --owns:*) shift ;;
            -*) ro_deny "\`$_n audit $1\`: a read-only agent's lane audit takes only <lane> [--base B] [--owns GLOBS] [--reported FILE] (never --repo: lane.jl runs git there)" ;;
            *) [ -z "$_ln" ] || ro_deny "\`$_n audit $_ln $1\` (one lane name)"; _ln=$1 ;;
        esac
        shift
    done
    [ -n "$_ln" ] || ro_deny "\`$_n audit\` without a lane name"
}

# ro_agent_check WORD...: one segment (bash_guard.sh: assignments, redirections and wrappers still in place).
ro_agent_check() {
    ro_dir "$cwd" "the working directory" # the payload's cwd, or the last cd's target (check_cmd tracks it)
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
    case $_c in */*) ro_script "$_c"; [ "$RO_SCRIPT" = lane ] || ro_deny "\`$_c\` names a program by path; only a command name on the allowlist, or the repo's own scripts/lane, runs"; _c=scripts/lane ;; esac
    case $_c in
        scripts/lane) ro_lane_audit scripts/lane "$@" ;;
        julia) ro_agent_julia "$@" ;;
        git) ro_agent_git "$@" ;;
        cp | mkdir) ro_agent_scratch "$_c" "$@" ;;
        cd | pushd) # the target as check_cmd will track it; one the guard cannot resolve is refused, so the tracked cwd is never wrong
            [ -z "$RO_NOCD" ] || ro_deny "\`scripts/evidence.jl <kind> -- $_c\` (the wrapped command is a command on this list, not a cd)"
            while [ $# -gt 0 ]; do case $1 in --) shift; break ;; -[LPe@]*) shift ;; *) break ;; esac; done
            _nd=$(newdir "${1:-}")
            [ -n "$_nd" ] || ro_deny "\`$_c ${1:-}\` goes where the guard cannot resolve (an expansion, or cd -)"
            ro_dir "$_nd" "cd into" ;;
        find) for _a in "$@"; do case $_a in -delete | -exec | -execdir | -ok | -okdir | -fprint* | -fls) ro_deny "\`find $_a\` deletes, writes or runs a command" ;; esac; done ;;
        rg) ro_opts rg ' -n -i -w -l -c -e -g -t -F -S -A -B -C -H -h -N -v ' ' -e -g -t -A -B -C ' ' --no-heading --color=never --glob --type --files --line-number --count --fixed-strings --smart-case --ignore-case --word-regexp --files-with-matches --max-count --context --no-messages ' -1 "$@" ;; # not --pre/--hostname-bin (run a program); rg rejects abbreviations
        sort) ro_opts sort ' -n -r -u -b -f -s -k -t ' ' -k -t ' '' -1 "$@" ;; # not -o/-T/--output/--compress-program (write, run)
        uniq) ro_opts uniq ' -c -d -u -i ' '' '' 1 "$@" ;;                    # a second operand (a lone - too) is written
        file) ro_opts file ' -b -i -h ' '' '' -1 "$@" ;;                      # not -C/--compile (writes a magic file)
        less) for _a in "$@"; do case $_a in +*) ro_deny "\`less $_a\` runs a less command" ;; esac; done; ro_opts less '' '' '' -1 "$@" ;; # not -o/-O/--log-file (writes a log)
        *) case $RO_AGENT_CMDS in *" $_c "*) ;; *) ro_deny "\`$_c\` is not on the allowlist" ;; esac ;;
    esac
}
# ro_agent_julia ARGS...: julia [+channel] [--startup-file=no] <the repo's own allowlisted script> <its allowed arguments>.
# B3: any other option is refused: --project (a scratch Manifest shadows the stdlib), -e/-E/-L/--load, -J/--sysimage.
ro_agent_julia() {
    _s=""
    while [ $# -gt 0 ]; do
        case $1 in
            +* | --startup-file=no) shift ;;
            -*) ro_deny "\`julia $1\`: only --startup-file=no and a juliaup +channel may precede the script (no --project: a scratch Manifest would shadow the stdlib; no -e/-E/-L/--load, -J/--sysimage, -t/--threads, --color)" ;;
            *) _s=$1; shift; break ;;
        esac
    done
    [ -n "$_s" ] || ro_deny "\`julia\` without a script (only an allowlisted script runs)"
    ro_script "$_s" # sets RO_SCRIPT: the name below the trusted checkout's scripts/ (B2)
    case $RO_SCRIPT in
        dod.jl | test/runtests.jl) ;;
        gen.jl) [ "$*" = --check ] || ro_deny "\`scripts/gen.jl $*\` (only --check: without it gen.jl writes the generated files)" ;;
        lane.jl) ro_lane_audit scripts/lane.jl "$@" ;;
        tdd.jl) [ "${1:-}" = audit ] || ro_deny "\`scripts/tdd.jl ${1:-}\` (only audit, the reviewer's test-first check: red, green and brief write evidence or briefs, mutate a worktree)" ;;
        ci.jl) case ${1:-} in test | guards | quality | docs) ;; *) ro_deny "\`scripts/ci.jl ${1:-}\` (only test, guards, quality, docs)" ;; esac ;;
        evidence.jl) # D8: the verifier records a gate run; the wrapped command passes this same check, and is not a cd (m2)
            case ${1:-} in
                latest) ;;
                '' | -*) ro_deny "\`scripts/evidence.jl ${1:-}\` (latest, or <kind> -- <a command on this list>)" ;;
                *) [ "${2:-}" = -- ] || ro_deny "\`scripts/evidence.jl $1 ${2:-}\` (latest, or <kind> -- <a command on this list>)"; shift 2; RO_NOCD=1; ro_agent_check "$@"; RO_NOCD="" ;;
            esac ;;
        *) ro_deny "\`julia scripts/$RO_SCRIPT\` (only scripts/dod.jl, scripts/ci.jl, scripts/evidence.jl, scripts/test/runtests.jl, scripts/gen.jl --check, scripts/tdd.jl audit, scripts/lane.jl audit)" ;;
    esac
}
# ro_agent_git ARGS...: no option that sets config, a program path, another repo or an output file; -C only into a
# trusted checkout (B4: a scratch gitdir's core.fsmonitor would run); read subcommands only.
ro_agent_git() {
    for _a in "$@"; do
        case $_a in -c | -c?* | --config-env* | --exec-path* | --git-dir* | --work-tree* | --output | --output=*) ro_deny "\`git $_a\` sets config, a program path, another repository or an output file" ;; esac
    done
    case " $* " in *" -C "*) ro_dir "$(git_dir "$@")" "git -C" ;; esac
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
# ro_agent_scratch (cp/mkdir into the scratch) is in _bash_guard_agents_lib.sh (round 4, A1).
# ro_agent_write_check ABS: write_guard.sh; a read-only agent writes only its reports and its scratch.
ro_agent_write_check() {
    [ -n "$RO_AGENT" ] || return 0
    case $1 in "$ROOT"/.lanes/reports/?* | "$ROOT_P"/.lanes/reports/?* | "$ROOT/.lanes/scratch/$AGENT"/?* | "$ROOT_P/.lanes/scratch/$AGENT"/?*)
        # review P1: the prefix match is lexical, so the RAW path ($fp, write_guard.sh) takes no `.`/`..` component or expansion,
        # and no existing symlink sits at or above the path below the root (ro_nolink, _bash_guard_agents_lib.sh)
        _n=Write
        case "/$fp/" in */./* | */../*) ro_deny "the write target $fp has a . or .. component: a symlink before it is followed by the OS, not by the guard" ;; esac
        case $fp in *'$'* | *'`'*) ro_deny "the write target $fp holds an expansion the guard cannot resolve" ;; esac
        case "/$1/" in */.[Gg][Ii][Tt]/*) ro_deny "the write target $1 has a .git component (any case: APFS folds it, and git reads it as a gitdir)" ;; esac
        ro_nolink "$1"
        return 0 ;;
    esac
    if in_main "$1"; then case $1 in "$IN_MAIN"/.lanes/reports/?*) return 0 ;; esac; fi
    deny "agent_type '$AGENT' is read-only (ADR-0016 D3): it may write only .lanes/reports/** and .lanes/scratch/$AGENT/**, not $1."
}
