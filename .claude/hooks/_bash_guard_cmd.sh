# shellcheck shell=sh
# shellcheck disable=SC2034,SC2154 # cwd and name are shared with bash_guard.sh; RO_GIT is in _bash_guard_lib.sh
# _bash_guard_cmd.sh: bash_guard.sh's check of ONE simple command (factory 0.2.3: ratchets.toml caps
# hooks at 150 lines). Sourced after _bash_guard_lib.sh and _read_only_roots.sh; costs no fork.

# check_cmd WORD...: skip assignments, leading redirections, shell keywords (if then else elif
# while until do ! { }) and wrappers with their options (env sudo doas nice time timeout <n> xargs
# caffeinate exec nohup builtin command eval), then check the command that runs: where it runs
# (read-only roots), rm -rf, and writes outside the root. `find -exec CMD ;` is checked as CMD.
check_cmd() {
    _w="" _w1="" envdir=""
    while [ $# -gt 0 ]; do
        if [ -n "$_w" ]; then # an option of wrapper $_w, and the argument it takes
            case "$_w $1" in
                'env -C' | 'env --chdir') envdir=${2:-}; shift $(($# > 1 ? 2 : 1)); continue ;;
                'env --chdir='*) envdir=${1#--chdir=}; shift; continue ;;
                'env -u' | 'env -S' | 'env -P' | sudo\ -[ugCDhprtUT] | doas\ -[uC] | 'nice -n' | timeout\ -[sk] | \
                    xargs\ -[InPLsEda] | caffeinate\ -[tw] | 'exec -a') shift $(($# > 1 ? 2 : 1)); continue ;;
                *' -'?*) shift; continue ;;
            esac
            [ "$_w" != timeout ] || { _w=""; shift; continue; } # its DURATION
        fi
        case $1 in
            *'>' | '<') shift $(($# > 1 ? 2 : 1)); continue ;; # a redirection operator and its target
            *=* | *'>'* | '<'*) shift; continue ;;              # an assignment, a redirection
        esac
        case ${1##*/} in
            if | then | else | elif | while | until | do | '!' | '{' | '}') _w=""; shift ;;
            env | sudo | doas | nice | time | timeout | xargs | caffeinate | exec | nohup | builtin | command) _w=${1##*/} _w1=${_w1:-${1##*/}}; shift ;;
            *) break ;;
        esac
    done
    [ $# -gt 0 ] || return 0
    case $1 in *'$'* | *'`'*) deny "a command name built from an expansion is blocked ($1): the guard cannot see what runs. Write the command name literally." ;; esac
    name=${1##*/}
    shift
    # where this command runs: the tracked cwd, or the directory a -C style flag names
    rundir=$cwd
    [ -z "$envdir" ] || rundir=$(abspath "$envdir" "$cwd")
    case $name in
        cd | pushd)
            while [ $# -gt 0 ]; do case $1 in --) shift; break ;; -[LPe@]*) shift ;; *) break ;; esac; done
            _nd=$(newdir "${1:-}")
            [ -z "$_nd" ] || cwd=$_nd
            rundir=$cwd
            ;;
        git)
            _gd=""
            case " $* " in *" -C "* | *" --git-dir"* | *" --work-tree"*) _gd=$(git_dir "$@") ;; esac # no subshell without them
            [ -z "$_gd" ] || rundir=$(abspath "$_gd" "$cwd")
            ;;
        make | gmake | uv | uvx)
            _p=""
            for tok in "$@"; do
                if [ -n "$_p" ]; then rundir=$(abspath "$tok" "$cwd"); _p=""; continue; fi
                case $name:$tok in
                    make:-C | gmake:-C | *make:--directory | uv*:--directory | uv*:--project) _p=1 ;;
                    *make:--directory=* | uv*:--directory=* | uv*:--project=*) rundir=$(abspath "${tok#*=}" "$cwd") ;;
                    *make:-C?*) rundir=$(abspath "${tok#-C}" "$cwd") ;;
                esac
            done
            ;;
        julia)
            for tok in "$@"; do
                case $tok in --project=@*) ;; --project=*) rundir=$(abspath "${tok#--project=}" "$cwd") ;; esac
            done
            ;;
    esac
    [ -z "$_w1" ] || read_only_check "$_w1" "$rundir" # a wrapper (xargs, sudo, ...) does not run in a read-only root either
    read_only_check "$name" "$rundir" "$@"
    _e=""
    case $name in
        rm) rm_check "$@" ;;
        eval) deny "eval is blocked: its string is not inspected. Run the command directly." ;;
        rmdir | mkdir | touch | chmod | chown | truncate | tee | mv)
            for tok in "$@"; do outside "$tok"; done
            ;;
        cp | ln | install | rsync)
            last=""
            for tok in "$@"; do last=$tok; done
            outside "$last"
            [ "$name" = rsync ] || optw " -t --target-directory " "$@"
            ;;
        dd) for tok in "$@"; do case $tok in of=*) outside "${tok#of=}" ;; esac; done ;;
        sed | perl) # in place (sed -i, -i.bak, --in-place; perl -i, -pi): every file argument is written
            _i=""
            for tok in "$@"; do case $name:$tok in sed:-i* | sed:--in-place* | perl:-i* | perl:-[pnla0]*i*) _i=1 ;; esac; done
            [ -z "$_i" ] || {
                _p="" _s=""
                for tok in "$@"; do
                    if [ -n "$_p" ]; then _p=""; continue; fi
                    case $name:$tok in
                        *:-e | *:-f | sed:--expression | sed:--file | perl:-E) _p=1; _s=1 ;;
                        *:-e?* | *:-f?* | sed:--expression=* | sed:--file=*) _s=1 ;;
                        *:-*) ;;
                        *) if [ -n "$_s" ]; then outside "$tok"; else _s=1; fi ;; # the first is the script
                    esac
                done
            }
            ;;
        curl) optw " -o --output --output-dir " "$@" ;;
        wget) optw " -O --output-document -o --output-file -a --append-output -P --directory-prefix " "$@" ;;
        tar) case ${1:-} in --extract | --get | -x* | -[!-]*x* | x* | [!-]*x*) optw " -C --directory " "$@" ;; esac ;;
        unzip) optw " -d " "$@" ;;
        find) # -delete removes below its start paths; -fprint/-fls write a file; -exec runs a command
            optw " -fprint -fprint0 -fprintf -fls " "$@"
            case " $* " in *" -delete "*)
                for tok in "$@"; do case $tok in -[HLP]) ;; -* | '!' | _) break ;; *) outside "$tok" ;; esac; done ;;
            esac
            _in=""
            for tok in "$@"; do
                case $tok in
                    -exec | -execdir | -ok | -okdir) _in=1; _e="$_e
