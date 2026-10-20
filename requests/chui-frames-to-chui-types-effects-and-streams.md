# Effect runtime run and cancel entry points, Task and Channel conversions, and a public stream API for a bounded Source (R10)

- **From → to:** chui-frames → chui-types
- **Status:** accepted        <!-- built on ChuiTypes main 6ee5fac (phases 3-4; ADR-0008 Accepted 2026-10-20), not released; stays open while ChuiFrames' Task shim exists -->
- **Urgency:** later (ChuiFrames phase 5: asynchronous source reads and the stream source)
- **Contract IDs affected:** today PROVISIONAL ("Effect runtime API", "Adapters", "Streams", "Stream as a ChuiFrames `Source`" in `chui-types.md`) and obligations 1 and 2 (obligation 2 as amended by ADR-0013); proposed as CT-004 to CT-007 by request `chui-types-to-coordinator-export-tiers-and-ct-ids.md` (R11, T3, the user applies); CF-011 and CF-015 on the ChuiFrames side
- **Adapter used meanwhile:** ChuiFrames' internal effects adapter, a plain-`Task` shim with cooperative cancellation through a flag checked between morsels (ChuiFrames ADR-0015 §1, ADR-0003 rules 7 and 15; not yet on ChuiFrames main c5db1cb). `chui-types.md` allows such a shim only while this request is open, so this request **stays open until ChuiFrames removes the shim**.
- **Reproducer:** (corrected 2026-10-20, see History) with the ChuiTypes snapshot under test: `julia --startup-file=no -e 'using ChuiTypes, Test; const CT = ChuiTypes; t = Threads.@spawn error("boom"); @test_throws ErrorException run(CT.fromtask(t)); f = CT.start(CT.fromtask(Threads.@spawn (sleep(10); 1))); CT.interrupt!(f); @test_throws CT.Cancelled fetch(f); @test CT.runexit(CT.fromtask(Threads.@spawn 1)) isa CT.Exit; @test all(n -> isdefined(CT, n), (:totask, :fromchannel, :tochannel, :await, :withbatches, :runchunks))'`. RED today in ChuiFrames: no ChuiTypes snapshot is registered. GREEN on 1.10.12 and 1.13.2 against a registered snapshot. Run so far only against unreleased ChuiTypes main (History, 2026-10-20).

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
- 2026-10-20 accepted (lead triage; filed by the coordinator lane requests-p4p3): **ChuiTypes
  phases 3 and 4 have built the whole path** on ChuiTypes main `6ee5fac` (unreleased).
  - **Run and cancel:** `run`, `runexit`, `start` → `Fiber`, `interrupt!`, `await`, and `fetch`
    on a `Fiber` (throws the original exception), as proposed above.
  - **Task and Channel:** `fromtask`, `totask`, `fromchannel` (hot, single-consumer),
    `tochannel(s; size)`, with ecosystem ADR-0013's semantics.
  - **The bounded Source**, under ChuiTypes **ADR-0008** (Accepted 2026-10-20, user at the
    ChuiTypes phase-4 ★): a stream becomes a Source by a **snapshot**,
    `runchunks(s; maxelements)`, taken once. Chunks are fresh vectors owned by the run (a chunk
    of `NamedTuple`s is a Tables.jl row table); `eltype(s)` is an advisory schema; `maxelements`
    bounds memory, not time, so the adapter wraps the snapshot in `timeoutfail`. A cold stream
    re-run repeats its elements only for deterministic sources, so the answer to "two plans
    agree" is "snapshot once", not "re-run". `withbatches(f, s)` stays for one-pass consumers.
  - **Every name above is exported** (checked with `Base.isexported` at `6ee5fac`), except
    `run`, `fetch` and `eltype`, which are Base methods on ChuiTypes' types.
  - **Still to do:** CT IDs and the `chui-types.md` amendment are request
    `chui-types-to-coordinator-export-tiers-and-ct-ids.md` (R11; T3, the user applies). The
    adapter's own rules (snapshot once at construction, a bound and a `timeoutfail`) are request
    `chui-types-to-chui-frames-stream-source-snapshot.md` (R13).
  - **Reproducer corrected.** It called `CT.fork(eff)`, which is an *effect* that forks inside a
    scope and succeeds with the fiber; it is not a `Fiber`, so `interrupt!` on it is a
    `MethodError`. The corrected command uses `CT.start(eff)`, which returns a `Fiber` at once,
    and also checks `runchunks`. Against ChuiTypes main `6ee5fac` (unreleased, so still RED in
    ChuiFrames' sense), Julia 1.13.2, `julia --startup-file=no --project=. -t 2` in
    `ChuiTypes.jl`: the corrected command printed `GREEN` (all four `@test`s pass); the old
    `fork` form fails with
    `MethodError: no method matching interrupt!(::Effect{Union{}, Fiber{Exception, Any}})`.
    Not run on 1.10.12 (ChuiTypes has no LTS manifest in this checkout).
  - **Stays open** until ChuiFrames drops its Task shim and adopts a released ChuiTypes snapshot
    (then `adopted`).
