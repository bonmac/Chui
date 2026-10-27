# shellcheck shell=sh
# shellcheck disable=SC2034,SC2154 # cwd is bash_guard.sh's; ROOT/MAIN* are _lib.sh's; ro_deny is in _bash_guard_agents.sh
# _bash_guard_agents_lib.sh: helpers of _bash_guard_agents.sh (factory 0.4.0 review rounds 1-2; ratchets.toml caps a
# hook at 150 lines). Sourced by bash_guard.sh after _bash_guard_agents.sh; costs no fork.
# 1. Where a read-only agent's command runs, and which script it runs (B2-B4). The agent writes only its scratch and
#    the reports, so a file there is the agent's own: a Manifest, a gitdir whose config runs a command (core.fsmonitor),
#    a scripts/dod.jl. Hence a trusted script is the repo's own scripts/<name> (or factory/template/scripts/<name>)
#    RESOLVED against the tracked cwd, and the scratch is never a cwd, a `cd` or `git -C` target, or a script source:
#    every such directory is a literal path in a trusted checkout and not below its .lanes/. Trusted checkouts: ROOT,
#    its main checkout when ROOT is a lane (MAIN, _lib.sh), and a lane worktree of either (.worktrees/<n>,
#    .claude/worktrees/<n>): their scripts are the lead's or a writer lane's (T3 paths).
# 2. The options a text tool may take (B1, N1-N3): a fixed short-option set per tool and no long option at all.
# 3. (round 4, A1, A5) cp and mkdir take a fixed option set too, and never a target that is or lies below a symlink;
#    the commands a read-only agent may run are its OWN list, not the reference roots' RO_CMDS (_read_only_roots.sh).

