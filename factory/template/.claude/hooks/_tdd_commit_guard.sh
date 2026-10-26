# shellcheck shell=sh
# shellcheck disable=SC2034,SC2154 # at, bg, cwd, CWD_OK, AN, AE, PENDING and tdeny come from tdd_boundary.sh
# _tdd_commit_guard.sh (factory 0.3.0, spec §0.5): the PreToolUse half of the commit guard, sourced by
# tdd_boundary.sh, and the identity and path rules tdd_commit_post.sh shares. Defines functions only.
# Sourced after _lib.sh and _bash_guard_lib.sh (git_dir). The role is agent_type ONLY (plan Task 0).
TW_ID='test-writer <test-writer@factory.invalid>'
PEND="$ROOT/.lanes/tdd-pending" # <tool_use_id>: "@ <agent_type> <agent_id>", then "<HEAD before> <checkout>" lines
TDD_STALE_MIN=15                # a pending entry older than this (minutes) was left by a cancelled call: swept
NL='
'
cdeny() { tdeny "$1" "§0.5" "$2"; }

# idnorm WORD: a "Name <email>" identity, also as segments() spells a quoted one (Name__email_), as ID ("" if neither)
idnorm() {
    case $1 in
        *' <'*'>') ID=$1 ;;
        ?*__*@*) _e=${1##*__} && ID="${1%__*} <${_e%_}>" ;;
        *) ID="" ;;
    esac
}
# role_of ID: the role an identity claims by its name or its email (R: test-writer, implementer, lead or "")
role_of() {
    _n=${1% <*} _e=${1##*<}
    case "$_n|${_e%>}" in
        'test-writer|'* | *'|test-writer@factory.invalid') R=test-writer ;;
        'implementer|'* | *'|implementer@factory.invalid') R=implementer ;;
        'lead|'* | *'|lead@factory.invalid') R=lead ;;
        *) R="" ;;
    esac
}
# id_rule CALLER ID: the §0.5 identity rule the commit breaks, as IDR ("" if none). CALLER is agent_type, - for the lead.
id_rule() {
    role_of "$2"
    IDR=""
    case $1 in
        test-writer | implementer) [ "$2" = "$1 <$1@factory.invalid>" ] || IDR=author-not-caller-role ;;
        -) case $R in test-writer | implementer) IDR=role-identity-not-caller ;; esac ;;
        *) [ -z "$R" ] || IDR=role-identity-not-caller ;;
    esac
}
ID_WHY="a role caller commits only as its role; no caller takes another role's identity, and only the lead (no agent_type) takes lead <lead@factory.invalid>"
# role_paths ROLE (stdin: repo-relative paths): the first path that ROLE may not commit (test-writer: test/**
# without the seeded runners test/runtests.jl and test/Project.toml; implementer: no test/**)
role_paths() {
    awk -v r="$1" 'r == "test-writer" && ($0 !~ /^test\// || $0 == "test/runtests.jl" || $0 == "test/Project.toml") { print; exit }
        r == "implementer" && /^test\// { print; exit }'
}
# caller_ident: the author git would record now (rule 4): the command's GIT_AUTHOR_* and -c options applied
caller_ident() (
    [ -z "$AN" ] || { GIT_AUTHOR_NAME=$AN && export GIT_AUTHOR_NAME; }
    [ -z "$AE" ] || { GIT_AUTHOR_EMAIL=$AE && export GIT_AUTHOR_EMAIL; }
    set -f
    set --
    IFS=$NL
    for _c in $_gc; do set -- "$@" -c "$_c"; done
    _i=$(git -C "$CO" "$@" var GIT_AUTHOR_IDENT 2>/dev/null) || exit 0
    printf '%s' "${_i% * *}"
)
# gsub ARGS...: git's subcommand after its global options, as GS (no fork: _bash_guard_lib's git_sub prints it)
gsub() {
    GS=""
    while [ $# -gt 0 ]; do
        case $1 in -C | -c | --git-dir | --work-tree | --namespace) shift $(($# > 1 ? 2 : 1)) ;; -*) shift ;; *) GS=$1; return 0 ;; esac
    done
}

# guard_commit ARGS... (git's, global options first): deny what §0.5 forbids, else add "<HEAD> <checkout>" to PENDING.
# The effective author, first rule that applies: --author; --reset-author with --amend/-C/-c: the caller; --amend,
# -C/-c/--reuse-message/--reedit-message: the source commit's author; else git var GIT_AUTHOR_IDENT.
guard_commit() {
    [ "$bg" != true ] || cdeny background "a git commit in a run_in_background call is never allowed: its post check would run before the commit exists"
    _gd=$(git_dir "$@") _gc=""
    while [ $# -gt 0 ]; do
        case $1 in
            commit) shift; break ;;
            -c) _gc="$_gc${2:-}$NL"; shift $(($# > 1 ? 2 : 1)) ;;
            -C | --git-dir | --work-tree | --namespace) shift $(($# > 1 ? 2 : 1)) ;;
            *) shift ;;
        esac
    done
    _au="" _ra="" _am="" _src="" _ru="" _fx="" _md="" _all="" _p=""
    for _w in "$@"; do
        case $_w in *[Tt][Dd][Dd]-[Mm][Oo][Dd][Ee]*) _md=1 ;; esac
        if [ -n "$_p" ]; then case $_p in a) _au=$_w ;; s) _src=$_w ;; esac; _p=""; continue; fi
        case $_w in
            --author) _p=a ;;
            --author=*) _au=${_w#*=} ;;
            --reset-author) _ra=1 ;;
            --amend) _am=1 ;;
            -C | -c | --reuse-message | --reedit-message) _p=s _ru=1 ;;
            -C?* | -c?*) _src=${_w#-?} _ru=1 ;;
            --reuse-message=* | --reedit-message=*) _src=${_w#*=} _ru=1 ;;
            --fixup | --squash) _p=x _fx=1 ;;
            --fixup=* | --squash=*) _fx=1 ;;
            -m | -F | --message | --file | -t | --template | --trailer | --date | --cleanup) _p=x ;;
            -a | --all | -i | --include | -o | --only | -p | --patch | --interactive | --pathspec-from-file*) _all=1 ;;
            -[!-]*m | -[!-]*F) _p=x; case $_w in *a*) _all=1 ;; esac ;;
            -[!-]*) case $_w in *a*) _all=1 ;; esac ;;
            -*) ;;
            *) _all=1 ;; # a pathspec: commits those paths, staged or not
        esac
    done
    case $at in test-writer | implementer)
        [ -z "$_md" ] || cdeny mode-trailer "only the lead writes a TDD-Mode: trailer"
        [ -z "$_all" ] || cdeny commit-paths "a $at stages named paths with git add and commits the index: no -a/-i/-o/-p or pathspecs on git commit" ;;
    esac
    [ "$at" != test-writer ] || [ -z "$_ru$_fx" ] ||
        cdeny tw-reuse-message "a test-writer may not use -C/-c/--reuse-message/--reedit-message/--fixup/--squash: they reuse another commit's message"
    [ -n "$CWD_OK" ] || case $_gd in /*) ;; *) cdeny cwd-unknown "this git commit runs after a cd the guard cannot follow; use git -C <absolute checkout> commit" ;; esac
    _rd=$cwd
    [ -z "$_gd" ] || _rd=$(abspath "$_gd" "$cwd")
    co_of "$_rd"
    [ -n "$CO" ] || return 0 # not a checkout: git refuses on its own
    if [ -n "$_au" ]; then
        idnorm "$_au"
        [ -n "$ID" ] || cdeny author-form "--author must be a full 'Name <email>' (a pattern can match a role's earlier commit): $_au"
    elif [ -n "$_am$_ru" ] && [ -z "$_ra" ]; then
        ID=$(git -C "$CO" log -1 --format='%an <%ae>' "${_src:-HEAD}" -- 2>/dev/null)
        [ -n "$ID" ] || cdeny source-author "cannot read the author of ${_src:-HEAD}, which this commit would keep"
    else
        ID=$(caller_ident)
        [ -n "$ID" ] || cdeny caller-ident "cannot compute this commit's author (git var GIT_AUTHOR_IDENT failed in $CO)"
    fi
    id_rule "${at:--}" "$ID"
    [ -z "$IDR" ] || cdeny "$IDR" "this commit would be authored '$ID' by ${at:-the lead}: $ID_WHY"
    if [ "$at" = test-writer ] && [ -n "$_am" ]; then
        [ "$(git -C "$CO" log -1 --format='%an <%ae>' HEAD 2>/dev/null)" = "$TW_ID" ] || cdeny tw-amend "a test-writer amends only a HEAD it authored"
    fi
    case $at in test-writer | implementer)
        _bad=$(git -C "$CO" diff --cached --name-only 2>/dev/null | role_paths "$at")
        [ -z "$_bad" ] || cdeny staged-path "a $at may not commit $_bad (test-writer: test/** without test/runtests.jl and test/Project.toml; implementer: no test/**)" ;;
    esac
    _h=$(git -C "$CO" rev-parse -q --verify HEAD 2>/dev/null)
    case $PENDING in *" $CO$NL"*) ;; *) PENDING="$PENDING${_h:-none} $CO$NL" ;; esac
}
