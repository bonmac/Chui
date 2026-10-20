# Public recursion schemes over a user-owned plan functor: `cata`, `ana`, `para` and `Fix` (R6)

- **From → to:** chui-frames → chui-core
- **Status:** open            <!-- partly answered by ChuiCore ADR-0001 §3 and ADR-0005 §3; see History -->
- **Urgency:** later (needed for ChuiFrames phase 3, the rule passes)
- **Contract IDs affected:** PROVISIONAL ("Recursion schemes" in `chui-core.md`); new IDs when ChuiCore accepts the API
- **Adapter used meanwhile:** stand-ins for `cata`, `ana` and a paramorphism in ChuiFrames' internal upstream adapter (ChuiFrames ADR-0014 §1; the module is not yet on ChuiFrames main c5db1cb)
- **Reproducer:** with the ChuiCore snapshot under test: `julia --startup-file=no -e 'using ChuiCore, Test; const CC = ChuiCore; @test all(n -> isdefined(CC, n), (:cata, :ana, :para, :Fix))'`, followed by ChuiFrames' own adapter test run against `ChuiCore.cata`/`para` instead of the stand-ins (a tree of an owned node type, with `fmap` registered for it, evaluated by `cata` and rewritten by `para`; both results equal the stand-ins'). RED today: no ChuiCore snapshot is registered, and no branch defines `cata` (checked on ChuiCore main 3054d7c and its phase-2 branches, 2026-10-20). GREEN when both parts pass on 1.10.12 and 1.13.2. Not run by this lane.

## Problem
ChuiFrames' optimizer rewrites the logical plan by ordered rule passes, each to a fixpoint over a
**plan functor**, with catamorphism, anamorphism and paramorphism-style traversals (ChuiFrames
ADR-0003 rule 4). A rule such as predicate pushdown needs each node's **original subtree** as well
as the folded children, which is a paramorphism. ChuiCore owns recursion schemes (ecosystem
ADR-0002 §2), so ChuiFrames must not keep its own copies past release (ChuiFrames ADR-0014
§4–5: `/release-check` fails while a stand-in for a ChuiCore-owned piece remains).

The plan nodes are ChuiFrames-owned plain structs (a closed `Union` of node variants, as ChuiCore
ADR-0002 allows for "recursion-scheme base functors (`ExprF`, ChuiFrames' plan nodes)").

## Proposed API
Public, not exported (as ChuiCore ADR-0005 §3 already decides):
- `cata(alg, x)`, `ana(coalg, seed)` and `para(alg, x)`, where `alg` for `para` receives each
  layer with every child paired with its original subtree.
- They work over a **downstream-owned** functor whose `fmap` is registered through ChuiCore's
  constructor-class encoding (`constructorclass(::Type{T})` → tag, `fmap(f, x)` dispatching on
  it; ChuiCore ADR-0001 §3).
- `Fix` for the explicit fixed point, if ChuiCore keeps it. Either encoding (`Fix`, or
  `project`/`embed` over the user's own recursive type) is acceptable to ChuiFrames, as long as a
  plan tree of owned node structs can be traversed **without rewrapping every node** in `Fix`.
- Laws: `cata(embed_alg, x) == x` (identity fold) and the fusion law on sample trees; `para`'s
  original subtree is `===` the input subtree. A law kit or doc test, at ChuiCore's choice.

ChuiFrames does **not** need monadic variants, `hylo`, `apo`, `histo` or `futu` for phase 3.

## History
- 2026-10-20 open: drafted in the ChuiFrames phase-1 report (ChuiFrames ADR-0003 rule 4,
  ADR-0014 §4; main c5db1cb); filed by the coordinator lane frames-reqs for the lead.
  **Partly answered at filing:**
  - **Tier:** public, not exported (ChuiCore ADR-0005 §3: "recursion schemes, free monads,
    laziness (`cata`, `ana`, `hylo`, …, `Fix`, `Coproduct`), whose main consumer is ChuiFrames'
    optimizer").
  - **Functor encoding:** `constructorclass` tags with `fmap(f, x)` dispatching on
    `FunctorStyle` (ChuiCore ADR-0001 §3); `fmap` and `constructorclass` are public, not exported
    (ADR-0012 P6, accepted).
  - **Still open:** the encoding itself (`Fix` vs `project`/`embed`, listed as "Not decided" in
    ChuiCore's phase-1 spec), the phase it lands in, and the final names. ChuiCore's research note
    favours `project`/`embed` over the user's own types (not a decision).
