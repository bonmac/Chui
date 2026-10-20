# Effect runtime run and cancel entry points, Task and Channel conversions, and a public stream API for a bounded Source (R10)

- **From → to:** chui-frames → chui-types
- **Status:** open            <!-- partly answered by ChuiTypes ADR-0002, 0003, 0006; stays open while ChuiFrames' Task shim exists -->
- **Urgency:** later (ChuiFrames phase 5: asynchronous source reads and the stream source)
- **Contract IDs affected:** PROVISIONAL ("Effect runtime API", "Adapters", "Streams", "Stream as a ChuiFrames `Source`" in `chui-types.md`); obligations 1 and 2 (obligation 2 as amended by ADR-0013); CF-011 and CF-015 on the ChuiFrames side
- **Adapter used meanwhile:** ChuiFrames' internal effects adapter, a plain-`Task` shim with cooperative cancellation through a flag checked between morsels (ChuiFrames ADR-0015 §1, ADR-0003 rules 7 and 15; not yet on ChuiFrames main c5db1cb). `chui-types.md` allows such a shim only while this request is open, so this request **stays open until ChuiFrames removes the shim**.
- **Reproducer:** with the ChuiTypes snapshot under test (names from ChuiTypes ADR-0002, 0003, 0006; several are PROVISIONAL there): `julia --startup-file=no -e 'using ChuiTypes, Test; const CT = ChuiTypes; t = Threads.@spawn error("boom"); @test_throws ErrorException run(CT.fromtask(t)); f = CT.fork(CT.fromtask(Threads.@spawn (sleep(10); 1))); CT.interrupt!(f); @test_throws CT.Cancelled fetch(f); @test CT.runexit(CT.fromtask(Threads.@spawn 1)) isa CT.Exit; @test all(n -> isdefined(CT, n), (:totask, :fromchannel, :tochannel, :await, :withbatches))'`. RED today: no ChuiTypes snapshot is registered, and ChuiTypes ADR-0006 says "the adapters are designed, not built". GREEN on 1.10.12 and 1.13.2. Not run by this lane.

## Problem
ChuiFrames' async I/O and future side effects must run on ChuiTypes' one effect runtime
(ecosystem ADR-0009 §4), and its stream source adapter lives in ChuiFrames, using only ChuiTypes'
public stream API (ecosystem ADR-0002 §1). ChuiFrames needs:
1. **Run and cancel.** Run per-partition reads as effects and get back the **original
   exception** of the first failing read (ChuiFrames ADR-0003 rule 7); cancel a query, where
   cancellation can be cooperative (Base has no task-cancellation API; ChuiFrames ADR-0015).
2. **Task and Channel conversions,** for sources whose libraries hand back `Task`s or
   `Channel`s (HTTP, S3 connectors in phase 6).
3. **A public stream API for a bounded Source** (CF-011, CF-015): a Source must return a
   **finite** `Vector` of partition handles from `plan_partitions`, with a `Tables.Schema`, and
   `explain` followed by `collect` must plan the same partitions.

## Proposed API
The names ChuiTypes has already designed, made **public** (qualified use is enough; none needs to
be exported) and given CT IDs:
- **Run:** `run(eff)` (a `Base.run` method on the owned type) returning the value or throwing
  the original exception; `runexit(eff)` returning the `Exit` (ChuiTypes ADR-0002 §3).
- **Cancel:** `fork`/`start(eff)` → a `Fiber`; `interrupt!(f)` signals, `await(f)` waits; a
  `Fiber`'s `fetch` throws the original exception (ADR-0002 §3, §5; ecosystem ADR-0013).
- **Task:** `fromtask(t::Task; canceller = nothing)` and `totask(eff)::Task` with ecosystem
  ADR-0013's semantics.
- **Channel:** `fromchannel(ch)` (hot, single-consumer) and `tochannel(stream; size)`
  (ChuiTypes ADR-0006).
- **Streams, for the bounded Source:**
  - a pull of the stream's chunks **in order** (`withbatches(f, s)` or a chunk iterator; ADR-0003
    §10) whose chunks are Tables.jl tables or vectors of `NamedTuple`s;
  - the chunk element type, so the adapter can build a `Tables.Schema` without reading data;
  - a way to know a stream is **finite**, or a documented rule that the adapter must snapshot the
    chunk list at construction (as ChuiFrames does for any Tables.jl input, CF-011);
  - confirmation that a cold stream re-run from the start yields the same chunks, so two plans
    over one stream agree.

## History
- 2026-10-20 open: drafted in the ChuiFrames phase-1 report (ChuiFrames ADR-0015 §2, ADR-0004
  rules 5 and 8; main c5db1cb); filed by the coordinator lane frames-reqs for the lead.
  **Partly answered at filing:** the run, cancel, Task and Channel names and semantics are
  designed in ChuiTypes ADR-0002 §3 and §5 and ADR-0006, and ecosystem ADR-0013 (accepted)
  settles the exception and cancellation semantics. Streams are cold and chunked (ChuiTypes
  ADR-0003); `runcollect`/`runfold`/`runforeach` and `withbatches` are PROVISIONAL names, and
  ADR-0003 says the Source adapter "needs a cross-repo design round (bounded vs streaming,
  schema)", which ChuiFrames ADR-0004 rule 8 now answers on its side: bounded first. **Still
  open:** export tiers for these names, CT IDs, and the stream-to-Source questions above. The
  runtime lands in ChuiTypes phase 3 and streams in phase 4; nothing is built yet.
