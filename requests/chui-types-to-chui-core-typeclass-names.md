# Typeclass operation names and trait encoding (R1)

- **From → to:** chui-types → chui-core
- **Status:** open            <!-- partly answered by ChuiCore ADR-0001; see History -->
- **Urgency:** soon
- **Contract IDs affected:** PROVISIONAL ("Typeclass trait encoding"); CC-004 (`combine`), CC-013 (proposed, ADR-0012)
- **Adapter used meanwhile:** `ChuiTypes.Upstream` in `src/upstream.jl` (ChuiTypes ADR-0004 §1–2): local stand-ins such as `flatmap`, `ap`, `fold`
- **Reproducer:** in an environment with the ChuiCore snapshot under test, `julia --startup-file=no -e 'using ChuiCore; ok = all(n -> isdefined(ChuiCore, n), (:fmap, :pure, :ap, :chain)); println(ok); ok || exit(1)'` (the names are ChuiCore's phase-2 draft; replace them with the final ones) — RED today: no ChuiCore snapshot is registered, so `using ChuiCore` fails. GREEN when every Functor/Applicative/Monad operation ChuiTypes needs is defined and documented. Not run by this lane.

## Problem
ChuiTypes' data types (`Option`, `Either`, `Validation`, `NonEmpty`, `LazyList`, `Reader`, `Writer`, `State`, `Effect`) need typeclass instances. It needs the operation names, the instance declaration form, and a semigroup operation distinct from CC-004's three-argument `combine` (ChuiTypes ADR-0004 §7, R1).

## Proposed API
Already answered by ChuiCore ADR-0001 (accepted 2026-10-20):
- Semigroup/Monoid instances are values: `combine(m, a, b)` on an instance value, and a fresh `neutral(m)`.
- Constructor classes are Holy traits on an owned constructor tag: `constructorclass(::Type{T})`, with value-less operations taking the tag first (`pure(tag, x)`).
- ChuiTypes' stand-ins must follow this encoding.

**Still open:** the final operation names for Functor, Applicative and Monad.
- ChuiCore's phase-2 draft uses `fmap`, `pure`, `ap` and `chain`. Of these, `fmap`, `pure` and `ap` are public, not exported (ADR-0009 Amendment, item 2).
- Names are final when ChuiCore's phase 2 lands.

## History
- 2026-10-20 open: drafted by the ChuiTypes phase-1 lane (ChuiTypes ADR-0004 §7, main 455c085); filed by the coordinator lane eco-amend for the lead. Partly answered at filing by ChuiCore ADR-0001.
