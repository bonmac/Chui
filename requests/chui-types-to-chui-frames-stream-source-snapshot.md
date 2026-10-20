# The stream Source adapter takes one bounded, timed snapshot at construction (R13)

- **From → to:** chui-types → chui-frames
- **Status:** open
- **Urgency:** later (ChuiFrames phase 5, when it builds the stream Source under R10)
- **Contract IDs affected:** CF-011 (snapshot at construction; `isthreadsafe`), CF-015 (bounded v0); proposed CT-006 (R11)
- **Adapter used meanwhile:** none: ChuiFrames has no stream Source yet (`grep` finds no `runchunks` in `ChuiFrames.jl/src` at `d3bcec8`). ChuiTypes tests the guarantee with its own mock Source (`ChuiTypes.jl/test/test_stream_source.jl`).
- **Reproducer:** in `<root>`: `grep -rl runchunks ChuiFrames.jl/src && grep -rl timeoutfail ChuiFrames.jl/src`. RED today: no match, exit 1. Once the adapter exists ChuiFrames adds a `:contract` test item (CT-006) to its `test/contracts/`. In that test, a stream whose source counts its runs is wrapped once and planned twice (`explain`, then `collect`). The run count must stay 1 and the two partition lists must be equal. A `fromchannel` stream over an open, empty channel, under a small timeout, must fail with the timeout's error and not hang. That test item becomes the GREEN command; it is not written yet, because the adapter's name is PROVISIONAL.

## Problem
ChuiTypes ADR-0008 (Accepted 2026-10-20) makes a bounded stream a Source **by a snapshot**:
`runchunks(s; maxelements = n)` runs the cold stream once and succeeds with fresh, run-owned
chunk vectors. Two facts force rules on the adapter, which lives in ChuiFrames
(ADR-0002 §1, ChuiTypes ADR-0008 "Decision", first paragraph):
1. **Re-running is not stable.** A cold stream re-run repeats its elements only when every source
   is deterministic. `merge`, hot sources and time operators change chunk boundaries and
   interleavings between runs, and every re-run repeats the upstream I/O. A Source that re-runs
   the stream per plan or per partition breaks CF-011 ("`explain` followed by `collect` plans the
   same partitions") and CF-008.
2. **`maxelements` bounds memory, not time.** ChuiTypes cannot prove a stream finite. A source
   that never ends nor fills the bound (an open, empty `fromchannel`, an unclosed `subscribe`)
   hangs the snapshot unless it is timed out.

## Proposed API
ChuiFrames' stream Source adapter (its name is ChuiFrames' choice):
- takes the snapshot **once, when the source is built**, the way CF-011 snapshots any Tables.jl
  input. It never re-runs the stream per plan, per `plan_partitions` call or per
  `read_partition`;
- runs `ChuiTypes.timeoutfail(ChuiTypes.runchunks(s; maxelements = n), d, err)` with `run`. Here
  `n` is a memory bound and `d` a time bound, user-settable with documented defaults, and `err`
  is an error naming the stream and `d`. Two caveats, which the adapter documents:
  - `maxelements` is checked per chunk, so up to `n` plus one chunk is read and held;
  - `timeoutfail` interrupts the snapshot after `d` and fails only once the snapshot has stopped.
    A source blocked in a plain (non-runtime) call, or a stream of pure chunks on one thread,
    delays or prevents that, so `d` is a hard bound only for sources that wait cancellably
    (proposed CT-006). Measured at ChuiTypes `6ee5fac`: a source sleeping 4 s inside `sync`
    under `d = 0.5` failed after 4.97 s;
- builds `source_schema` from `eltype(s)` when it is a concrete `NamedTuple` type, else from the
  snapshot, else from a user-given schema. An empty stream with a non-concrete `eltype` and no
  user schema is an `ArgumentError`;
- may coalesce consecutive chunks deterministically (to `morsel` rows) into partitions; chunk
  sizes are not promised;
- may return `isthreadsafe(s) = true`, since the snapshot's vectors are fresh and never touched
  again.

## History
- 2026-10-20 open: drafted in the ChuiTypes phase-4 lane's report (ADR-0008, "Decision" and
  §2), filed by the coordinator lane requests-p4p3. Reproducer run in `<root>` at `961b764`
  (ChuiFrames main `d3bcec8`): no match, exit 1 (RED).
