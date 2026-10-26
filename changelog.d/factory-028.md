- **factory 0.2.8** (`factory/`, not yet synced into the coordinator or the packages): the lane cap
  (`[lanes] max_open`) is enforced again.
  - `dispatch_limit.sh` counted SubagentStart minus SubagentStop, which in-process teammates never
    balance, so the cap never fired after 2026-10-20.
  - A lane is now an Agent dispatch, recorded by `dispatch_limit.sh` under a lock. It is closed by:
    - its `completed` or failed result;
    - auto mode's denial of it;
    - a background agent's SubagentStop;
    - `TaskStop <name>`;
    - for an agent that is gone, `scripts/lane release <name>`.
  - An unknown result status keeps the lane counted.
  - Only dispatches that never ran expire, after `FACTORY_LANE_TTL_HOURS` (default 24).
  - The ledger no longer drops the record that follows a truncated line.
  - New hook library `_lanes.sh`. New PostToolUse, PostToolUseFailure and PermissionDenied wiring in
    `settings.json`. New subcommand `lane release`.

  Spec: `docs/superpowers/specs/2026-10-26-factory-028-design.md`. The release was reviewed by the
  critic: ACCEPT WITH FIXES. B1, M1–M5 and m1 are fixed and tested; m2–m5 are documented. The coordinator sync is T3
  (`FACTORY_ALLOW_T3=1`), and each package takes 0.2.8 in its own sync lane.
