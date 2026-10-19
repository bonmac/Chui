# Transducer names and a type-stable, allocation-free fold over a chunk (R3)

- **From → to:** chui-types → chui-core
- **Status:** open
- **Urgency:** soon
- **Contract IDs affected:** PROVISIONAL ("The transducer substrate API"); the `isstateless` obligation (proposed, ADR-0012 P2)
- **Adapter used meanwhile:** a minimal, temporary transducer fold over a chunk in `ChuiTypes.Upstream` (ChuiTypes ADR-0004 §2)
- **Reproducer:** with the ChuiCore snapshot: `julia --startup-file=no -e 'using ChuiCore, Test; const CC = ChuiCore; f(xf, xs) = CC.foldxl(+, xf, xs; init = 0.0); alloc(xf, xs) = (f(xf, xs); @allocated f(xf, xs)); xs = rand(1000); xf = CC.Map(abs) ⨟ CC.Filter(>(0.5)); @test (@inferred f(xf, xs)) isa Float64; @test alloc(xf, xs) == 0; n = Ref(0); CC.foldxl(+, CC.Map(x -> (n[] += 1; x)) ⨟ CC.Take(3), 1:10^6; init = 0); @test n[] == 3'` (the allocation is measured inside a function, not at global scope). RED today: no snapshot. GREEN when all three checks pass on 1.10.12 and 1.13.2. Not run by this lane.

## Problem
ChuiTypes streams are pull-based and chunked (ChuiTypes ADR-0003). Each chunk is folded through a transducer pipeline, so the fold must be type-stable and allocation-free over an `AbstractVector` chunk, and `Reduced` must stop early.

## Proposed API
ChuiCore ADR-0003 (accepted 2026-10-20) gives the shape:
- `Map`, `Filter` and `Take` are structs, and `Reduced` stops early;
- `foldxl(op, xf, itr; init)` runs `complete` once;
- all of these are public, not exported.

The request is for the guarantee itself, so that a regression is caught upstream:
- `@inferred` and 0 bytes for stateless pipelines over an `AbstractVector`;
- early stop through `Reduced`.

ChuiTypes must not use `foldparts`/`foldxt` on unbounded or effectful streams (ChuiCore ADR-0003, Consequences).

## History
- 2026-10-20 open: drafted by the ChuiTypes phase-1 lane (ChuiTypes ADR-0004 §7, main 455c085); filed by eco-amend for the lead.
