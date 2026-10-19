# A first registered ChuiCore 0.0.x snapshot in ChuiRegistry (R4)

- **From → to:** chui-types → chui-core
- **Status:** open            <!-- needs the user: registration is an outward action -->
- **Urgency:** soon
- **Contract IDs affected:** none (release); every CC-ID ChuiTypes will list in `test/contracts/USED.md`
- **Adapter used meanwhile:** `ChuiTypes.Upstream` stand-ins (ChuiTypes ADR-0004 §2); ChuiCore is not yet in ChuiTypes' `[deps]`
- **Reproducer:** `julia --startup-file=no -e 'using Pkg; Pkg.activate(temp = true); Pkg.add("ChuiCore")'`, run with ChuiRegistry added. RED today: ChuiCore is not registered. GREEN when a `0.0.x` snapshot resolves. Not run by this lane.

## Problem
ChuiTypes depends only on registered `0.0.x` snapshots of ChuiCore (ADR-0004 rule 2), never on a `develop` or git URL. Until one exists, ChuiTypes works against stand-ins, and its contract tests cannot run.

## Proposed API
None. The request is for a release: ChuiCore `0.0.1` (or the next `0.0.x`) tagged and registered in ChuiRegistry (ADR-0005), recorded in `releases.md`.

**Needs the user.** Tagging and registering are outward actions (CLAUDE.md, non-negotiable 4). The release-manager prepares the release; the user approves it.

## History
- 2026-10-20 open: drafted by the ChuiTypes phase-1 lane (ChuiTypes ADR-0004 §7, main 455c085); filed by eco-amend for the lead. Waiting on ChuiCore's phase 2 and the user's approval to register.