# RO_AGENT_CMDS: the plain commands a read-only agent may run (tools that only print; sort is checked for -o; awk, sed, xargs,
# tee and the shells are out). test_hooks_agents.jl pins this line; separate from RO_CMDS (A5), the reference roots' list.
RO_AGENT_CMDS=' cat head tail less grep rg find ls wc stat file cd pushd popd pwd echo printf true false test date diff cmp sort cut tr uniq basename dirname realpath which jq '

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
# ro_opts TOOL SHORT ARGSHORT LONG MAX ARGS...: ARGS hold only short options whose letters are in SHORT (' -n -k ' style; one
# cluster per word, as getopt reads it: a letter in ARGSHORT takes the rest of its word, or the next word), long options only
# from LONG (whole, or by the name before `=`; a separate argument is an operand; a tool that abbreviates long options gets none),
# `--` ending the options, at most MAX operands (a lone - is one; -1: any). Rounds 2-3: sort -ro/--out, file --comp, uniq - F, rg --hostname-bin.
ro_opts() {
    _t=$1 _ok=$2 _oa=$3 _ol=$4 _max=$5 _n=0 _need="" _end=""
    shift 5
    for _a in "$@"; do
        if [ -n "$_need" ]; then _need=""; continue; fi # the argument of the previous option
        if [ -n "$_end" ]; then _n=$((_n + 1)); continue; fi
        case $_a in
            -) _n=$((_n + 1)) ;;
            --) _end=1 ;;
            --*) case $_ol in *" $_a "* | *" ${_a%%=*} "*) ;; *) ro_deny "\`$_t $_a\`: a read-only agent's $_t takes only${_ol:- no long option} and${_ok:- no short option}" ;; esac ;;
            -?*)
                _r=${_a#-}
                while [ -n "$_r" ]; do
                    _ch=${_r%"${_r#?}"}
                    _r=${_r#?}
                    case $_ok in *" -$_ch "*) ;; *) ro_deny "\`$_t -$_ch\`: a read-only agent's $_t takes only${_ok:- no short option} and${_ol:- no long option}" ;; esac
                    case $_oa in *" -$_ch "*) [ -n "$_r" ] || _need=1; _r="" ;; esac
                done ;;
            *) _n=$((_n + 1)) ;;
        esac
    done
    [ "$_max" -lt 0 ] || [ "$_n" -le "$_max" ] || ro_deny "\`$_t\` takes at most $_max operand(s) for a read-only agent (a lone - is one: a second file is written)"
}
# ro_agent_scratch NAME ARGS...: cp takes only -R -r -p and mkdir only -p (one getopt cluster per word, `--` ends the
# options, no long option: round 4 A1, macOS `cp -s`/`-l` made a link under the scratch and a plain cp then wrote
# THROUGH it to the linked file outside); every target (cp: its last operand; mkdir: every operand) is below
# .lanes/scratch/<agent_type>/ and neither it nor any parent below the root is an existing symlink (ro_nolink).
ro_agent_scratch() {
    _n=$1 _end="" _rec="" _nop=0 _i=0
    shift
    case $_n in cp) _ok=' -R -r -p ' ;; *) _ok=' -p ' ;; esac
    for _a in "$@"; do # pass 1: options, expansions, the operand count
        # review M1, N1: an expansion or a glob in ANY operand is resolved by the shell, not by the guard (`dws/*` reached a link
        # the find never saw; `d/*` was a literal to ro_nolink), so none is allowed
        case $_a in *'$'* | *'`'* | *'*'* | *'?'* | *'['* | *'{'* | '~'*) ro_deny "\`$_n $_a\`: the word \`$_a\` holds an expansion or a glob (\$, \`, *, ?, [, {, a leading ~) the guard cannot resolve; write the path literally" ;; esac
        if [ -z "$_end" ]; then
            case $_a in
                --) _end=1; continue ;;
                -) ;;
                -*) _r=${_a#-}
                    while [ -n "$_r" ]; do
                        _ch=${_r%"${_r#?}"}
                        _r=${_r#?}
                        case $_ok in *" -$_ch "*) ;; *) ro_deny "\`$_n -$_ch\`: a read-only agent's $_n takes only$_ok(cp -s/-l make links, -a/-f/-n/-X and mkdir -m/-v change what is written; name the target last)" ;; esac
                        case $_ch in R | r) _rec=1 ;; esac
                    done
                    continue ;;
            esac
        fi
        _nop=$((_nop + 1))
    done
    [ "$_nop" -gt 0 ] || ro_deny "\`$_n\` without a target"
    _end=""
    for _a in "$@"; do # pass 2: each operand AS TYPED (review P1: a space-joined list re-split `sp ace` and the scan missed its link)
        if [ -z "$_end" ]; then case $_a in --) _end=1; continue ;; -) ;; -*) continue ;; esac; fi
        _i=$((_i + 1))
        if [ "$_n" = mkdir ] || [ "$_i" -eq "$_nop" ]; then ro_scratch_target "$_a"; elif [ -n "$_rec" ]; then ro_scratch_source "$_a"; fi
    done
}
# ro_scratch_target RAW: below .lanes/scratch/<agent_type>/, no `.`/`..` component (review B1: abspath folds `..` lexically, but the
# OS follows a symlink before it: `d/dl/../x`), and no existing symlink at or above it below the root (ro_nolink).
ro_scratch_target() {
    case "/$1/" in */./* | */../*) ro_deny "\`$_n\` target $1 has a . or .. component: a symlink before it is followed by the OS, not by the guard; name the scratch path directly" ;; esac
    _x=$(abspath "$1" "$cwd")
    case $_x in "$ROOT/.lanes/scratch/$AGENT" | "$ROOT/.lanes/scratch/$AGENT"/?* | "$ROOT_P/.lanes/scratch/$AGENT" | "$ROOT_P/.lanes/scratch/$AGENT"/?*) ;;
        *) ro_deny "\`$_n\` target $_x is not below .lanes/scratch/$AGENT/" ;; esac
    ro_nolink "$_x"
    ro_flat "$1" "${_x%/*}" # a new last component is fine: its parent is real and link-checked
}
# ro_flat RAW EXIST: the splitter (_bash_guard_lib.sh) flattens quoted whitespace and escapes to `_` (review P1: `"sp ace"` reached the
# guard as `sp_ace`, a name the symlink scan could not find), so an operand holding `_` is trusted only when EXIST is there as written.
ro_flat() {
    case $1 in *_*) [ -e "$2" ] || ro_deny "\`$_n $1\`: \`_\` may stand for a quoted space or an escape the guard flattens, and $2 does not exist as written; name an existing path without them" ;; esac
}
# ro_scratch_source RAW: a `cp -R` source holds no symlink (B1: cp -R copies it AS a link under the scratch, to be written through
# next). The scan is unbounded in depth (N2), so the cost cap is a depth cap, checked first.
ro_scratch_source() {
    case $1 in *_*) ro_deny "\`cp -R $1\`: a cp -R source may not hold \`_\` (the splitter flattens a quoted space or an escape to it, and a same-named directory could hide the tree scanned); copy a path without it" ;; esac
    _x=$(abspath "$1" "$cwd")
    [ -z "$(find "$_x" -mindepth 9 -print -quit 2>/dev/null)" ] || ro_deny "\`cp -R $1\`: the source tree is deeper than 8 levels; copy a smaller tree (the symlink scan is bounded by that depth)"
    _l=$(find "$_x" -type l 2>/dev/null | head -1)
    [ -z "$_l" ] || ro_deny "\`cp -R $1\`: the source tree holds a symlink ($_l), which cp -R would copy as a link under the scratch; copy without it"
}
# ro_nolink ABS: no component of ABS below the root (ABS itself, then each parent down to .lanes) is an existing symlink,
# so a cp or mkdir never writes through one; the root and what is above it are not checked (/tmp is a link on macOS).
ro_nolink() {
    _p=$1
    while [ -n "$_p" ]; do
        case $_p in "$ROOT" | "$ROOT_P" | /) return 0 ;; esac
        [ ! -L "$_p" ] || ro_deny "\`$_n\` target $1: $_p is a symlink, and a read-only agent's cp and mkdir never write through one"
        _p=${_p%/*}
    done
}
