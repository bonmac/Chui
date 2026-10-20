# ADR-0012: Chui-added `⨟` methods take two arguments; only the upstream fallback and a downstream closing method are variadic

- **Status:** Accepted (2026-10-20, user at the contract ★): CC-001 amended in place, the section
  "Proposed, needs the user" (P1–P6) accepted in full, stable IDs only for CC-012 and CC-013. The
  user applies the T3 edit to `contracts/chui-core.md`.
- **Date:** 2026-10-20
- **Deciders:** the user (contract files are T3, `risk.toml`)
- **Scope:** ecosystem (contract ADR for `contracts/chui-core.md`, ADR-0010)

This ADR is longer than 120 lines because it carries the exact contract text, ready to apply.

## Context

- **CC-001 (stable) says:** "`⨟` is binary, not n-ary: methods take exactly two arguments".
- **ChuiCore ADR-0006 (accepted 2026-10-20) takes the `⨟` binding from CompositionsBase 0.1.2.**
  - That package's only method is variadic and untyped: `opcompose(fs...) = ∘(reverse(fs)...)`.
  - Taking the binding imports that method. So CC-001's wording is false the moment ChuiCore
    ships (ChuiCore `docs/research/compositionsbase.md`; critic B `cb.jl`, both versions:
    "all methods binary: false").
- **The infix form is unaffected.** `a ⨟ b ⨟ c` parses as `⨟(⨟(a, b), c)` (E-37), so infix
  chains only ever call 2-argument methods.
