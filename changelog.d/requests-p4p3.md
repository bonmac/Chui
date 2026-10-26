- **Added:**
  - Requests R11–R14, from the ChuiTypes phase-4 and ChuiFrames phase-3 lanes, filed in `requests/`
    and indexed (2026-10-20):
    - R11, ChuiTypes → coordinator: CT-004 to CT-007 (run and cancel, the Task and Channel
      adapters, the stream snapshot `runchunks` under ChuiTypes ADR-0008, `withbatches`) with
      their export tiers, and the "Stream as a ChuiFrames Source" amendment (T3);
    - R12, ChuiTypes → factory: dod.jl tiers a public-API change that only edits export lines
      as T1;
    - R13, ChuiTypes → ChuiFrames: the stream Source takes one snapshot at construction, bounded
      by `maxelements` and wrapped in `timeoutfail`;
    - R14, ChuiFrames → coordinator: `chui-frames.md` after phases 2c–3 (frame equality and
      `drop`, CF-004 `var`/`std` of fewer than two values → `missing`, new CF-018 for the lazy
      entry points, a CF-008 note on eager replay) (T3).
    - The proposed contract text for R11 and R14 is outside the repo, for the user to apply.
  - Requests R15 and R16, found by the critic's review of that contract text:
    - R15, to ChuiFrames: `collect(optimize(q))` replays the optimized plan, which ignores pushed
      filters, so a failing query can raise a different exception from eager;
    - R16, to ChuiTypes: the `interrupt!` and `runchunks` docstrings and ADR-0008 §2 overstate
      what `interrupt!`, `maxelements` and `timeoutfail` do.
- **Changed:**
  - R10 accepted: ChuiTypes main `6ee5fac` builds the run, cancel, adapter and bounded-Source
    path. Its reproducer is corrected: it used `fork`, an effect, where it needs `start`, which
    returns a `Fiber`. R10 stays open until ChuiFrames drops its Task shim.