" ;;
                    _ | ';' | '+') _in="" ;;
                    *) [ -z "$_in" ] || _e="$_e $tok" ;;
                esac
            done
            ;;
        git)
            if [ -n "$_gd" ]; then
                dir=$(abspath "$_gd" "$cwd")
                _s=$(git_sub "$@")
                case $RO_GIT in *" $_s "*) ;; *) allowed "$dir" || deny "git -C/--git-dir/--work-tree $dir $_s: mutating git outside the repo root is blocked." ;; esac
            fi
            case " $* " in *" init "* | *" clone "* | *" worktree "*) _s=$(git_sub "$@") ;; *) _s="" ;; esac
            case $_s in init | clone | worktree) # the directory they create (clone: its 2nd operand)
                _np=0 _l="" _seen=""
                for tok in "$@"; do
                    if [ -z "$_seen" ]; then [ "$tok" != "$_s" ] || _seen=1; continue; fi
                    case $tok in -* | add) continue ;; esac
                    _np=$((_np + 1)) _l=$tok
                    [ "$_s" = clone ] || outside "$tok"
                done
                [ "$_s" != clone ] || [ "$_np" -lt 2 ] || outside "$_l"
                ;;
            esac
            ;;
    esac
    [ -n "$_e" ] || return 0
    _ifs=$IFS
    IFS='
'
    for _x in $_e; do # each `find -exec` command, checked as a command of its own
        IFS=$_ifs
        # shellcheck disable=SC2086
        check_cmd $_x
    done
    IFS=$_ifs
}
