# ADR-0009: Shared vocabulary across the Chui packages

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint); §1, §5 and Consequences amended
  2026-10-20 (see "Amendment 2026-10-20"). Items 1, 3 and 4 are the user's, from the ChuiCore
  phase-1 ★. Item 2's `neutral` change was approved by the lead and confirmed by the user at the
  contract ★ (2026-10-20). §2's wording amended 2026-10-20 (see "Amendment 2026-10-20: §2's
  wording"), proposed by the lead; confirmed by the user at the ChuiFrames contract ★ (2026-10-20).
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem

## Context

Users should learn one grammar for the whole family. The prototype (`DESIGN.md` §2–§3) uses `⨟`
for left-to-right composition, `c.x` for deferred column references, Tables.jl and Arrow, and
monoid aggregation. Verified facts:
- **`⨟`** (U+2A1F, `\bbsemi`) has precedence 12 (like `∘` and `*`, above `|>` at 9) and is
  left-associative. Base does not define it on 1.11.7 or 1.13.2, or in the source of 1.10, 1.12,
  1.13 or master (E-01, E-02, E-23).
  - **Precedence gotcha:** `c.x .> 3 ⨟ g` parses as `c.x .> (3 ⨟ g)`, and `x |> f ⨟ g` as
    `x |> (f ⨟ g)` (E-23). Docs must parenthesise mixed expressions.
- **CompositionsBase.jl** 0.1.2 exports `⨟` as an alias of `opcompose`, its ASCII name
  (`g ⨟ f == f ∘ g`). It has no dependencies and **11 registered dependents**, including Accessors
  and Transducers (E-03, E-28). A second, different `⨟` binding would make a bare `⨟` ambiguous
  for anyone who loads both.
- **`c` as an exported binding** (E-24): on 1.10/1.11, a top-level `c = 1` after `using ChuiFrames`
  and a first use of `c` errors ("cannot assign a value to imported variable"). On 1.13.2 it
  silently shadows `c`. With an explicit `using ChuiFrames: c`, reassignment errors on both.
- `IO`, `Task`, `Ref` and `Some` are exported by Base or Core on every supported Julia (on 1.10, `IO`, `Task` and `Ref` only by Core; E-34).

## Decision

1. **`⨟`: one binding, owned by ChuiCore**, meaning `(f ⨟ g)(x) == g(f(x))`.
   **Recommendation:** ChuiCore extends `CompositionsBase.:⨟`/`opcompose` (taking it as a
   dependency) rather than defining a new binding, and re-exports only those two names from it.
   ChuiCore's own ADR confirms. Downstream packages only **add methods** (e.g.
   `Step ⨟ Step` → `Pipeline`). The law is behavioural, `(f ⨟ g)(x...) == g(f(x...))`; what
   `f ⨟ g` returns is not promised (`chui-core.md` CC-001).
2. **`c.x` grammar, owned by ChuiFrames, reused by every future package.** Rules from the
   prototype: dotted calls are elementwise; plain calls are reductions; comparisons are not
   overloaded (write `.>`); `c.x |> f` is the whole-column escape hatch.
   *Amended 2026-10-20, confirmed by the user (Amendment "§2's wording" below):* "plain
   calls are reductions" reads "plain calls of the grammar's whole-column functions are
   **whole-column** calls". **How `c` is exported:
   a plain `export c` from ChuiFrames** (option a, decided by the user at the L0 checkpoint,
   2026-10-19), with the reassignment cost above documented. Rejected: (b) opt-in
   `using ChuiFrames: c` only; (c) a submodule (`using ChuiFrames.Grammar`). Changing the export
   style later is a breaking contract change (ADR-0010).
3. **Tables.jl for interchange; Apache Arrow as the columnar format.** Every tabular type implements
   the Tables.jl interface, and every table-accepting function accepts any Tables.jl source. Arrow
   IPC is the on-disk and inter-process format.
