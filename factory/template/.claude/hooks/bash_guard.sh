#!/bin/sh
# bash_guard.sh: PreToolUse(Bash). Blocks a short denylist, writes outside the repo root, and
# any command that RUNS inside a read-only root (.agents/factory.toml [bash_guard]) unless
# it is a read-only command. `cd`/`pushd` are tracked across `&&`, `;`, `|` segments.
# A speed bump, not a sandbox: blind spots are listed in docs/CHECK_COVERAGE.md.
# Exit 2 = blocked (stderr goes to Claude). Overrides are read from the SESSION env only
# (an inline `FACTORY_ALLOW_PUSH=1 git push` does not reach this hook):
#   FACTORY_ALLOW_PUSH=1     allow `git push` (not --force) once the user approved pushing
#   FACTORY_ALLOW_OUTWARD=1  allow gh actions that create or change things on GitHub
d=$(dirname -- "$0")
for _l in _lib.sh _bash_guard_lib.sh _read_only_roots.sh; do # a missing library must block (exit 2), not fail open
    [ -f "$d/$_l" ] || { printf '[factory] %s is missing; bash_guard fails closed. Restore it (julia scripts/sync_factory.jl).\n' "$d/$_l" >&2; exit 2; }
done
. "$d/_lib.sh"
. "$d/_bash_guard_lib.sh"
. "$d/_read_only_roots.sh"
need_jq
raw=$(field '.tool_input.command')
[ -n "$raw" ] || exit 0
cwd=$(field '.cwd')
cwd=${cwd:-$ROOT}

