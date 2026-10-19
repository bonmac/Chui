# shellcheck shell=sh
# shellcheck disable=SC2034,SC2154 # RO_GIT is read, and `cwd`/`raw` are set, by bash_guard.sh
# _bash_guard_lib.sh: command splitting and path helpers only bash_guard.sh needs (split out in
# factory 0.2.2: ratchets.toml caps hooks at 150 lines). Sourced after _lib.sh; costs no fork.

# segments (stdin -> stdout): one simple command per line, in one awk (no sed/tr forks).
# Text inside '...', "..." and $'...' (and a backslashed character) is ONE argument: its blanks
# and ; & | ( ) < > become _, so a quoted sed expression or commit message is not a redirect or
# a second command. A "$(...)" or `...` inside double quotes still runs, so it is split like
# unquoted text. A `#` that starts a word ends the line (a comment: its apostrophes are not
# quotes). Then 2>&1-style duplications go, &> and >& become >, and ; & | ( ) split.
segments() {
    awk -v SQ="'" 'BEGIN { q = ""; sp = " \t;&|()<>"; b = ""; k = 0 }
    function out() { gsub(/[0-9]*>&([0-9]+|-)/, "", b); gsub(/&>|>&/, ">", b); gsub(/[;&|()]/, "\n", b); print b; b = "" }
    { n = length($0)
      for (i = 1; i <= n; i++) { c = substr($0, i, 1); d = substr($0, i + 1, 1)
        if (q == "") { # unquoted: top level, or inside a "$(...)" / "`...`" (t[k] = depth or `)
          if (c == "\\") { b = b (index(sp "\"#`$" SQ, d) ? "_" : c d); i++ }
          else if (c == "#" && (i == 1 || index(" \t;&|(", substr($0, i - 1, 1)))) i = n
          else if (c == "$" && d == SQ) { q = "A"; b = b c d; i++ }
          else if (c == "\"" || c == SQ) { q = c; b = b c }
          else if (k && t[k] == "`" && c == "`") { k--; q = "\""; b = b ";" }
          else if (k && t[k] != "`" && (c == "(" || c == ")")) {
            t[k] += (c == "(" ? 1 : -1); b = b c; if (t[k] == 0) { k--; q = "\"" } }
          else b = b c }
        else if (c == "\\" && q != SQ) { b = b "__"; i++ }
        else if ((c == SQ && q != "\"") || (c == "\"" && q == "\"")) { q = ""; b = b c }
        else if (q == "\"" && (c == "`" || (c == "$" && d == "("))) {
          q = ""; k++; if (c == "`") { t[k] = "`"; b = b ";" } else { t[k] = 1; b = b "$("; i++ } }
        else b = b (index(sp, c) ? "_" : c) }
      if (q != "") b = b "_"; else if (k) b = b ";"; else out() }
    END { if (b != "") out() }'
}

outside() { # outside TOKEN: deny if TOKEN names a path outside the root and scratch dirs
    _t=${1#[\"\']} && _t=${_t%[\"\']} # no $(unquote): a fork per token
    case $_t in '' | -* | '&'*) return 0 ;; esac
    _a=$(abspath "$_t" "$cwd")
    allowed "$_a" || deny "write outside the repo root blocked: $_a (root: $ROOT). Lanes write only inside their repo; use the scratchpad or \$TMPDIR for temp files."
}

# scratch ABS: true if ABS is strictly below $TMPDIR, or at least three levels below this
# user's Claude Code scratch root /private/tmp/claude-<uid>/<project>/<session>/..., where
# `rm -rf` is allowed; never the repo root, never a glob in <project> or <session>.
scratch() {
    case $1 in "$ROOT" | "$ROOT"/* | "$ROOT_P" | "$ROOT_P"/*) return 1 ;; esac
    case $1 in
        /private/tmp/claude-*/*/*/?* | /tmp/claude-*/*/*/?*)
            _s=${1#/*tmp/claude-}
            case $_s in "$(id -u)"/*) ;; *) return 1 ;; esac
            _s=${_s#*/}
            _p=${_s%%/*} && _s=${_s#*/}
            case "$_p/${_s%%/*}" in *[*?[]*) return 1 ;; esac
            return 0
            ;;
    esac
    _td=${TMPDIR%/}
    [ -n "$_td" ] || return 1
    case $1 in "$_td"/?* | /private"$_td"/?*) return 0 ;; esac
    return 1
}

# rm_check ARGS...: `rm -rf` only on ABSOLUTE scratch targets (or $TMPDIR/..., unless the command
# assigns TMPDIR); a relative target is never trusted, since the tracked cwd can be wrong
# (bare `cd`, `cd -`, subshells, popd). Every target must be inside the root or scratch.
rm_check() {
    _r="" _f="" _n=0 _ok=1
    for _t in "$@"; do
        case $_t in
            --recursive) _r=1 ;; --force) _f=1 ;; --*) ;;
            -*) case $_t in *[rR]*) _r=1 ;; esac; case $_t in *f*) _f=1 ;; esac ;;
            *)
                _n=$((_n + 1))
                _u=$(unquote "$_t")
                case $_u in '$TMPDIR'/* | '${TMPDIR}'/* | '$TMPDIR"/'* | '${TMPDIR}"/'*)
                    case $raw in *TMPDIR=*) _ok="" ;; *) _u="${TMPDIR%/}/${_u#*/}" ;; esac ;;
                esac
                case $_u in *'$'* | *'`'*) _ok="" ;; /*) scratch "$(abspath "$_u")" || _ok="" ;; *) _ok="" ;; esac
                ;;
        esac
    done
    if [ -n "$_r" ] && [ -n "$_f" ] && { [ "$_n" -eq 0 ] || [ -z "$_ok" ]; }; then
        deny "rm -rf is blocked except on absolute paths below \$TMPDIR or your session scratchpad (/private/tmp/claude-<uid>/<project>/<session>/). Remove named paths with \`rm -r <path>\`, or ask the lead."
    fi
    for _t in "$@"; do outside "$_t"; done
}

RO_GIT=' status log show diff rev-parse ls-files ls-tree grep blame describe cat-file merge-base for-each-ref shortlog reflog '

unquote() { _u=${1#[\"\']}; printf '%s' "${_u%[\"\']}"; }
# git_dir ARGS...: the last -C DIR among git's global options (empty if none).
git_dir() {
    _gd=""
    while [ $# -gt 0 ]; do
        case $1 in -C) _gd=${2:-}; shift 2 ;; -c | --git-dir | --work-tree | --namespace) shift 2 ;; -*) shift ;; *) break ;; esac
    done
    printf '%s' "$_gd"
}
# git_sub ARGS...: git's subcommand after its global options (-C dir, -c k=v, --no-pager, ...).
git_sub() {
    while [ $# -gt 0 ]; do
        case $1 in -C | -c | --git-dir | --work-tree | --namespace) shift 2 ;; -*) shift ;; *) break ;; esac
    done
    printf '%s' "${1:-}"
}
# newdir TARGET: the directory `cd TARGET` moves to, or empty if it cannot be known statically.
newdir() {
    _d=$(unquote "$1")
    case $_d in
        '' | -) return 0 ;;
        '$HOME' | '${HOME}' | '$HOME/'* | '${HOME}/'*) ;;
        *'$'* | *'`'*) return 0 ;;
    esac
    abspath "$_d" "$cwd"
}