4. **One effect *runtime*, in ChuiTypes.** Other effect-like types (lazy IO values, futures, plain
   `Task`/`Channel`) convert to and from it through adapters in ChuiTypes. ChuiFrames' async I/O
   and future packages' side effects run on that runtime. ChuiCore only documents the conventions.
5. **Algebra versus aggregation (owned by ChuiCore):**
   - **Typeclasses:** `Semigroup` (associative `combine`) and `Monoid` (Semigroup + a neutral
     element named **`neutral`**, as in `neutral(::Type{T})`; the name was decided by the user
     at the L0 checkpoint, 2026-10-19; its exact signature is still ChuiCore's to settle).
     *Amended 2026-10-19 (critic S1):* the first draft called it `identity`, which Base exports
     with another meaning, so rule 6 forbids it; `mempty` was considered and rejected as jargon.
     *Amended 2026-10-20:* the signature is settled as `neutral(m)` on an instance value, with
     `neutral(::Type{T})` as closed sugar (Amendment, item 3).
   - **Name clash, resolved at the L0 checkpoint (2026-10-19):** the protocol's
     `partial(agg, acc, chunk)` and brief 10's partial-application helpers cannot share the name
     inside ChuiCore. Decided (option a): the aggregation protocol **keeps `partial`**, and
     partial application is named **`papply`**. Rejected: renaming the protocol function to
     `absorb`/`step!`. `papply`'s signature stays PROVISIONAL in `chui-core.md`'s composition item
     until ChuiCore's composition ADR.
   - **Aggregation protocol** `Aggregator`: `init(agg)` is a *factory* (a fresh accumulator per
     partition), plus `partial(agg, acc, chunk)`, `combine(agg, a, b)` and `final(agg, acc)`.
   - **Trait `iscommutative(agg)::Bool`** (default `false`). Executors must respect it: a
     non-commutative aggregator is combined in partition order. Shuffles and hash repartitioning
     reorder rows, so they must keep an order key or fall back to sequential combination.
   - **Floating point:** float `combine` is only approximately associative (E-34, E-36), so laws on
     float results use one per-aggregator tolerance scaled to the data (e.g. `√eps·sum(abs, v)`
     for sums), defined once in `chui-core.md` CC-004; Base's default `isapprox` is too strict.
     The laws are stated over fresh accumulators per use, because `partial`/`combine` may mutate.
   - **Empty input:** where Base returns a value on an empty `Vector`, `final(agg, init(agg))`
     returns the same value (`isequal`). Where Base throws, ChuiCore throws one fixed, documented
     type on every Julia (`ArgumentError` or `BoundsError`, below; the B2 policy, confirmed by the
     user at the L0 checkpoint), because Base's own type changes between
     versions (`maximum(Float64[])` is a `MethodError` on 1.10 and an `ArgumentError` on 1.13;
     E-34). `ReduceM` and `MapM` are exempt from matching Base. Partitions may be empty, so
     aggregators without an identity accumulator (the semigroups **and Moments**, E-36) carry an
     internal "no value yet" state that `combine` treats as identity.
     *Amended 2026-10-19 (critic B2, B3, S17).*

   | Built-in | Class | Commutative | Empty input → |
   |---|---|---|---|
   | Sum, Prod, Count, CountTrue, AnyM, AllM | Monoid (approximate for floats) | yes | 0, 1, 0, 0, false, true |
   | Max, Min, Extrema | Semigroup (no identity) | yes | throws `ArgumentError` (on every Julia) |
   | First, Last | Semigroup | **no** | throws `BoundsError` |
   | Mean | Aggregator: monoid (sum, n) + `final` | yes | NaN |
   | Moments (var, std) | Aggregator: Chan merge with a "no value yet" state + `final`; **approximate** associativity | yes | NaN |
   | ReduceM(op) | declared by the user; default Semigroup, non-commutative | as declared | throws `ArgumentError` unless the user declares a neutral element; not compared with Base |
   | MapM(f, inner) | as `inner` | as `inner` | as `inner` on empty input; not compared with Base |
6. **Naming:** verbs are lowercase dplyr-style; types are CamelCase; the only exported single-letter
   name is `c`. **No exported name may collide with a Base, Core or standard-library export** (e.g.
   brief 20's `IO` and `Task` need other names in ChuiTypes' ADR). ChuiCore's banner reports any
   remaining conflicts. A method a package adds to a Base function takes an argument of a type
   that package owns (no piracy); a verb with no such argument gets its own name
   (`chui-frames.md` CF-009).
7. **Input to the `chui-frames` Source contract:** the prototype's `schema` and `partitions` reuse
   names from Tables.jl (`Tables.schema`, `Tables.partitions`; not exported, but confusing). The
   contract must either use distinct names or extend Tables' functions consistently. It must also
   choose between a **bounded-only v0** and a **streaming variant**, because ChuiTypes streams are
   unbounded.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| `∘` only | Right-to-left reading fights pipelines. Both stay available. |
| `|>` chains only | They produce no value that can be inspected, optimized or run lazily. |
| `>>` as composition | Base's bit shift; overloading it for functions is confusing. |
| A fresh ChuiCore `⨟` binding | Clashes with CompositionsBase's export (E-03, E-28). |
| "Exactly one effect type" | Brief 20 asks for IO, a ZIO-style effect, futures and Task-like types; one runtime with conversions is the coherent version. |
| Opt-in `using ChuiFrames: c`, or a `ChuiFrames.Grammar` submodule | Avoids the reassignment cost (E-24) but makes the core grammar a second import; the user chose a plain export at L0. |
| Protocol function renamed `absorb`/`step!` (freeing `partial` for partial application) | `partial` is the established name in the aggregation design; the user chose `papply` for partial application at L0. |
| Empty-input errors that follow Base's type on each Julia version | Base's type changes between versions (E-34), so callers could not catch one type; the user chose fixed types (B2) at L0. |
| Calling Max/Min/First/Last monoids | They have no identity element; treating them as monoids hides the empty-input case. |

## Consequences

- Taking rule 1's recommendation makes CompositionsBase ChuiCore's first dependency (a ChuiCore dependency ADR).
- Contracts list `⨟`, `c`, the Tables.jl guarantee, the Aggregator protocol and the effect runtime.
- `c` is a plain export, so `chui-frames.md` promises it as stable; users who reassign `c` at
  top level get an error on 1.10/1.11 and silent shadowing on 1.13 (E-24), which the ChuiFrames
  docs must say.
- *Superseded 2026-10-20 (Amendment, item 1):* ~~ChuiCore exports `partial` (protocol), `papply`
  (partial application) and `neutral` (monoid element).~~ ChuiCore exports `papply`; `partial`
  is public, not exported. `neutral` is proposed as public, not exported, pending ★ Q3
  (Amendment, item 2). None of the three is exported by Base or Core on 1.10.12 or
  1.13.2 (E-37); standard-library exports are checked by ChuiCore's banner (rule 6).

## Verification

- E-01/E-02/E-23 (`⨟` on 1.11.7 and 1.13.2), E-03, E-28 (dependents), E-24 (`c`), E-34 (Base/Core exports, empty reductions on 1.10 and 1.13, float associativity), E-36 (tolerance counterexamples, Moments with an empty side), E-37 (parse shapes, `public` on 1.10, name availability), E-38 (DataFrames exports `combine`).
- UNVERIFIED: which of CompositionsBase's 11 dependents re-export `⨟`.

## Revisit when

- ChuiCore's composition ADR decides on CompositionsBase.
- Base ever defines `⨟` (re-check each new Julia minor).

## Amendment 2026-10-20: export tiers, `neutral`'s signature, the `⨟` binding

Items 1, 3 and 4 were decided by the user at the ChuiCore phase-1 ★ (2026-10-20), accepting
ChuiCore ADR-0001, 0005 and 0006. Item 2's `neutral` change is the lead's, approved on the
evidence of ChuiCore's phase-2 clash probe, and confirmed by the user at the contract ★
(2026-10-20). The decisions above stay as
written; this section records what replaces or settles them.

1. **Three export tiers replace the Consequences line "ChuiCore exports `partial`"** (ChuiCore
   ADR-0005).
   - **Exported:** a short vocabulary. **Only names that pass the clash-list test below may be
     exported; passing it does not export a name** (`init` and `partial` pass and stay public).
     Today the vocabulary is `⨟`, `opcompose`, `papply`, the law-kit stubs, and the
     constructor-class operations and traits whose final names pass. `neutral` is not on it
     (item 2).
   - **Public, not exported** (`@compat public`; written `ChuiCore.x` or imported by name):
     - the aggregation protocol `init`, `partial`, `combine`, `final`, `iscommutative`;
     - the built-in aggregators;
     - the transducer substrate, optics, recursion schemes, free monads and laziness;
     - the hooks downstream code extends (`AlgebraClass`, `default_monoid`, `constructorclass`, …).
   - **Internal:** everything else.
   - **Exports must pass a named clash-list test.** A name may be exported only if no module on
     the list exports it as a different binding. The list is Base, Core, `Base.Iterators`, the
     standard libraries of CC-010, and these packages: DataFrames, Transducers, Accessors,
     Setfield, Functors, TypeClasses, ConstructionBase and CompositionsBase (except its `⨟` and
     `opcompose`). It is a `:quality` test in its own environment, run on stable, and the list
     grows only by ADR. For ChuiCore this tightens rule 6, which still binds every package.
   - Why not export `partial`: it would split the four-function protocol. `partial` would be
     bare, while `combine` must stay qualified, because DataFrames exports `combine` (E-38).
2. **Consistency with the L0 decisions.**
   - `papply` keeps its name and is exported. `partial` keeps its name; L0 decided the name, and
     only its export changes.
   - `c` stays a plain ChuiFrames export: it is outside ChuiCore's tiers.
   - **`neutral` keeps its name, but it becomes public, not exported** (approved by the lead,
     confirmed by the user at the contract ★, 2026-10-20). The clash test wins over ChuiCore ADR-0005 rule 3's list.
     - **The probe.** ChuiCore's phase-2 lane ran ADR-0005's clash test on Julia 1.13.2 against
       DataFrames 1.3.6, Functors 0.4.12, TypeClasses 1.1.0, Transducers 0.4.85, Accessors
       0.1.45 and Setfield 1.1.2. TypeClasses exports `pure`, `ap`, `neutral`, `combine`, `curry`
       and `Identity`; DataFrames exports `combine`; Functors exports `fmap`.
     - **Result.** `neutral`, `curry`, `pure`, `ap` and `fmap` are proposed as **public, not
       exported**. The lead approved this on 2026-10-20; the user confirms at ★ Q3.
     - **Evidence.** The lead's report of the probe, and `src/names.jl` lines 5–7 on ChuiCore's
       `feat/phase2-traits` branch (commit 58bad5d). Not yet in ChuiCore's research log.
     - **Change to L0.** This reverses the L0 Consequences line "ChuiCore exports … `neutral`".
       The name itself, which is what L0 decided, is unchanged.
     - **ChuiCore follow-up.** ChuiCore ADR-0005 §3 still lists `neutral` as exported, so it needs
       its own amendment, written in ChuiCore.
     - **Rejected:** a named exception for `neutral`, and dropping TypeClasses from the list.
       Either would let a bare `neutral` become ambiguous for users who load TypeClasses, so
       `using ChuiCore, TypeClasses` would still break it.
3. **`neutral`'s signature is settled** (ChuiCore ADR-0001, dictionary passing). §5's
   `neutral(::Type{T})` is no longer the primary form.
   - **Primary form:** `neutral(m)` on an instance value `m` (`Sum()`, a downstream aggregator).
     It exists only where the carrier has a true identity, and it returns a fresh value on every
     call.
   - **Refinement:** `neutral(m, ::Type{T})` is optional.
   - **Sugar:** `neutral(::Type{T}) = neutral(default_monoid(T), T)` is **closed sugar**.
     Downstream packages declare `default_monoid(::Type{T})`, and never a `neutral(::Type{T})`
     method. Numbers have no default.
   - `combine(m, a, b)` takes the instance first. ChuiCore defines no 2-argument `combine`.
4. **§1's recommendation is confirmed** (ChuiCore ADR-0006). ChuiCore depends on CompositionsBase
   (`"0.1.2"`) and re-exports exactly `⨟` and `opcompose`. The "Revisit when" trigger "ChuiCore's
   composition ADR decides on CompositionsBase" has fired and is closed by this item.
   - "Downstream packages only add methods" now carries an arity rule (ADR-0012): Chui-added
     methods take two arguments. The exceptions are a downstream's closing varargs method and
     CompositionsBase's variadic fallback.
5. **Contract text** for items 1, 3 and 4 is proposed in ADR-0012, for the user to apply to
   `contracts/chui-core.md` (T3).

**Alternatives rejected** (beyond ChuiCore ADR-0005's own table):

| Alternative | Why rejected |
|---|---|
| Keep the Consequences line (export `partial`) | It splits the protocol across tiers, as item 1 says. The user accepted the tiers. |
| Export the whole protocol, `combine` included | A bare `combine` becomes ambiguous for every DataFrames user (E-38). |
| Keep `neutral(::Type{T})` as the primary form | Allows one monoid per type (ChuiCore ADR-0001 F2) and needs a second mechanism beside CC-004's instance-first `combine`. |

**Verification.** ChuiCore ADR-0001 (F2, F5, F9), ADR-0005 (Context: the clash measurements, and
TypeClasses' exports read from the installed source), ADR-0006 (`docs/research/compositionsbase.md`);
E-37, E-38; ChuiCore's phase-2 clash probe (item 2). UNVERIFIED: that probe on 1.10, and at
other versions of the listed packages.

**Revisit when.** The user revisits the `neutral` export at the next checkpoint. Also when ChuiCore's conflict banner or
`integration/` reports a clash with an exported name, or the user takes ChuiCore ADR-0005's
`Prelude` alternative.

## Amendment 2026-10-20: §2's wording

**What changes** (in force: confirmed by the user 2026-10-20, ADR-0014 ★ Q5). §2's rule
"plain calls are reductions" reads "plain calls of the grammar's whole-column functions are
**whole-column** calls": such a call on a column expression receives the whole column (or the
group's slice), and returns either one value or one value per row. Other plain calls are not
promised (`chui-frames.md` CF-006) and may silently return constants (CF-005's known cost).

**Why.** ChuiFrames ADR-0002 rule 9 (accepted 2026-10-20, ChuiFrames main c5db1cb):
- `lag(c.x, k)` and `lead(c.x, k)` are plain calls, as are the running operations
  `cumsum(c.x)`, `cumprod` and `accumulate`.
- They return **one value per row**, evaluated per group, so they are not reductions.
- Dotting them is wrong: `cumsum.(c.x)` silently builds 0-dimensional arrays (ChuiFrames GR-14).
- ChuiFrames ADR-0002 calls this "a stated exception to ADR-0009 §2"; this amendment makes it the
  rule instead of an exception.

**What does not change.**
- Dotted calls are still elementwise (CF-003).
- Plain operators are still not overloaded (CF-005).
- `c.x |> f` is still the escape hatch for any function the grammar does not cover (CF-006).
- `chui-frames.md` CF-004 keeps its title and text: it promises only what *reductions* do. The
  per-row whole-column calls are PROVISIONAL there until phase-2 parity fixes their names
  (ADR-0014).

**Who decides.** Proposed by the lead with ADR-0014; confirmed by the user at the ChuiFrames
contract ★ (2026-10-20, ADR-0014 Q5).
It changes no contract entry.

**Verification.** ChuiFrames ADR-0002 rule 9 and GR-14 (`docs/research/grammar.md`), read on
ChuiFrames main c5db1cb.
