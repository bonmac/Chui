- **factory 0.2.8** (`factory/`, not yet synced into the coordinator or the packages): the lane cap
  (`[lanes] max_open`) is enforced again.
  - `dispatch_limit.sh` counted SubagentStart minus SubagentStop, which in-process teammates never
    balance, so the cap never fired after 2026-10-20.
  - A lane is now an Agent dispatch, recorded by `dispatch_limit.sh`. It is closed by its
    foreground result, by a background agent's SubagentStop, or by `TaskStop <name>`.
  - Lanes expire after `FACTORY_LANE_TTL_HOURS` (default 24).
  - The ledger no longer drops the record that follows a truncated line.
  - New hook library `_lanes.sh`, and new PostToolUse/PostToolUseFailure wiring in `settings.json`.

  Spec: `docs/superpowers/specs/2026-10-26-factory-028-design.md`. The coordinator sync is T3
  (`FACTORY_ALLOW_T3=1`); each package takes 0.2.8 in its own sync lane.
