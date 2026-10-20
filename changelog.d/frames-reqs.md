### Added

- ADR-0014 (Proposed): `chui-frames.md` follows ChuiFrames' accepted phase-1 ADRs (2026-10-20).
  - New stable entries CF-011 to CF-016 for the Source/Sink interface (ChuiFrames ADR-0004
    rules 1–5 and 7–10): four required Source methods, `Tables.Scan` pushdown with a residual,
    conservative statistics pruning, transactional sinks, bounded-only v0, one format registry.
  - New stable entry CF-017: `mutate` and `summarise` reserve their option keywords (ChuiFrames
    ADR-0002 rule 14).
  - In-place clarifications of CF-001 (DataAPI interop methods are out of scope), CF-005 (the
    `string`/`hash` silent constants; `c.x == missing` is `false`) and CF-008 (group-key order is
    not `arrange` order).
  - PROVISIONAL rewritten: the Source/Sink sketch is gone; `code_lowered` shows a rendered
    kernel; ordered levels, source ordering and streaming sources are recorded.
  - The exact text is in the ADR, for the user to apply under T3.
- Requests R6–R10 from ChuiFrames, filed in `requests/` and indexed:
  - to ChuiCore: recursion schemes over a plan functor (R6), the transducer substrate and
    `aggregate` (R7), ownership of `missing`-aware aggregators (R8), the conflict banner (R9);
  - to ChuiTypes: effect run and cancel, Task and Channel conversions, and a stream API for a
    bounded Source (R10).

### Changed

- ADR-0009 §2 amended (2026-10-20, pending the user's confirmation at ADR-0014 ★ Q5): "plain
  calls are reductions" becomes "plain calls of the grammar's whole-column functions are
  whole-column calls", because `lag`, `lead` and `cumsum` return one value per row (ChuiFrames
  ADR-0002 rule 9).
