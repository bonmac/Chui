# Memoised thunks for LazyList (R5)

- **From → to:** chui-types → chui-core
- **Status:** open
- **Urgency:** later
- **Contract IDs affected:** PROVISIONAL ("Laziness")
- **Adapter used meanwhile:** ChuiTypes' own memoised cell inside `LazyList` (ChuiTypes ADR-0001), to be replaced if ChuiCore ships one
- **Reproducer:** with the ChuiCore snapshot: `julia --startup-file=no -e 'using ChuiCore; n = Ref(0); t = ChuiCore.Lazy(() -> (n[] += 1; 42)); (ChuiCore.force(t), ChuiCore.force(t), n[]) == (42, 42, 1) || exit(1)'`. The names `Lazy`/`force` are placeholders (free names, ChuiCore `law-kits-modules-names.md` L-2). RED today: no snapshot, and no laziness API. GREEN when a memoised thunk evaluates its body once, on both supported versions, including from two tasks. Not run by this lane.

## Problem
ChuiTypes' `LazyList` needs a memoised thunk: evaluated at most once, with the value cached and safe to force from several tasks. ChuiCore's PROVISIONAL "Laziness" item may provide one. If it does, `LazyList` should reuse it rather than keep a second implementation.

## Proposed API
- A memoised thunk type with a force function.
- It is forced at most once. ChuiTypes ADR-0001 §7 needs that much for its memoised lazy cons.
- *Added by the filing lane, for ChuiCore to decide:* whether "at most once" also holds under
  concurrent `force` from several tasks, and whether a body that throws is retried or cached.
- Names and placement are ChuiCore's to decide (public, not exported, per CC-013 as proposed).

## History
- 2026-10-20 open: drafted by the ChuiTypes phase-1 lane (ChuiTypes ADR-0004 §7, main 455c085); filed by eco-amend for the lead.
