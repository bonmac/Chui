- **factory 0.4.0, format hook** (`factory/template/`; not yet versioned or synced), plan
  `docs/superpowers/plans/2026-10-27-factory-040.md` Task 8 (D10, D9): new
  `factory/template/.claude/hooks/format_check.sh`, wired in `factory/template/.claude/settings.json`
  as `PostToolUse` on `Edit|Write` (a plain `sh .../format_check.sh`, timeout 10, not the fail-closed
  wrapper). For a `.jl` file (`tool_input.file_path`, else `tool_input.path`) it runs
  `runic --check FILE` when a `runic` executable is on PATH and exits 2 with
  `[factory] <root-relative file> is not Runic-formatted` plus the last 20 lines of runic's output;
  it exits 0 silently when runic or jq is absent, the file is not `.jl`, the payload has no path or
  is not JSON, the file does not exist, or runic passes. ADVISORY and fails open by design: the
  format gate still formats. `factory/template/.agents/checks.toml` gains the `format_check` table
  (blind spots: fails open; needs runic on PATH; other file types; Bash-made edits; the Monitor tool
  is covered by the `Bash|Monitor` matcher only through `tool_input.command`; the codex plugin runs
  commands no hook sees), rendered into `factory/template/docs/CHECK_COVERAGE.md`. Tests: new
  `factory/template/scripts/test/test_hooks_format.jl` (a stub `runic` on a temp PATH with a call
  recorder; the real PATH is replaced), included from `scripts/test/test_hooks.jl`.
  Review round 1 (`fix(hooks)`): M1, only runic exit 1 means unformatted; any other exit (a crash,
  127) prints `[factory] runic --check failed (rc N); formatting not checked` and exits 0 (tested
  with stubs exiting 139, 127 and 2). N1, the suggested `runic '<path>'` is quoted. N2, the
  `format_check` blind spots name the host's 10 s hook timeout (a cold runic can exceed it: the hook
  is killed with no advice). Also the hook file is mode 755 like every other hook
  (`test_sync_factory.jl` requires it; the first full gates caught it).