# Heredoc bodies are data, not commands: drop the lines between <<WORD and WORD.
cmd=$(printf '%s\n' "$raw" | awk '
    end != "" { t = $0; sub(/^\t+/, "", t); if (t == end) { end = ""; print } ; next }
    { print; if (match($0, /<<-?[ \t]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/)) {
        w = substr($0, RSTART, RLENGTH); sub(/^<<-?[ \t]*["'"'"']?/, "", w); end = w } }')
# Quoted strings are arguments (commit messages, patterns): blank them for the denylist.
bare=$(printf '%s\n' "$cmd" | sed -e "s/'[^']*'/Q/g" -e 's/"[^"]*"/Q/g')

has() { printf '%s\n' "$bare" | grep -Eq -- "$1"; }
S='(^|[;&|(`[:space:]])'                          # start of a command word
G="${S}git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|-[[:alpha:]]|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+" # git + global options

has "${G}reset[[:space:]]+--hard" && deny "git reset --hard is blocked: it discards work. Use a WIP commit or ask."
has "${G}clean[[:space:]]+-[[:alnum:]]*f" && deny "git clean -f is blocked: it deletes untracked files."
has "${G}add[[:space:]]+(-A|--all|\.|:/)([[:space:]]|$)" &&
    deny "git add -A/./:/ is blocked: stage named paths so nothing stray is committed."
if has "${G}stash([[:space:]]|$)"; then
    has "${G}stash[[:space:]]+(list|show|apply)([[:space:]]|$)" ||
        has "${G}stash[[:space:]]+push[[:space:]].*(-m|--message)" ||
        deny "only 'git stash push -m <tag>', 'git stash apply <sha>', list and show are allowed: the stash stack is shared by all worktrees. Prefer a WIP commit; ask the lead to drop entries."
fi
has "${G}[a-z-]+[[:space:]].*--no-verify" && deny "--no-verify is blocked: fix the failing hook instead."
has "${S}(pkill|killall)[[:space:]]" && deny "pkill/killall are blocked: kill a named PID you started."
if has "${G}push([[:space:]]|$)"; then
    has "--force([^-]|$)|[[:space:]]-f([[:space:]]|$)" && deny "git push --force is blocked; use --force-with-lease, with the user's approval."
    [ "${FACTORY_ALLOW_PUSH:-}" = 1 ] || deny "git push needs the user's confirmation (ECOSYSTEM.md §1.6). The user sets FACTORY_ALLOW_PUSH=1 for the session once approved."
fi
GH="${S}gh[[:space:]]+"
if has "${GH}(repo[[:space:]]+(create|delete|edit|rename|archive|fork)|release[[:space:]]+(create|delete|edit|upload)|issue[[:space:]]+(create|comment|close|edit|reopen|delete)|pr[[:space:]]+(create|merge|comment|close|edit|review|ready|reopen)|workflow[[:space:]]+(run|enable|disable)|run[[:space:]]+(rerun|cancel|delete)|(secret|variable)[[:space:]]+(set|delete)|label[[:space:]]+(create|edit|delete))" ||
    has "${GH}api[[:space:]].*(-X[[:space:]]*|--method[[:space:]=]*)(POST|PATCH|PUT|DELETE)" ||
    has "${GH}api[[:space:]].*[[:space:]](-[fF]|--field|--raw-field|--input)([[:space:]=]|$)"; then
    [ "${FACTORY_ALLOW_OUTWARD:-}" = 1 ] || deny "This gh command acts on GitHub and needs the user's confirmation (ECOSYSTEM.md §1.6)."
fi

# --- per command: rm -rf, writes outside the repo root, read-only roots ------------
set -f
printf '%s\n' "$cmd" | segments | {
    while IFS= read -r seg; do
        # shellcheck disable=SC2086
        set -- $seg
        prev=""
        for tok in "$@"; do # redirection targets: >f, >>f, 2>f, &>f, or `> f` (not `->`)
            case $prev in *'->') ;; *'>') outside "$tok" ;; esac
            case $tok in *'->'*) ;; *'>'?*) outside "${tok##*>}" ;; esac
            prev=$tok
        done
        envdir=""
        while [ $# -gt 0 ]; do # skip env assignments, wrappers (and env's options) and leading redirections
            case $1 in
                -C | --chdir) [ -n "$inenv" ] && envdir=${2:-} && shift 2 && continue; break ;;
                --chdir=*) [ -n "$inenv" ] || break; envdir=${1#--chdir=}; shift; continue ;;
                -u) [ -n "$inenv" ] || break; shift 2; continue ;;
                -*) [ -n "$inenv" ] || break; shift; continue ;;
            esac
            case $1 in env) inenv=1; shift ;; sudo | command | nice | time | *=* | *'>'*) shift ;; *) break ;; esac
        done
        inenv=""
        [ $# -gt 0 ] || continue
        name=${1##*/}
        shift
        # where this command runs: the tracked cwd, or the directory a -C style flag names
        rundir=$cwd
        [ -z "$envdir" ] || rundir=$(abspath "$(unquote "$envdir")" "$cwd")
        case $name in
            cd | pushd)
                while [ $# -gt 0 ]; do case $1 in --) shift; break ;; -[LPe@]*) shift ;; *) break ;; esac; done
                _nd=$(newdir "${1:-}")
                [ -z "$_nd" ] || cwd=$_nd
                rundir=$cwd
                ;;
            git)
                _gd=""
                case " $* " in *" -C "*) _gd=$(git_dir "$@") ;; esac # skip the subshell when there is no -C
                [ -z "$_gd" ] || rundir=$(abspath "$(unquote "$_gd")" "$cwd")
                ;;
            make | gmake)
                _p=""
                for tok in "$@"; do
                    if [ -n "$_p" ]; then rundir=$(abspath "$(unquote "$tok")" "$cwd"); _p=""; continue; fi
                    case $tok in -C | --directory) _p=1 ;; --directory=*) rundir=$(abspath "$(unquote "${tok#--directory=}")" "$cwd") ;; -C?*) rundir=$(abspath "$(unquote "${tok#-C}")" "$cwd") ;; esac
                done
                ;;
            uv | uvx)
                _p=""
                for tok in "$@"; do
                    if [ -n "$_p" ]; then rundir=$(abspath "$(unquote "$tok")" "$cwd"); _p=""; continue; fi
                    case $tok in --directory | --project) _p=1 ;; --directory=* | --project=*) rundir=$(abspath "$(unquote "${tok#*=}")" "$cwd") ;; esac
                done
                ;;
            julia)
                for tok in "$@"; do
                    case $tok in --project=*) _pp=$(unquote "${tok#--project=}"); case $_pp in @*) ;; *) rundir=$(abspath "$_pp" "$cwd") ;; esac ;; esac
                done
                ;;
        esac
        read_only_check "$name" "$rundir" "$@"
        case $name in
            rm) rm_check "$@" ;;
            rmdir | mkdir | touch | chmod | chown | truncate | tee | mv)
                for tok in "$@"; do outside "$tok"; done
                ;;
            cp | ln | install | rsync)
                last=""
                for tok in "$@"; do last=$tok; done
                outside "$last"
                ;;
            dd) for tok in "$@"; do case $tok in of=*) outside "${tok#of=}" ;; esac; done ;;
            git)
                if [ -n "$_gd" ]; then
                    dir=$(abspath "$(unquote "$_gd")" "$cwd")
                    _s=$(git_sub "$@")
                    case $RO_GIT in *" $_s "*) ;; *) allowed "$dir" || deny "git -C $dir $_s: mutating git outside the repo root is blocked." ;; esac
                fi
                ;;
        esac
    done
}
status=$?
set +f
exit $status