- **A prefix call takes the fallback.** `⨟(a, b, c)` reaches the variadic fallback and returns a
  nested `ComposedFunction`. Where a downstream type gives `⨟` a non-function meaning
  (ChuiFrames' `Step ⨟ Step → Pipeline`), that result is not the downstream's type.
- **ChuiCore ADR-0006 §3–4** therefore advise such a downstream to add a closing varargs method,
  and request this amendment.
- **ChuiCore's ADR-0001 to 0008 were accepted together (2026-10-20).** They also settle most of
  the contract's PROVISIONAL items, and ADR-0003 §4 states an executor rule that binds ChuiFrames.
  - ChuiCore main (3054d7c) indexes ADR-0001 to 0008 as Accepted.
- **ADR-0010 and `contracts/README.md`:**
  - A breaking change to a stable entry retires the entry and gives the new behaviour a new ID.
  - A decided PROVISIONAL item gets the next free ID (`CC-012`) with `since=<next version>`.
  - Headers match `^### (C[CTF]-\d{3}) (.+)$`, followed by `` `since=… status=…` ``.

## Decision

1. **The arity rule.** CC-001's sentence is replaced by the text below.
   - Every method a Chui package adds to `⨟`/`opcompose` **must** take exactly two arguments.
   - The one exception: a downstream package **may** add a closing varargs method for a type it
     owns, taking three or more arguments. That method **must** satisfy
     `⨟(a, b, c, rest...) == foldl(⨟, (a, b, c, rest...))` under the package's documented
     equality.
   - Among Chui packages and CompositionsBase, the variadic fallback is the only other method of
     another arity. CompositionsBase's InverseFunctions extension adds no `opcompose` methods
     (critic check, 2026-10-20).
   - ChuiCore ADR-0006 §3 keeps its "should" for ChuiFrames: a downstream that gives `⨟` a
     non-function meaning should add the closing method. The contract permits it but does not
     require it.
2. **Recommended: amend CC-001 in place, with no new ID; `since=0.0.1` stays.**
   `contracts/README.md`'s change table has no row for an in-place edit of a stable entry, so this
   is an exception the user grants (★ Q1), not something the table already allows. The case for
   it:
   - The change is compatible. It permits a method that CompositionsBase already defines, and
     code that worked under the old text still works.
   - Nobody relies on CC-001 yet (checked below).
   - ChuiCore 0.0.1 is unreleased (`contracts/README.md`, `releases.md`), so no release ever
     shipped the old wording, and that wording cannot be honoured once CompositionsBase is the
     binding.
   Checked on 2026-10-20: every `test/contracts/USED.md` in ChuiCore, ChuiTypes and ChuiFrames
   (main checkouts and their open worktrees) reads "(none yet)".
3. **Prefix calls get a law.** For callables, `⨟(f₁, …, fₙ)(x) == fₙ(⋯ f₁(x) ⋯)`, `n ≥ 2`, and
   CC-001's test checks it.
4. **Exact replacement text for CC-001.** Only the parts shown change. The header, the `since=`
   line, `names:`, the first two Statement bullets and the precedence bullet stay as they are.

   (a) Replace the Statement bullet that begins "`⨟` is **binary, not n-ary**" with:

   ```markdown
   - **Infix `⨟` is binary:** `a ⨟ b ⨟ c` parses as the nested call `⨟(⨟(a, b), c)` (unlike `*`,
     which parses `a * b * c` as one 3-argument call; E-37), so an infix chain only ever calls
     two-argument methods.
   - **Arity of methods** (ADR-0012). Every method a Chui package adds to `⨟`/`opcompose` takes
     exactly two arguments, with one exception: a downstream package may add a **closing varargs
     method** for a type it owns, taking three or more arguments, and it must agree with the infix
     chain: `⨟(a, b, c, rest...)` equals `foldl(⨟, (a, b, c, rest...))` under that package's
     documented equality, checked by that downstream's CC-002 test. Among Chui packages and
     CompositionsBase, the only other method of another arity is the upstream fallback,
     CompositionsBase's untyped `opcompose(fs...)` (CC-012), which composes one or more callables.
     For a downstream type with no closing method, a prefix call `⨟(a, b, c)` reaches that fallback
     and returns a plain composition of its arguments, not the downstream's type.
   ```

   (b) Append to the **Laws** paragraph:

   ```markdown
   **Prefix calls:** for callables
   `f₁, …, fₙ` with `n ≥ 2`, `⨟(f₁, …, fₙ)(x) == fₙ(⋯ f₂(f₁(x)) ⋯)`, the same as the infix chain.
   ```

   (c) In the **Example** block, insert after the `opcompose(inc, dbl)(3) == 8` line:

   ```markdown
   ⨟(inc, dbl, inc)(3) == inc(dbl(inc(3))) == 9          # true: the variadic upstream fallback
   ```

   (d) Append to the **Parse shapes** (Base only) block:

   ```markdown
   Meta.parse("⨟(a, b, c)").args                     # -> Any[:⨟, :a, :b, :c]
   ```

   (e) Replace the `test:` paragraph with:

   ```markdown
   test: `CC-001 ⨟ composes left to right` — checks `(f ⨟ g)(x) == g(f(x))` for a few Base
   functions and several inputs (never `(f ⨟ g) == g ∘ f`), `opcompose === ⨟`, both associativity
   groupings on sample inputs, the prefix law `⨟(f, g, h)(x) == h(g(f(x)))` for three Base
   functions, and the parse shapes above by comparing `Expr` values, not printed strings.
   ```

## Proposed, needs the user

Not decided by the ★. These texts follow ChuiCore's accepted ADRs and `contracts/README.md`'s
rule that an item gets an ID when the owning ADR accepts it. They also respect ADR-0010's
rejection of "stable IDs for undecided items".

**How the items are split:**
- **New IDs now:** only the items whose names *and* semantics an accepted ChuiCore ADR fixes, and
  which ChuiCore itself marks as ready: CC-012 (ChuiCore ADR-0006 §5) and CC-013 (ChuiCore
  ADR-0005 §5).
- **Obligation:** the `isstateless` executor rule. It binds design now, but its test needs the v1
  transducer set, which phase 3 fixes.
- **PROVISIONAL bullets rewritten:** typeclass encoding, law kits, transducers, optics and ADTs.
  ChuiCore's ADRs say each "becomes an entry after phase 2/3" (ADR-0001, 0003, 0004, 0007,
  Consequences); ADTs have no named sum yet.

**P1. Preamble.** Replace the **Sources**, **Format** and **Qualified names** bullets with:

