# shellcheck shell=sh
# _paths.sh: path helpers for the factory hooks (normpath, abspath, phys). Sourced by _lib.sh, never run.
# Split from _lib.sh when the factory 0.3.0 and 0.4.0 changes together took it past the 150-line hook cap.

# normpath ABS: collapse //, /./ and /../ textually (symlinks are not resolved).
normpath() {
    _out=""
    _oldifs=$IFS
    case $- in *f*) _noglob=1 ;; *) _noglob="" ;; esac # restore the caller's noglob state
    IFS=/
    set -f
    for _seg in $1; do
        case $_seg in
            '' | .) ;;
            ..) _out=${_out%/*} ;;
            *) _out="$_out/$_seg" ;;
        esac
    done
    [ -n "$_noglob" ] || set +f
    IFS=$_oldifs
    printf '%s\n' "${_out:-/}"
}

# abspath PATH [BASE]: expand ~, make relative paths absolute against BASE, normalise.
# shellcheck disable=SC2088 # matching a literal "~/" prefix is the point
abspath() {
    case $1 in
        "~") _p=$HOME ;;
        "~/"*) _p="$HOME/${1#"~/"}" ;;
        "~+") _p=${2:-$ROOT} ;; # the current directory
        "~+/"*) _p="${2:-$ROOT}/${1#"~+/"}" ;;
        '$HOME' | '${HOME}') _p=$HOME ;;
        '$HOME/'*) _p="$HOME/${1#'$HOME/'}" ;;
        '${HOME}/'*) _p="$HOME/${1#'${HOME}/'}" ;;
        /*) _p=$1 ;;
        *) _p="${2:-$ROOT}/$1" ;;
    esac
    normpath "$_p"
}

# phys ABS (0.3.0, the tdd hooks): ABS with symlinks resolved (a missing tail kept) as RP; one fork.
# shellcheck disable=SC2034 # RP is read by _lanes.sh and _tdd_allow.sh
phys() {
    _p=$1 _t="" _n=0
    while [ -L "$_p" ] && [ "$_n" -lt 20 ]; do _n=$((_n + 1)) _l=$(readlink "$_p"); case $_l in /*) _p=$_l ;; *) _p="${_p%/*}/$_l" ;; esac; done
    while [ -n "$_p" ] && [ ! -d "$_p" ]; do _t="/${_p##*/}$_t" _p=${_p%/*}; done
    _r=$(CDPATH='' cd -P -- "${_p:-/}" 2>/dev/null && pwd -P) && RP=${_r%/}$_t || RP=""
}
# is_co, co_of and in_root (the checkout of a path) live in _tdd_allow.sh: only tdd_boundary.sh uses them.
