- **factory 0.4.0, lane.jl** (`factory/template/`; not yet versioned or synced), plan
  `docs/superpowers/plans/2026-10-27-factory-040.md` Tasks 2, 5 and 9 (the `lane.jl` parts):
  - `scripts/lane compact [--keep N]` (D2, critic's rule): rewrites the ledger keeping every
    dispatch, spawn, close, verdict and denial event of every session; only `stop`s whose agent_id
    no `spawned` or `unknown-result` record names, non-JSON lines and idle events outside the last
    N (200) lines are dropped. Holds the cap's lock for the whole read, rewrite and rename; the
    per-session open set from the hooks' own `_lanes.sh` query (one copy) is run before and after,
    and nothing is replaced if it would change. Code in the new
    `factory/template/scripts/_lane_stats.jl`, included by `lane.jl`.
  - Review round 1: a `stop` closing an `unknown-result` dispatch is kept (M1: it was dropped, the
    lane reopened and the safety check refused forever, so the ledger never shrank); every append
    `lane.jl` makes (`lane-new`, `verdict`, `release`) takes the cap's lock, waits 5 s, never breaks
    it, and the command exits non-zero when it cannot (M2: an append during compact's rename was
    lost); `stats` and `handoff` give the one-line "cannot read [lanes] ledger" error, exit 1 (m1);
    the `denied` column is `session denied` with a footnote (m2); a dispatch's verdict is the one
    recorded in its round, after its row and before the next dispatch of its name (m3); the
    "compacted" line counts the non-JSON lines dropped (n1).
  - `scripts/lane audit <name> --report FILE` (D5): the report's first line must be exactly
    `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST` (one of the three, exact case, nothing
    else on the line: not the template line, not bold) and a line `Head: <sha>` (7+ characters)
    must name the lane's current HEAD (a stale round fails), else the audit fails; a passing audit
    records `{ev: verdict, lane, verdict, head, report}` in the ledger. `--reported` is unchanged.
  - `scripts/lane stats [--since ISO]` and `scripts/lane handoff` (D11): one Markdown row per
    dispatch of the ledger (dispatched, closed by the hooks' closing rules, duration, verdict, the
    session's dispatch denials and the name's idle-unreported events while open), and the HANDOFF
    "Open lanes" table from `git worktree list` (a worktree outside `.worktrees/` is `unmanaged`)
    and the open dispatches without a worktree. Read-only.