```markdown
- **Sources:** ADR-0002 (placement), ADR-0004 (versioning), ADR-0007 §2 (law kits),
  ADR-0009 §1, §5, §6 (vocabulary), ADR-0010 (format), ADR-0012 (CC-001's arity rule, CC-012,
  CC-013); ChuiCore's ADR-0001 to ADR-0008 (accepted 2026-10-20). Evidence:
  `research/ecosystem-verification.md` (E-NN).
- **Format:** see [README.md](README.md). Stable entries below; ecosystem rules that bind design
  before their names exist are [obligations](#obligations-not-entries); undecided items are under
  [PROVISIONAL](#provisional), without IDs. CC-003, CC-008 and CC-009 were withdrawn before the
  contract became binding (`status=retired`); their IDs are not reused.
- **Qualified names.** Entries name the protocol functions and built-in aggregators qualified
  (`ChuiCore.partial`, `ChuiCore.Sum`). They are **public, not exported** (CC-013), so
  contract tests use the qualified form; `⨟` and `opcompose` are exported.
```

**P2. A new section before the first `---`** (the obligations format of `chui-types.md`):

```markdown
## Obligations (not entries)

No IDs and no contract tests. Each becomes an entry with the next free ID, and a `test:` line,
when ChuiCore accepts the names it needs (the v1 transducer set is fixed in ChuiCore's phase 3,
ChuiCore ADR-0003 §1).

**Only `isstateless` pipelines run per partition** (ChuiCore ADR-0003 §4, accepted 2026-10-20).
- `ChuiCore.isstateless(xf)::Bool` declares whether a transducer pipeline may run independently
  on each partition. The default is **`false`** (fail-closed). Of ChuiCore's transducers, only
  `Map`, `Filter`, `MapCat`, and compositions made only of those, declare `true`;
  early-terminating transducers (`Take`, `TakeWhile`) and every other stateful transducer are
  `false`. Any transducer type, downstream ones included, may declare `true` only if it keeps
  no state.
- **Every executor** that splits its input into partitions (ChuiCore's `foldparts`, `foldxt` and
  `aggregate`, ChuiFrames' engine, any future package) runs a pipeline per partition **only if**
  `isstateless(xf)` is `true`. Any other pipeline runs as one sequential `foldxl` over the
  partitions flattened in order, with a single `init()`. So a downstream transducer type that
  declares nothing is never run per partition.
- Per-partition runs also require the pipeline and the reducing operation to be pure;
  effectful pipelines use `foldxl`. Partition results are merged in partition order (CC-005).
- Downstream executors should call `foldparts`/`aggregate` rather than re-implement partition
  folding (ChuiCore ADR-0003, Consequences).
- Declaring `isstateless(xf) == true` for a stateful transducer is a bug in that transducer.
- Future test, once named: `isstateless` is `true` for `Map(f)`, `Filter(p)` and their
  composition, and `false` for `Take(1)`, `TakeWhile(p)` and a transducer type defined in the
  test with no `isstateless` method.
```

**P3. The retired CC-003 stub:** replace its last two sentences with "ChuiCore ADR-0006
confirmed it on 2026-10-20; it is now CC-012. The ID is not reused."

**P4. Two new entries after CC-011:**

````markdown
### CC-012 `⨟` and `opcompose` are CompositionsBase's bindings
`since=0.0.1 status=stable`

**Statement.** (ChuiCore ADR-0006, confirming ADR-0009 §1.)
- ChuiCore depends on CompositionsBase (`[compat] CompositionsBase = "0.1.2"`) and re-exports
  exactly two of its names, `⨟` and `opcompose`: `ChuiCore.:⨟ === CompositionsBase.:⨟` and
  `ChuiCore.opcompose === CompositionsBase.opcompose`. ChuiCore does not export CompositionsBase's
  other names (`compose`, `decompose`, `deopcompose`, nor its re-export of Base's `∘`).
- So a bare `⨟` resolves, to that one binding, after `using ChuiCore` together with
  `using CompositionsBase`, or with a package that re-exports CompositionsBase's `⨟` (Accessors
  and Transducers do; ChuiCore ADR-0006).
