# Package brief: JuntaADT.jl (data types, effects, streams)

The lead session hands this brief to the agents working on **JuntaADT.jl**.
- **Upstream:** it depends on **Junta.jl**, through *released* versions only.
- **Downstream:** JuntaDF and the future packages depend on it.

Lanes for this package edit and commit only in `<root>/JuntaADT.jl`.

**Read first:**
- `docs/agent/ECOSYSTEM.md`.
- `<root>/contracts/junta-core.md`: what you may use from Junta. Carry contract tests for it in `test/contracts/`.
- `<root>/contracts/junta-adt.md`: what you promise downstream.
- `HANDOFF.md`.

## Scope

- **Data types:** `Option`/`Maybe`, `Either`/`Result`, `Validation` (accumulates errors), `These`, `NonEmpty`, `LazyList`, `Reader`, `Writer`, `State`, `IO`.
  - Each implements the Junta traits that apply to it, and passes Junta's exported law-test kits.
- **A ZIO-style effect:**
  - environment + error + success channels;
  - resource safety (`bracket`/`Scope`);
  - retries and schedules, timeouts;
  - structured concurrency on Julia `Task`s, and cancellation that propagates.
  - Also, adapters to and from plain `Task`, `Channel` and exceptions.
- **Futures:** Fluture-style lazy, cancellable futures; Folktale/Monet-style `Task`.
- **Reactive streams (RxJS / Monix / fs2 / ZIO Streams):**
  - cold and hot observables;
  - operators: map, filter, scan, merge, concat, switchMap, mergeMap, debounce, throttle, buffer, window, retry;
  - schedulers, including a virtual-time scheduler for testing;
  - backpressure.
  - Streams must be usable as a JuntaDF **source**: agreed in the root repo through `junta-df.md`'s `Source` interface.
- **Inspiration:**
  - JavaScript: Ramda, Sanctuary, Fluture, Folktale, Purify, Monet, daggy, Underscore/Lodash (lodash/fp), RxJS;
  - Scala: cats, cats-effect, ZIO, fs2;
  - Haskell `mtl`/`transformers`.

## Independence

- **Before Junta's v0.1 release:** build against the Junta contract by depending on the tagged pre-release (`v0.1.0-DEV`) from the personal registry.
  - If there is no tag yet, implement the types and their own logic first, and put a thin adapter layer where Junta's traits will plug in.
- **Missing upstream features:** write a cross-repo request in `<root>/requests/` for the lead to schedule. A JuntaADT lane never edits Junta's code.

## Phases
1. **Research and ADRs:**
   - an encoding of these types that stays type-stable;
   - the effect runtime design (fibers or `Task`s, cancellation semantics);
   - the stream design (push or pull, backpressure).
   - ★ Report to the lead before implementing.
2. **Core data types**, plus laws.
3. **Reader/Writer/State/IO**, and the effect runtime with resource-safety and cancellation tests.
4. **Futures and streams:** marble tests (Rx-style timeline tests) on virtual time; stress tests for leaks and cancellation.
5. **Performance:** allocations and TTFX.
6. **Docs.** Then v0.1.0, after the user confirms; record it in `<root>/releases.md`.

## Done means
- **Laws:** pass for every instance.
- **Effects:** cancellation and resource-safety property tests pass, and stress tests show no leaked tasks.
- **Contracts:** contract tests pass against Junta's latest release.
- **Quality checks:** JET and Aqua are clean.
- **Standalone:** `]test` passes from a fresh clone.
