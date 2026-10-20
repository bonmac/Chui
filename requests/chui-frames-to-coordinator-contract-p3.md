# `chui-frames.md` follows ChuiFrames' phase-2c and phase-3 decisions: drop and frame equality, var/std → missing, lazy entry points, eager replay (R14)

- **From → to:** chui-frames → coordinator (`contracts/chui-frames.md`; T3, the user applies)
- **Status:** open
- **Urgency:** soon (ChuiFrames main `d3bcec8` already behaves this way; CF-004 as written no longer matches it)
- **Contract IDs affected:** Definitions ("Frame equality"); CF-004 (changed); CF-008 (a note); new CF-018; CF-016 (a clarification); PROVISIONAL "The lazy entry points" and "The ChuiTypes stream adapter's API"
- **Adapter used meanwhile:** none needed: ChuiFrames has no consumers yet. Until this lands, CF-004's text contradicts ChuiFrames' `var`/`std` on fewer than two values.
- **Reproducer:** in `<root>`: `julia --startup-file=no -e 's = read("contracts/chui-frames.md", String); i = first(findfirst("### CF-004 ", s)); j = first(findfirst("### CF-005 ", s)); ok = occursin("### CF-018 ", s) && occursin("Statistics.var", s[i:j]) && occursin("drop", s[1:first(findfirst("### CF-001 ", s))]) && occursin("replays", s); println(ok); exit(ok ? 0 : 1)' && julia --startup-file=no contracts/check.jl contracts`. RED today: `false`, exit 1. GREEN once the user has applied the proposed file and `check.jl` reports 0 errors on 1.13.2 and 1.10.12 (the proposed copy already gives `true` and 0 errors on both).

## Problem
ChuiFrames' phase-2c ★ and phase-3 work (merged on ChuiFrames main `d3bcec8`) changed or decided
four things `chui-frames.md` states otherwise or leaves PROVISIONAL:

1. **Frame equality and `drop`.** `group_by(…; drop = false)` is now a field of the frame
   (phase 2c), and `group_by(drop = nothing)` inherits it (phase 3, breaking in ChuiFrames).
   ChuiFrames' `isequal`/`==`/`hash` on frames compare the flag; its `frame_equal`, which is the
   contract's Definition, does not (user decision at the phase-2c ★; `src/frame.jl`). The
   contract does not say which, so a consumer could read "frame-equal" as "`isequal`".
2. **CF-004, `var`/`std` of fewer than two values.** CF-004 says results "agree with
   Base/Statistics". Since phase 3, plain `var(c.x)`/`std(c.x)` of fewer than two values (with
   `corrected = false`: of none) give `missing`, where Statistics gives `NaN`. This matches dplyr's
   `NA` and the null of Polars and DuckDB (ChuiFrames ADR-0002 rule 10 note, user at the phase-2c
   ★; `changelog.d/phase3-lazy.md`, Breaking). `c.x |> var` keeps `NaN` (CF-006).
3. **The lazy entry points are decided.** `lazy`, `collect(q; morsel, threads)`, `optimize`,
   `explain`, `code_lowered`, and "a verb applied to a Source starts a lazy query" are built
   and documented (phase-3 spec §2, ChuiFrames ADR-0003 rule 13). The contract still lists them
   as the prototype's PROVISIONAL names in five places. (The brief called this "CF-017 lazy
   entry points". CF-017 is taken, by the reserved keywords, so this is a new **CF-018**.)
4. **CF-008 and eager replay.** CF-008 promises the same exception type on both paths. ChuiFrames
   meets it by replaying the unoptimized plan eagerly when a lazy run throws (ChuiFrames ADR-0003
   rule 7 note, lead's decision at the phase-3 ★); a lazy failure the replay does not reproduce
   returns the replay's result. Consumers should know a failing lazy query runs twice.

## Proposed API
Contract text, ready to apply: `chui-frames.md` in the lead's scratchpad `contracts-p3p4/`,
with `DIFF.md` (items F0–F5) and the ★ questions:
- **F1** Definitions: an informative paragraph. Frame equality ignores `drop`; ChuiFrames'
  `isequal`/`==`/`hash` are stronger and are not used by contract tests.
- **F2** CF-004: an "Exception" bullet for `var`/`std`; an example line; a Base-only block showing
  Statistics' `NaN`; the `test:` line gains the `missing` cases. **This changes what a passing
  implementation must do**, so ★ Q1 asks for the in-place exception (as ADR-0012 Q1 and ADR-0014
  Q1, on the same grounds: ChuiFrames 0.0.1 is unreleased, no consumers), or retire CF-004 and
  issue CF-019.
- **F3** CF-008: an informative note on eager replay and the R-total rule. The replay covers a
  query as built; a query passed through `optimize` is replayed from its optimized plan, which at
  `d3bcec8` drops pushed filters (R15).
- **F4** new **CF-018** "Lazy queries: `lazy`, `collect`, `optimize`, `explain`,
  `code_lowered`". It covers:
  - the tiers: `lazy`, `optimize`, `explain` and `LazyFrame` are exported, `collect` and
    `code_lowered` are Base methods, and `physical`/`execute` stay internal;
  - results independent of `morsel` and `threads` under CF-008's rules, with `morsel`'s default
    not promised;
  - recording without running, and `collect` of a Source;
  - for `optimize(q)`, agreement only when collecting succeeds. The exception type is not
    promised until R15 lands. Critic round 1, B5: a pipeline whose eager run raises
    `ArgumentError` raised `DomainError` through `collect(optimize(q))`.

  The printers' output stays PROVISIONAL. CF-016's `scan_file` sentence now says it still
  returns the format's Source, and the example comments point at CF-018. `contracts/README.md`
  drops `lazy`/`collect` from its list of PROVISIONAL names.
- **F5** the PROVISIONAL "ChuiTypes stream adapter" bullet points at CT-006 (R11) and R13.
- A contract ADR is needed (ADR-0010): the draft calls it ADR-0015, shared with R11.

## History
- 2026-10-20 open: drafted in the ChuiFrames phase-3 lane's report (frames-p3, reviewer APPROVE
  FINAL at `0734789`; phase-3 plan Part A item 4 "the contract text as a draft request"), filed by
  the coordinator lane requests-p4p3. The proposed text was checked:
  - `contracts/check.jl` on a copy of `contracts/` with it: 0 errors on 1.13.2 and 1.10.12
    (`chui-frames.md: 18 entries, 18 stable, IDs unique+sequential: true`; the new Base-only
    block's three expectations pass);
  - a scratch script against ChuiFrames main `d3bcec8` on 1.13.2: 21/21 claims hold (F1, F2,
    F4).
