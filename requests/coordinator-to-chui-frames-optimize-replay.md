# `collect(optimize(q))` replays the optimized plan, which drops pushed filters, so a failing query can raise a different exception type from eager (R15)

- **From → to:** coordinator (found by the critic reviewing R14's contract text) → chui-frames
- **Status:** open
- **Urgency:** soon (CF-018 holds back its `optimize` exception promise until this lands)
- **Contract IDs affected:** proposed CF-018 (`optimize`) and CF-008's replay note (R14)
- **Adapter used meanwhile:** none; the proposed CF-018 promises `collect(optimize(q))` only when it succeeds
- **Reproducer:** in `<root>`: `julia --startup-file=no --project=ChuiFrames.jl -e 'using ChuiFrames; ⨟ = ChuiFrames.Upstream.:⨟; f(v) = any(==(0), v) ? throw(DomainError(0)) : any(==(2), v) ? throw(ArgumentError("two")) : v; p = filter(c.x .> 0) ⨟ mutate(y = c.x |> f); t = (x = [0, 1, 2],); ty(g) = try g(); nothing catch e; typeof(e) end; a = ty(() -> p(t)); b = ty(() -> collect(optimize(p(lazy(t))))); c2 = ty(() -> collect(p(lazy(t)))); println("eager ", a, ", optimized ", b, ", plain ", c2); exit(a === b ? 0 : 1)'`. RED at ChuiFrames main `d3bcec8`: `eager ArgumentError, optimized DomainError, plain ArgumentError`, exit 1. GREEN when `optimized` is `ArgumentError`. (`⨟` is taken from `ChuiFrames.Upstream` because ChuiFrames does not export its stand-in yet.)

## Problem
CF-008 promises the same exception type on both paths, and ChuiFrames keeps that promise by
replaying a failing lazy query eagerly (ChuiFrames ADR-0003 rule 7 note). `collect` replays
`reference(q.plan)` (`src/lazy/collect.jl:24`). For a query returned by `optimize`, that plan is
the **optimized** one, whose `ScanNode` carries the pushed filter, projection and limit, and
`_readall` reads the source whole without applying them. In the reproducer, the filter
`c.x .> 0` has been pushed into the scan. The replay therefore evaluates `f` on the row `x = 0`
and raises `DomainError`, where eager raises `ArgumentError`. On the "engine defect" path the
replay could also return rows the filter should remove. That last point is from reading the
code; it was not run.

## Proposed API
No new API. Either option works:
- `optimize(q)` returns a `LazyFrame` that keeps the original plan for replay; or
- `reference` applies a `ScanNode`'s pushed filter, projection and limit after `_readall`.

Then CF-018 can promise CF-008's full agreement for `collect(optimize(q))`. That would be a
compatible contract edit.

Also stale: `src/io/io.jl:18-19` still says `scan_file`'s "result type is PROVISIONAL until the
lazy entry points land".

## History
- 2026-10-20 open: found by the critic reviewing R14's contract text (B5); the reproducer was
  re-run by the coordinator lane requests-p4p3 at ChuiFrames `d3bcec8`, Julia 1.13.2: RED as
  quoted above.
