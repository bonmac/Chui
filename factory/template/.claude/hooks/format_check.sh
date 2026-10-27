#!/bin/sh
# format_check.sh: PostToolUse(Edit|Write). ADVISORY (0.4.0, D10): after an Edit or Write of a `.jl`
# file, runs `runic --check FILE` when a `runic` executable is on PATH and exits 2 (stderr goes back
# to the agent) with the file's root-relative path and the tail of runic's output when the file is
# not Runic-formatted. Exits 0 silently when runic is absent, the file is not `.jl`, the payload has
# no path (or is not JSON), the file does not exist, or runic passes. Fails OPEN by design: a hook
# that blocks on its own crash after a successful edit would stop work the gate (`ci.jl format`)
# catches anyway, so settings.json runs this one plainly, not through the fail-closed wrapper.
. "$(dirname -- "$0")/_lib.sh"
have_jq || exit 0
command -v runic >/dev/null 2>&1 || exit 0
file=$(field '.tool_input.file_path')
[ -n "$file" ] || file=$(field '.tool_input.path')
[ -n "$file" ] || exit 0
case $file in *.jl) ;; *) exit 0 ;; esac
abs=$(abspath "$file" "$(field '.cwd')")
[ -f "$abs" ] || exit 0
out=$(runic --check "$abs" 2>&1) && exit 0
case $abs in
    "$ROOT"/*) rel=${abs#"$ROOT"/} ;;
    "$ROOT_P"/*) rel=${abs#"$ROOT_P"/} ;;
    *) rel=$abs ;;
esac
# shellcheck disable=SC2016 # the backticks are literal: they quote a command in the message
printf '[factory] %s is not Runic-formatted (advisory: `runic %s` fixes it; the format gate also checks it). runic --check said:\n' "$rel" "$rel" >&2
printf '%s\n' "$out" | tail -n 20 >&2
exit 2