- A check of this compares bindings with `===` and evaluates a bare `⨟`. It never relies on the
  absence of a "both … export" warning: 1.10 prints one when two different bindings clash, but
  1.13 prints nothing and fails only at the use (E-37).
- The variadic generic fallback is CompositionsBase's (`opcompose(fs...)`, CC-001's arity rule).

**Example.**
```julia
using ChuiCore, CompositionsBase
ChuiCore.:⨟ === CompositionsBase.:⨟                 # true
ChuiCore.opcompose === CompositionsBase.opcompose   # true
(sin ⨟ cos)(1.0) == cos(sin(1.0))                   # true: the bare ⨟ resolves
Base.isexported(ChuiCore, :compose)                 # false
```

test: `CC-012 CompositionsBase binding` — in the contract environment (which adds
CompositionsBase): the two `===` identities; in a fresh module, after `using ChuiCore,
CompositionsBase`, evaluating the bare symbol `⨟` returns `ChuiCore.:⨟` (no `UndefVarError`); and
for each name CompositionsBase exports other than `⨟`, `opcompose` and the module's own name,
`!Base.isexported(ChuiCore, n)`. ChuiCore ADR-0006 §5 also names the Accessors and Transducers
cases; they are deliberately left to ChuiCore's own tests, so that downstream contract
environments need not add Accessors and Transducers.

### CC-013 Export tiers: the aggregation protocol and the built-in aggregators are public, not exported
`since=0.0.1 status=stable`

**Statement.** (ChuiCore ADR-0005; ADR-0009 as amended 2026-10-20.)
- Every ChuiCore name is in exactly one tier: **exported**; **public, not exported** (declared
  with `@compat public`: the `public` keyword on Julia ≥ 1.11, a no-op on 1.10, where `public` is
  a `ParseError`; E-37, ADR-0006); or **internal** (no stability promise; no contract entry names
  an internal name).
- **Exported:** a short vocabulary. Only names that pass the clash rule below may be exported;
  passing it does not export a name (`init` and `partial` pass and stay public). This entry
  promises `⨟` and `opcompose` (CC-001, CC-012). `papply` also passes and is intended to be
  exported; its entry, with its
  signature, comes with its PROVISIONAL item below. `neutral`, `curry`, `pure`, `ap` and `fmap`
  fail the rule (TypeClasses and Functors export them; ADR-0009 as amended), so they are public,
  not exported.
- **Public, not exported:** the aggregation protocol `init`, `partial`, `combine`, `final` and
  `iscommutative` (CC-004, CC-005), and the built-in aggregators of CC-007. Downstream code
  writes them qualified (`ChuiCore.combine`) or imports them by name (`using ChuiCore: combine`).
- **Not exported** (each public once named; PROVISIONAL below): the transducer substrate,
  optics, recursion schemes, free monads and laziness helpers. The hooks downstream code
  extends in the typeclass encoding are public too, unless ChuiCore exports a trait name that
  passes the clash rule (ChuiCore ADR-0005 §3).
- **Clash rule for exports:** an exported name is not exported, as a different binding, by Base,
  Core, `Base.Iterators`, the standard libraries of CC-010, or the packages named in ChuiCore
  ADR-0005 §2. ChuiCore's own `:quality` test checks the package list; downstream contract tests
  check the Base and standard-library part (CC-010).
- Moving a name between tiers is a contract change (ADR-0010).

**Example.**
```julia
using ChuiCore
Base.isexported(ChuiCore, :opcompose)      # true
Base.isexported(ChuiCore, :combine)        # false: write ChuiCore.combine
using ChuiCore: Sum, init, partial, final  # or import the public names explicitly
final(Sum(), partial(Sum(), init(Sum()), [1, 2, 3])) == 6   # true
```

test: `CC-013 export tiers` — checks `Base.isexported(ChuiCore, n)` for `⨟` and `opcompose`;
for each of `init`, `partial`, `combine`, `final`, `iscommutative`, `neutral` and each name on CC-007's
`names:` line, checks `!Base.isexported(ChuiCore, n)` and, on `VERSION ≥ v"1.11"`,
`Base.ispublic(ChuiCore, n)`.
````

