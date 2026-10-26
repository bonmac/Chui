- **Changed:**
  - The coordinator is synced to **factory 0.2.8** (`--profile coordinator`; 10 managed files
    updated, `.claude/hooks/_lanes.sh` added, `.factory-version` records 0.2.8).
    `docs/CHECK_COVERAGE.md` is regenerated from `.agents/checks.toml`.
    - The lane cap (`[lanes] max_open`, 6 here) now fires. `dispatch_limit.sh` counts Agent
      dispatches, not SubagentStart minus SubagentStop, which in-process teammates never balanced.
      Before, the open count was always ≤ 0.
    - `lane_ledger.sh` also runs on PostToolUse and PostToolUseFailure (`Agent|Task|TaskStop`)
      and on PermissionDenied (`Agent|Task`). A lane closes when its foreground agent completes,
      on a TaskStop by name, or when its background agent's SubagentStop arrives.
    - `scripts/lane release <name>` closes a lane whose agent is gone. The cap's denial names it.
    - Dispatches run under `.lanes/.dispatch.lock`, so parallel Agent calls cannot pass the cap
      together. A dispatch that never ran stops counting after `FACTORY_LANE_TTL_HOURS` (default 24).
    - The ledger written before 0.2.8 counts 0 open lanes, since its lines are not dispatches.
    - The seven seeded files whose factory copy differs (`.agents/agent-registry.toml`,
      `.gitignore`, `CHANGELOG.md`, `CLAUDE.md`, `HANDOFF.md`, `LICENSE`, `ratchets.toml`) are
      left as they are. 0.2.8 changes none of them in the factory, and needs no new registry key.
