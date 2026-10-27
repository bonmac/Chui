- **factory 0.4.0, lane.jl** (`factory/template/`; not yet versioned or synced), plan
  `docs/superpowers/plans/2026-10-27-factory-040.md` Tasks 2, 5 and 9 (the `lane.jl` parts):
  - `scripts/lane compact [--keep N]` (D2): rewrites the ledger keeping every line of an open
    dispatch chain in every session plus the last N (200) other lines, under the cap's lock,
    through a temp file and a rename; the open set comes from the hooks' own `_lanes.sh` query
    (one copy), run before and after, and nothing is replaced if it would change. Code in the new
    `factory/template/scripts/_lane_stats.jl`, included by `lane.jl`.
  - `scripts/lane audit <name> --report FILE` (D5): the report's first line must be exactly
    `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST` (one of the three, exact case, nothing
    else on the line), else the audit fails; a passing audit records `{ev: verdict, lane, verdict,
    report}` in the ledger. `--reported` is unchanged.
  - `scripts/lane stats [--since ISO]` and `scripts/lane handoff` (D11): one Markdown row per
    dispatch of the ledger (dispatched, closed by the hooks' closing rules, duration, verdict, the
    session's dispatch denials and the name's idle-unreported events while open), and the HANDOFF
    "Open lanes" table from `git worktree list` (a worktree outside `.worktrees/` is `unmanaged`)
    and the open dispatches without a worktree. Read-only.