Neither entry has a `names:` line. Their names are already covered by CC-001 and CC-004 to
CC-007; mapping them again would make every `⨟` user list CC-012 and add CompositionsBase to its
contract environment. A downstream that relies on these rules lists the IDs by hand (as for
CC-010). CC-013 promises only `⨟` and `opcompose` among the exports: `papply`'s signature is
still PROVISIONAL, and the rest of the exported tier is named in phase 2.

**P5. CC-002's `test:` line.** It tests CC-001's closing-method rule. Append, before its final
period:

```markdown
; and, if it defines a closing varargs method (CC-001), that `⨟(a, b, c)` equals
`(a ⨟ b) ⨟ c` under that equality, on sample values
```

**P6. PROVISIONAL.** Delete the bullets "CompositionsBase binding" and "Export list" (now CC-012
and CC-013). Keep "Name-conflict banner", "Purity and effect conventions" and "`missing`-aware
aggregators" unchanged. Add after the section's first sentence:

```markdown
Where ChuiCore's accepted ADRs (2026-10-20) already decide part of an item, the decided part is
recorded below; the item gets its ID when the ADR's own "becomes an entry after phase N" note is met.
```

Replace the remaining bullets, in this order, with:

```markdown
- **Typeclass trait encoding.** *Decided* (ChuiCore ADR-0001): Semigroup, Monoid and
  aggregators are **instance values** (dictionary passing). `combine(m, a, b)` takes the instance
  first; ChuiCore defines no 2-argument or variadic `combine`. `neutral(m)` exists only for
  instances with a true identity on the carrier and returns a **fresh** value on every call, with
  `isequal(final(m, init(m)), final(m, neutral(m)))`; `neutral(m, ::Type{T})` optionally refines
  it (default `neutral(m)`); `neutral(::Type{T}) = neutral(default_monoid(T), T)` is **closed
  sugar**: downstream code declares `default_monoid(::Type{T})`, never a `neutral(::Type{T})`
  method, and numbers have no default. `AlgebraClass(::Type{M})` (`IsSemigroup()`, `IsMonoid()`,
  default `NotAlgebra()`) classifies instances and never gates CC-004/CC-005 executors. Functor,
  Applicative, Monad, Alternative, Traversable, Contravariant, Bifunctor, Profunctor and
  Category/Arrow are Holy traits on an owned constructor **tag** (`constructorclass(::Type{T})`,
  fallback `NoTag()`; an unregistered type gets an `ArgumentError`); Foldable is Base iteration;
  Maybe is Base's `Some{T}`/`nothing`; operations with no value to dispatch on take the tag
  first (`pure(tag, x)`). *Open (ChuiCore phase 2):* the operation and tag names (no new `bind`,
  `flatmap`, `first`, `second`, `empty` or `view`), and the exact instance list. Name decided at
  L0 (ADR-0009 §5): **`neutral`**; `identity` is Base's and `mempty` was rejected as jargon.
  `neutral`, `pure`, `ap` and `fmap` are public, not exported (CC-013).
- **Law kits** (was CC-008). *Decided* (ChuiCore ADR-0007; ADR-0007 §2 as amended 2026-10-20):
  ChuiCore exports method-less stubs (`test_semigroup_laws`, `test_monoid_laws`,
  `test_aggregator_laws`, and one per typeclass); `ChuiCoreTestExt` (trigger `Test`) adds methods
  for a finite collection of samples, `ChuiCoreSuppositionExt` (triggers `Test` and Supposition)
  for a Supposition generator. The instance or tag comes first; each law is an inner
  `@testset "<law name>"` holding one `@test`, counted in the caller's testset; aggregator kits
  take `eq(r₁, r₂, v)`, default CC-004's `≈ᵃ`, other kits `eq(a, b)`, default `isequal`;
  `ChuiCore.default_eq(instance)` is public. Supposition results are asserted with
  `@check record=false db=false` plus an explicit `@test`, and each kit has planted-violation tests that
  run on the LTS job. `Test` and Supposition stay weak dependencies (CC-011). *Open (phase 2):*
  exact signatures and the full list of kits.
- (Name-conflict banner: unchanged.)
- **Composition helpers:** `pipe`, `curry`, partial application, point-free helpers.
  *Name decided at the L0 checkpoint (2026-10-19, ADR-0009 §5, option (a)):* partial application
  is **`papply`**, exported (CC-013), because the aggregation protocol keeps `partial` (CC-004);
  rejected: renaming the protocol function to `absorb`/`step!`. `papply`'s signature (e.g.
  `papply(f, args...)`, reusing `Base.Fix1`/`Fix2`, and `Base.Fix` from 1.12, where they fit) and
  the other helpers stay PROVISIONAL until ChuiCore's composition ADR. None of `partial`,
  `papply`, `absorb`, `step!` is exported by Base or Core (E-37).
- **The transducer substrate API.** *Location* decided by ADR-0002 §4 (ChuiCore's own code;
  Transducers.jl interop only in `ChuiCoreTransducersExt`). *Design decided* (ChuiCore ADR-0003):
  transducers are immutable structs under `abstract type Transducer` (`Map`, `Filter`, `MapCat`,
  `Take`, `TakeWhile`, `Scan`, `Partition`, `Composed`) with **no call method**; a reducing
  function is built by `asrf(xf, op)`; the protocol is `start`/`next`/`complete` with `Reduced`
  for early termination; state lives in the accumulator; `complete` runs exactly once per fold;
  `a ⨟ b` means "a, then b" through CC-012's binding. Folds: `foldxl` (sequential, `init`
  required), `foldparts` (pre-partitioned input, `init` a factory, `merge` required, merged in
  order), `foldxt` (vectors only), `aggregate(agg, xf, parts)` (name provisional) over CC-004.
  All public, not exported (CC-013); `ChuiCore.Map` never aliases `Transducers.Map`. The
  per-partition rule is the [obligation](#obligations-not-entries) above. *Open (phase 3):* the
  v1 set, `aggregate`'s name, the exact signatures.
- **Recursion schemes:** `Fix`, cata, ana, hylo, para, apo, histo, futu, and monadic variants.
  Public, not exported (CC-013).
- **Data types à la carte and free monads:** coproducts, injection/projection, interpreters. The
  coproduct of functors is named `Coproduct` (`Sum` is CC-007's aggregator; ChuiCore ADR-0005).
  Public, not exported.
- **Laziness:** thunks, memoized lazy values, lazy structure combinators. Public, not exported.
- **Optics.** *Decided* (ChuiCore ADR-0004): ChuiCore owns a minimal core, not a dependency on
  Accessors: `Lens` (a property lens through `getproperty` and
  `ConstructionBase.setproperties`; an index lens), `Prism` (`preview(p, x)` returns `Some(v)` or
  `nothing`; `review(p, v)` builds the variant), `ChuiCore.set(x, optic, v)` and
  `ChuiCore.modify(f, x, optic)` in Accessors' argument order; getting is calling the optic;
  composition is Base's (`∘`/`⨟` give a `ComposedFunction`); struct rebuilding uses
  ConstructionBase's `constructorof`. All public, not exported. Interop with Accessors is
  `ChuiCoreAccessorsExt`. *Open (phase 3):* constructors, prism design and laws.
- **The ADT and pattern-matching library choice.** *Decided* (ChuiCore ADR-0002): ChuiCore
  depends on no pattern-matching library (not Moshi, SumTypes or MLStyle); a variant is a plain
  struct; a closed sum is a `Union` alias of variants its package owns, an open sum an abstract
  type; a `Union` alias containing a type its package does not own (`Nothing`, `Some`) gets no
  methods of Base functions; a public test helper lists the members of a closed sum lacking a
  method (blind to catch-all methods). No entry yet: no named sum type exists for downstream use;
  the first one gets an entry when ChuiCore accepts it.
```

