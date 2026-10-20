# Export tiers and CT IDs for the runtime and stream names R10 needs, and the "Stream as a ChuiFrames Source" amendment (R11)

- **From → to:** chui-types → coordinator (`contracts/chui-types.md`; T3, the user applies)
- **Status:** open
- **Urgency:** soon (ChuiFrames' stream Source and async reads, phase 5, test against these IDs)
- **Contract IDs affected:** new CT-004 to CT-007; the two obligations in `chui-types.md` (they become CT-004 and CT-005); PROVISIONAL "The effect runtime's API", "The adapter names", "Streams", "Stream as a ChuiFrames `Source`"
- **Adapter used meanwhile:** none in ChuiTypes (the names are built and exported on ChuiTypes main `6ee5fac`). ChuiFrames keeps its Task shim under R10 and cannot list CT IDs in its `test/contracts/USED.md` until they exist.
- **Reproducer:** in `<root>`: `julia --startup-file=no -e 's = read("contracts/chui-types.md", String); ok = all(id -> occursin("### " * id * " ", s), ("CT-004", "CT-005", "CT-006", "CT-007")) && occursin("ADR-0008", s); println(ok); exit(ok ? 0 : 1)' && julia --startup-file=no contracts/check.jl contracts`. RED today: `false`, exit 1 (`contracts/chui-types.md` at `961b764` has no CT-004). GREEN when the user has applied the proposed file and `check.jl` reports 0 errors on 1.13.2 and 1.10.12.

## Problem
R10 (ChuiFrames → ChuiTypes) asks for the effect runtime's run and cancel names, the Task and
Channel adapters, and a public stream API for a bounded Source, **made public and given CT IDs**.
ChuiTypes phases 3 and 4 built all of it on main `6ee5fac`, and ChuiTypes ADR-0008 (Accepted
2026-10-20, user at the phase-4 ★) decides how a bounded stream becomes a Source: a snapshot,
`runchunks(s; maxelements)`. But `chui-types.md` still lists every one of these names as
PROVISIONAL or as an untestable obligation, so:
- ChuiFrames cannot write `:contract` test items for them (README: PROVISIONAL items are never
  tested) and `contract_usage.jl --strict` would flag its use as reliance on unpromised API;
- the PROVISIONAL entry "Stream as a ChuiFrames `Source`" still says the adapter's API and "which
  stream operations ChuiTypes must make public" are open, which ADR-0008 now answers.

## Proposed API
Contract text, ready to apply: `chui-types.md` in the lead's scratchpad
`contracts-p3p4/`, with `DIFF.md` (items T1–T4). In short:

| ID | Entry | Names | Tier at `6ee5fac` |
|---|---|---|---|
| CT-004 | One effect runtime: run, start, interrupt and fetch (was obligation 1) | `Effect`, `run`, `runexit`, `Exit`, `succeeded`, `value`, `cause`, `isfail`, `isinterrupted`, `Fail`, `fail`, `start`, `Fiber`, `interrupt!`, `fetch`, `await`, `EffectFailed`, `Cancelled` | exported; `run` and `fetch` are Base methods; `succeeded`, `value`, `cause`, `isfail`, `isinterrupted`, `Fail` are public, not exported |
| CT-005 | Task and Channel adapters live in ChuiTypes (was obligation 2, with ADR-0013's semantics) | `fromtask`, `totask`, `fromchannel`, `tochannel`, `orphans` | exported; `orphans` is public, not exported |
| CT-006 | A bounded stream is snapshotted by `runchunks` (ChuiTypes ADR-0008) | `Stream`, `runchunks`, `eltype`, `timeoutfail` | exported; `eltype` is a Base method |
| CT-007 | `withbatches` pulls a stream's chunks in order, in one pass | `withbatches` | exported |

- **Tiers** (checked with `Base.isexported` and `Base.ispublic` at `6ee5fac`): as in the table.
  The Base methods are `run`, `fetch` and `eltype`; `orphans`, `Fail` and the `Exit` accessors
  are public and not exported; everything else is exported. The entries write all of them
  qualified (`ChuiTypes.runchunks`), as `chui-frames.md` does for its Source names.
- **The amendment the lead asked for:** the PROVISIONAL item "Stream as a ChuiFrames `Source`"
  now records ChuiTypes' half as decided (ADR-0008, CT-006) and leaves open only a streaming
  Source and a non-vector chunk type.
- **Beyond the brief's list** (runchunks, withbatches, eltype on Stream, fromchannel,
  tochannel, start, interrupt!, fetch on Fiber), the entries also cover `run`, `runexit`,
  `await`, `fromtask`, `totask`, `timeoutfail`, the exception and exit types, and the public
  accessors for an `Exit`. R10's reproducer and ADR-0008 §5 use them, a Source adapter cannot run
  `runchunks` without `run`, and an `Exit` is useless without its accessors. Nothing
  outside R10 and ADR-0008 is pinned: `fork`, scopes, `bracket`, schedules, the operators and
  the other run functions stay PROVISIONAL.
- **Knock-on edits:** `contracts/README.md`'s "Obligations" bullet names chui-core's obligations
  instead of chui-types'; `contracts/chui-core.md`'s "Purity and effect conventions" points at
  CT-004 and CT-005 instead of the removed "Obligations" section. Proposed copies are next to the
  others.
- A contract ADR is needed (ADR-0010; the change table): new stable IDs `since=0.0.1`, as
  ADR-0014 did for CF-011 to CF-017. The draft calls it ADR-0015, shared with R14.

## History
- 2026-10-20 open: drafted in the ChuiTypes phase-4 lane's report (HANDOFF "Decisions taken"
  item 6; ADR-0008 Consequences), filed by the coordinator lane requests-p4p3. Proposed text
  checked: `contracts/check.jl` on a copy of `contracts/` with it, 0 errors on 1.13.2 and
  1.10.12 (`chui-types.md: 7 entries, 5 stable, IDs unique+sequential: true`). Every promise
  in CT-004 to CT-007 was checked by a scratch script against ChuiTypes main `6ee5fac` on
  1.13.2: 23/23 after one fix. The orphan count rises only when the fiber is already waiting on
  the task; the first run gave `Evaluated: 0 == 1`.
- 2026-10-20 critic round 1 (ACCEPT WITH FIXES): four CT promises in the draft were false at
  `6ee5fac`, each shown RED by a one-line command and confirmed by this lane.
  - B1: `fromtask` maps `EffectFailed(e)` to `Fail(e)` and `Cancelled()` to `Interrupted`;
    the run printed `Failure(Fail(42))`.
  - B2: `interrupt!` cancels forked fibers, not ones made with `start`; the started fiber was
    still running.
  - B3: `timeoutfail` fails only after the interrupted effect stops; the run took 4.97 s
    against `d = 0.5`.
  - B4: `maxelements` is checked per chunk; the run read 1024 elements under `maxelements = 10`.

  The entry text was corrected for all four. The new claims passed 16/16 in a second script. The
  docstrings and ChuiTypes ADR-0008 that state the old claims are request R16. CT-006 is renamed
  "A bounded stream is snapshotted by `runchunks`", because ChuiTypes itself provides no
  Source.
