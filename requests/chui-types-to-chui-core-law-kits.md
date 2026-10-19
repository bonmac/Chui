# Law-kit form and the Supposition 1.10 workaround (R2)

- **From → to:** chui-types → chui-core
- **Status:** open            <!-- partly covered by ADR-0007 §2 amendment; see History -->
- **Urgency:** soon
- **Contract IDs affected:** PROVISIONAL ("Law kits"); CC-011
- **Adapter used meanwhile:** local law helpers in ChuiTypes' `test/laws/`, shaped like the kits (`test_<class>_laws(inst, gen; eq)`), using `@check record=false` plus `@test` (ChuiTypes ADR-0004 §5); deleted when the kits ship
- **Reproducer:** in a test environment with the ChuiCore snapshot, `Test` and Supposition, run under `julia +lts` a `@testset` that calls `ChuiCore.test_monoid_laws` on a deliberately unlawful instance. RED today: no snapshot, and the stub has no methods. GREEN when the testset reports a failure and the process exits 1 on 1.10.12 and 1.13.2. Not run by this lane.

## Problem
ChuiTypes needs ChuiCore's law kits to test its instances. On Julia 1.10 a failing Supposition `@check` is not recorded, so a kit that relies on recording passes vacuously on the blocking LTS job.

## Proposed API
- `test_<class>_laws(inst, gen; eq)`, with the instance first: an instance value, or a constructor tag for constructor classes.
- Supposition generators are asserted with `@check record=false db=false` plus an explicit
  `@test` (ADR-0007 §2 as amended).
- Planted-violation tests run on the LTS job.

Covered by ChuiCore ADR-0007 and by ecosystem ADR-0007 §2 as amended on 2026-10-20. Still open: the exact signatures and the kit list (ChuiCore phase 2).

## History
- 2026-10-20 open: drafted by the ChuiTypes phase-1 lane (ChuiTypes ADR-0004 §7, main 455c085); filed by eco-amend for the lead. Partly covered at filing by the ADR-0007 §2 amendment.
