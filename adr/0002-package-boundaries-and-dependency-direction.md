# ADR-0002: Package boundaries and dependency direction

- **Status:** Proposed
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem

## Context

Chui is a family of independently versioned packages (`prompts/common.md` §2, §5). Each must
install, test and build its docs alone against *released* upstream versions, so the dependency
graph must be acyclic and stable. More than one package needs these shared pieces:
- the algebra and aggregation protocol (ChuiCore's typeclasses, ChuiFrames' aggregation engine);
- a transducer substrate (ChuiTypes streams, ChuiFrames execution);
- an effect runtime (ChuiTypes, used by ChuiFrames I/O).

## Decision

1. **Dependency edges** (`A -> B` means A depends on B). These are the only hard edges allowed:
   - `ChuiTypes -> ChuiCore`
   - `ChuiFrames -> ChuiCore`
   - `ChuiFrames -> ChuiTypes`
   - `ChuiStats -> ChuiFrames`, `ChuiLearn -> ChuiFrames`, `ChuiSpatial -> ChuiFrames`, `ChuiPlot -> ChuiFrames`
     (each may also depend directly on ChuiCore and ChuiTypes).
   - **Sibling edges:** a future package may depend on a sibling (e.g. `ChuiLearn -> ChuiStats`)
     only through a new ADR that keeps the graph acyclic.
   - **No upward or sideways hard dependencies.** Optional integrations go in package extensions
     (`[weakdeps]` + `ext/`, Julia ≥ 1.9, E-08). This covers integrations between siblings and
     with outside packages.
   - **Adapters between a package and one it depends on live in the downstream package.** In
     particular the adapter that lets a ChuiTypes stream be a ChuiFrames `Source` lives in
     **ChuiFrames itself**, using only ChuiTypes' public stream API. ChuiTypes ships **no**
     extension on ChuiFrames: an upstream extension keyed on a downstream package would make the
     upstream's behaviour depend on, and be tested against, its own consumer.
2. **Where each concern lives:**

   | Concern | Owner | Rule for downstream packages |
   |---|---|---|
   | `⨟` composition, `pipe`, currying | ChuiCore | add methods, never a new binding (ADR-0009) |
   | Typeclasses (Semigroup, Monoid, Functor, …) as Holy traits, plus exported law kits | ChuiCore | run ChuiCore's kits on their own instances |
   | The aggregation protocol (`init` factory / `partial` / `combine` / `final`, plus the `iscommutative` trait) and the generic aggregators | ChuiCore (ADR-0009 §5) | ChuiFrames builds column- and `missing`-aware aggregates *on top* of it and does not redefine it |
   | The transducer substrate (one for the ecosystem) | ChuiCore, as its own implementation; Transducers.jl interop only through an extension | ChuiTypes streams and ChuiFrames execution use only ChuiCore's names |
   | Recursion schemes, free monads, laziness, optics | ChuiCore | ChuiFrames' optimizer uses them |
   | The name-conflict banner utility | ChuiCore | every package reuses it |
   | Data types, the **one effect runtime**, futures, streams | ChuiTypes | other effect-like types convert to its runtime (ADR-0009 §4) |
   | `c.x` expressions, verbs, plans, the Source/Sink interface, tabular storage | ChuiFrames | future packages reuse `c` and `Source` |
   | Statistics, models, spatial data, plots | future packages | tidy data in and out, via Tables.jl |
3. **Placement rule for new shared machinery:** put it in the *lowest common ancestor* of its users
   in the graph above. Never put it in a downstream package that an upstream package would then need.
4. **Transducers.jl is not a hard dependency of ChuiCore.** Version 0.4.85 has 11 direct and about
   20 transitive registered dependencies (E-27), which breaks ChuiCore's tiny dependency budget.
   ChuiCore keeps its own small substrate (the prototype's ~60 lines, `DESIGN.md` §3.5), with the
   same names. Interop with Transducers.jl goes in a `ChuiCoreTransducersExt` extension.
   **This ADR overrides brief `10-chui-core.md`, which says "decide in an ADR whether the shared
   transducer substrate lives here (own implementation, or adopting Transducers.jl)".** The location
   and "no hard dependency" are decided here. ChuiCore's own ADR still designs the substrate.
5. **Law kits must not make test libraries hard dependencies of ChuiCore.** ADR-0007 §2 lists the
   packaging options.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| One monorepo / one package | Contradicts the independent-versioning requirement (`common.md` §2). |
| Transducers in ChuiFrames, reused by ChuiTypes | ChuiTypes would depend on ChuiFrames: a cycle. |
| Transducers in ChuiTypes | ChuiCore's laziness and fold combinators could not use them; ChuiCore is the lowest common ancestor of the users. |
| Adopt Transducers.jl as a hard dependency | Its ~20 transitive dependencies (Accessors, BangBang, Tables, …; E-27) would load into every Chui package. |
| Monoids or the aggregation protocol in ChuiFrames | ChuiCore's algebra (Foldable, law kits) needs them; two copies would drift. |
| A separate micro-package for monoids and transducers | A fourth repo to version and release, with no consumer that ChuiCore does not already serve. Revisit if ChuiCore outgrows its TTFX budget. |

## Consequences

- Releases happen in graph order: ChuiCore, then ChuiTypes, then ChuiFrames, then the future packages (`common.md` §5).
- Requests for shared machinery queue up on ChuiCore and go through `requests/` (ADR-0010).
- ChuiCore's dependency budget must stay tiny, since everything loads it.

## Verification

- E-08: extensions and weakdeps need Julia 1.9+ (Pkg docs via Context7).
- E-27: Transducers.jl's dependency closure, computed from the local General snapshot.
- The ownership choices are design decisions, not factual claims.

## Revisit when

- A future package needs something that only a sibling provides.
- ChuiCore's measured load time or TTFX exceeds its budget (then consider splitting it).
- Transducers.jl slims its dependency tree, or ChuiCore's substrate turns out to need most of its features.
