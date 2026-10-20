# Release the transducer substrate and `aggregate`: `isstateless`, `foldxl`, `foldparts`, `foldxt` (R7)

- **From → to:** chui-frames → chui-core
- **Status:** open            <!-- partly answered by ChuiCore ADR-0003 §4–7; see History -->
- **Urgency:** soon (ChuiFrames phase 2 uses `aggregate` and `foldxl`; phase 3 needs `isstateless`, `foldparts` and `foldxt` for morsel parallelism)
- **Contract IDs affected:** PROVISIONAL ("The transducer substrate API" in `chui-core.md`); the `isstateless` per-partition obligation (ADR-0012 P2, accepted 2026-10-20, not yet applied to `chui-core.md`); CC-004, CC-005
- **Adapter used meanwhile:** stand-ins for `Map`, `Filter`, `MapCat`, `Take`, `start`/`next`/`complete`, `Reduced`, `asrf`, `foldxl`, `foldparts(…; init, merge)`, `foldxt`, a fail-closed `isstateless` and `aggregate(agg, xf, parts)` in ChuiFrames' internal upstream adapter (ChuiFrames ADR-0014 §1; the module is not yet on ChuiFrames main c5db1cb)
- **Reproducer:** with the ChuiCore snapshot under test (keyword shapes from ChuiCore ADR-0003 §5–6; adjust to the released signatures): `julia --startup-file=no -e 'using ChuiCore, Test; const CC = ChuiCore; parts = [[1, 2], [3], Int[]]; @test CC.isstateless(CC.Map(abs) ⨟ CC.Filter(>(0))); @test !CC.isstateless(CC.Take(1)); struct MyXf <: CC.Transducer end; @test !CC.isstateless(MyXf()); @test CC.foldparts(+, CC.Map(identity), parts; init = () -> 0, merge = +) == 6; @test CC.foldparts(+, CC.Take(2), parts; init = () -> 0, merge = +) == 3; @test CC.foldxt(+, CC.Map(abs), [-1, 2, -3]; init = () -> 0, merge = +) == 6; @test CC.aggregate(CC.Sum(), CC.Map(identity), parts) == 6'`. RED today: no ChuiCore snapshot is registered, and no branch defines these names (ChuiCore main 3054d7c and its phase-2 branches, 2026-10-20). GREEN when every check passes on 1.10.12 and 1.13.2. Not run by this lane.

## Problem
ChuiFrames' engine runs fused stages over morsels (ChuiFrames ADR-0003 rules 5–6):
- a stage runs per partition **only if** `isstateless` says so; any other stage (a row limit, a
  scan) runs sequentially through `foldxl`;
- parallel folds go through `foldparts`/`foldxt` with an explicit, in-order `merge`;
- a plain fold over an aggregator goes through `aggregate(agg, xf, parts)` (ChuiCore ADR-0003
  rule 6), so CC-004 and CC-005 hold without ChuiFrames re-implementing partition folding.

ChuiCore owns the substrate (ecosystem ADR-0002 §4), so ChuiFrames' stand-ins must switch to
ChuiCore's names before ChuiFrames releases (ChuiFrames ADR-0014 §5).

## Proposed API
Exactly ChuiCore ADR-0003 (accepted 2026-10-20), public, not exported:
- `isstateless(xf)::Bool`, default `false`; `true` only for `Map`, `Filter`, `MapCat` and their
  compositions (§4).
- `foldxl(op, xf, itr; init)`, `init` a required value (§5).
- `foldparts(op, xf, parts; init, merge)`: `parts` an `AbstractVector` of iterables in order,
  `init` a factory, `merge` required; a non-stateless pipeline runs as one sequential `foldxl`
  with a single `init()` (§5).
- `foldxt(op, xf, v::AbstractVector; init, merge, ntasks)` (§5).
- `aggregate(agg, xf, parts)` over CC-004 unchanged: `init(agg)` as the factory, `partial`,
  `combine(agg, a, b)` as `merge`, then `final` (§6).

ChuiFrames asks for two things beyond the ADR text:
1. **Release order.** `aggregate`, `foldxl` and the stateless transducers before ChuiFrames'
   phase-2 eager engine lands, if ChuiCore's phase plan allows; `foldparts`/`foldxt` by
   ChuiFrames' phase 3.
2. **The `isstateless` obligation as a contract entry** with the test text of ADR-0012 P2, once
   the v1 transducer set is fixed (ChuiCore phase 3).

## Overlap
R3 (`chui-types-to-chui-core-transducer-fold.md`) asks for `foldxl`, `Map`/`Filter`/`Take`,
`Reduced` and an allocation-free chunk fold, and cites the same obligation. This request adds
`foldparts`, `foldxt` and `aggregate`, which R3 excludes. The lead may accept both together.

## History
- 2026-10-20 open: drafted in the ChuiFrames phase-1 report (ChuiFrames ADR-0003 rules 5–6,
  ADR-0014 §1, §4; main c5db1cb); filed by the coordinator lane frames-reqs for the lead.
  **Partly answered at filing:** the shape, semantics and tier are decided by ChuiCore ADR-0003
  §4–7; ADR-0012 P2 (accepted) states the per-partition obligation for the user to apply to
  `chui-core.md` (T3; not applied as of 2026-10-20). **Still open:** the v1 transducer set,
  `aggregate`'s name ("name provisional", §6) and the exact signatures (ChuiCore phase 3);
  nothing is implemented yet.