**★ for the user:**
- **Q1.** `contracts/README.md`'s change table has no row for editing a stable entry in place, so
  applying the CC-001 text in place (recommended) is an exception the user grants. The
  alternative is to retire CC-001 and give the new text a
  new ID (then CC-012/CC-013 above shift by one)?
- **Q2.** Accept P1–P6 as split (IDs only for CC-012, CC-013), or assign IDs now for the
  monoid-family part of the typeclass encoding as well?
- **Q3.** Confirm that `neutral` is public, not exported. The lead approved this from ChuiCore's
  phase-2 clash probe (ADR-0009 Amendment, item 2); it reverses an L0 Consequences line. If the
  user declines, remove `neutral` from CC-013's statement, its test, and P6's typeclass bullet.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep CC-001 as written and make ChuiCore restrict the fallback | The method is CompositionsBase's; narrowing it from ChuiCore is piracy, and a new binding breaks CC-002 (ChuiCore ADR-0006). |
| Allow any arity for Chui-added methods | Lets downstreams diverge between `⨟(a, b, c)` and `a ⨟ b ⨟ c`; the `foldl` rule keeps one meaning. |
| Require (not permit) a closing method for non-function `⨟` types | A design obligation the contract cannot test generically; ChuiCore ADR-0006 keeps it a "should". |
| Retire CC-001 and issue a new ID | Churns the most-cited ID for an entry no release ever shipped (Decision 2); offered as ★ Q1. |
| IDs now for all items ChuiCore decided | Freezes names that phase 2/3 fix (ADR-0010's rejected "stable IDs for undecided items"). |
| The `isstateless` rule as a stable entry now | Its test needs `Map`, `Filter`, `Take`, whose v1 set phase 3 fixes; obligations exist for exactly this. |

## Consequences

- **T3 edits the user must authorize**, all in `contracts/chui-core.md`:
  - CC-001 (a)–(e), from the ★ decision;
  - P1–P6, if accepted.
  `contracts/README.md` needs no change: the contract version stays v0, since ChuiCore is
  unreleased.
- **ChuiFrames' engine is bound by the obligation (P2):** it calls `foldparts`/`aggregate` or
  checks `isstateless`. Its executor ADR must cite it.
- **Downstream contract environments add CompositionsBase** if they list CC-012.
- **Vendored copies go stale.** ChuiTypes and ChuiFrames carry copies of the contract under
  `test/contracts/` (`chui-core.md`, and in ChuiFrames `chui-types.md`). After the T3 edit, each
  package refreshes its copy in its own commit (ADR-0010 rule 4).
- `since=0.0.1` on CC-012/CC-013 assumes they ship in ChuiCore's first release. The release
  manager corrects `since=` if 0.0.1 ships before phase 3.

## Verification

- ChuiCore ADR-0001 to 0008 (main 3054d7c, `ChuiCore.jl/docs/adr/`; 0008 for the optics rebuild) and
  `docs/research/compositionsbase.md`, `law-kits-modules-names.md`, as cited there; E-23, E-37.
- The assembled file (current `chui-core.md` with every edit above applied, beside unchanged
  copies of the other contract files and ADRs) was checked with `contracts/check.jl` in a scratch
  directory, with 0 errors on both Julia versions: 13 entries, 10 stable, IDs unique and
  sequential; 28 julia blocks parsed, 5 Base-only blocks executed, 18 value expectations checked,
  including the new `Meta.parse("⨟(a, b, c)").args` → `Any[:⨟, :a, :b, :c]`. Versions 1.13.2 and
  1.10.12.
- `Base.ispublic` (CC-013's test): `isdefined(Base, :ispublic)` is `false` on 1.10.12 and `true`
  on 1.11.7 and 1.13.2 (run by this lane, 2026-10-20).
- The `⨟(inc, dbl, inc)(3) == inc(dbl(inc(3))) == 9` example: `true` with CompositionsBase 0.1.2
  on 1.13.2 and 1.10.12, where `length(methods(opcompose)) == 1` (scratch environment, run by this
  lane on 2026-10-20).

## Revisit when

- CompositionsBase changes its fallback (ChuiCore ADR-0006's trigger), or Base defines `⨟`.
- ChuiCore phase 2 or 3 accepts the names a PROVISIONAL item or the obligation is waiting for.
- A downstream needs a second varargs shape (for example, mixed owned and foreign arguments).
