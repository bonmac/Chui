# Docstrings and ADR-0008 overstate `interrupt!`, `runchunks(maxelements)` and `timeoutfail` (R16)

- **From → to:** coordinator (found by the critic reviewing R11's contract text) → chui-types
- **Status:** open
- **Urgency:** later (the proposed CT-004 and CT-006 already state the true behaviour; only ChuiTypes' own docs disagree)
- **Contract IDs affected:** proposed CT-004, CT-006 (R11); none changes
- **Adapter used meanwhile:** none needed
- **Reproducer:** in `<root>`: `julia --startup-file=no --project=ChuiTypes.jl -e 'using ChuiTypes; a = string(@doc ChuiTypes.interrupt!); b = string(@doc ChuiTypes.runchunks); ok = !occursin("every fiber it started", a) && !occursin("are read", b); println(ok); exit(ok ? 0 : 1)'`. RED at ChuiTypes main `6ee5fac`: `false`, exit 1. GREEN when both docstrings are corrected. The ADR-0008 text is checked by reading it.

## Problem
Three statements in ChuiTypes are false at `6ee5fac`, each shown by a one-line command in the
critic's round-1 review of R11 and re-run by this lane:
1. `interrupt!`'s docstring (`src/effect/fiber.jl`) says it cancels "every fiber it started". It
   cancels the fibers `f` **forked**; a fiber made with `start` inside `f` keeps running. The run
   printed `Fiber{Union{}, Nothing}(running)`.
2. `runchunks`' docstring (`src/stream/core.jl`) and ADR-0008 §2 say a stream over the bound fails
   "after `n + 1` are read". The bound is checked per chunk, so up to `n` plus one chunk is read:
   1024 elements were read under `maxelements = 10`.
3. ADR-0008 §2 says an adapter "should … wrap the snapshot in `timeoutfail`" to bound time.
   `timeoutfail` is built on `racefirst`: it interrupts the snapshot and waits for it to stop. So
   a source blocked in a plain call, or a pure stream on one thread, overruns the deadline. The
   run took 4.97 s against `d = 0.5`, for a source sleeping 4 s inside `sync`.

## Proposed API
No API change. Correct the two docstrings, and add a dated note to ADR-0008 §2 using the wording
of the proposed CT-004 and CT-006. Alternatively, if ChuiTypes would rather change the code (an
element-level `maxelements` check, a hard deadline in `timeoutfail`), that is a ChuiTypes ADR, and
CT-004/CT-006 would then be tightened with it.

## History
- 2026-10-20 open: from critic round 1 on R11 (B2, B3, B4), filed by the coordinator lane
  requests-p4p3. Reproducer run at ChuiTypes `6ee5fac`, Julia 1.13.2: `false`, exit 1 (RED).
