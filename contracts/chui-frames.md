# Contract: chui-frames (v0)

> **Binding since 2026-10-19** (ADR-0002/0004/0007/0009/0010 Accepted at the L0 checkpoint).
> Stable entries change only through a contract ADR (see [README.md](README.md)).

- **Owner:** ChuiFrames. **Consumers:** ChuiStats, ChuiLearn, ChuiSpatial, ChuiPlot (none exist
  yet; ADR-0002 §1).
- **Contract version:** v0, describing ChuiFrames 0.0.1 (unreleased).
- **Sources:** ADR-0009 §2, §3, §6, §7; ADR-0010 (format, rule 6); ADR-0014 (this file's update
  to ChuiFrames' phase-1 ADRs); ChuiFrames' ADR-0001 to ADR-0004 (accepted 2026-10-20,
  `ChuiFrames.jl/docs/adr/`); the prototype (`reference/prototype/DESIGN.md` §2–§3) for the `c.x` grammar only.
  Where an entry promises more than the prototype does, it says "new work" and cites the probe
  (E-35).
- **Format:** see [README.md](README.md). The Source and Sink interface is CF-011 to CF-016
  (ChuiFrames ADR-0004). Undecided items are under [PROVISIONAL](#provisional).
- **Names in examples and tests.** Verb names (`filter`, `mutate`, `group_by`, `summarise`,
  `arrange`), the frame type, and the lazy entry points `lazy`/`collect` come from the prototype
  and are PROVISIONAL until ChuiFrames' parity matrix and grammar ADR accept them. The *rules*
  below are stable. Contract tests use the names of the ChuiFrames release under test and are
  re-written when an accepted ADR renames them (README, "Tests that need PROVISIONAL names").
  `c` is a plain export of ChuiFrames (CF-010), so `using ChuiFrames` brings it into scope.
  The Source and Sink names (CF-011 to CF-016) are decided by ChuiFrames ADR-0004; whether each
  is exported is not promised, so entries and tests write them qualified (`ChuiFrames.Source`).

## Definitions

**Frame equality.** Two tables `a` and `b` are *frame-equal* when

```julia
isequal(Tables.columntable(a), Tables.columntable(b)) && isequal(groupcols(a), groupcols(b))
```

that is: the same column names in the same order, the same number of rows, elementwise `isequal`
values (`missing` matches `missing`, `NaN` matches `NaN`; element types may differ, since
`isequal([1], [1.0])` is `true`), and the same grouping columns in the same order (none for an
ungrouped table or a plain Tables.jl source). `groupcols` stands for ChuiFrames' accessor for a
frame's grouping columns; its name is PROVISIONAL (the prototype stores them in the field
`groups`). `isequal` on `NamedTuple`s compares names and their order (E-35). ChuiFrames need not
overload `==` on its frame types; contract tests use this definition. CC-002, CF-007 and CF-008
refer to it.

**Approximate frame equality** (used only by CF-008). As frame equality, except that values are
compared elementwise by these rules: `isequal` when either value is `missing` or not a float
(integers, strings, Bools, …); for two floats, `isequal`, or, when the column is computed by a
reduction (a summary column, or an elementwise expression containing a reduction, such as the
window `c.x .- mean(c.x)`), equality within CC-004's float tolerance for that reduction on the
group's input; tuples and `NamedTuple`s (e.g. `extrema` results) are compared recursively,
componentwise.

---

### CF-001 Every frame type is a Tables.jl table; every table input accepts any Tables.jl source
`since=0.0.1 status=stable`

**Statement.**
- Every table type ChuiFrames exports (eager frames, grouped frames, and the result of collecting
  a lazy query) implements the Tables.jl interface: `Tables.istable(T) == true`, and both
  `Tables.columns` and `Tables.rows` work, with `Tables.schema` giving column names and element
  types when they are known.
- Every ChuiFrames function or verb that accepts a table accepts **any** Tables.jl source
  (a `NamedTuple` of vectors, a `Vector` of `NamedTuple`s, a DataFrame, an `Arrow.Table`, …) and
  returns a ChuiFrames table (ADR-0009 §3). **New work:** the prototype accepts only its own
  `Tbl` (a `NamedTuple` input throws `MethodError`, E-35).
- **Scope** (ADR-0014; ChuiFrames ADR-0002 rule 5). "ChuiFrames function or verb" means a
  function ChuiFrames owns. Methods ChuiFrames adds to **another package's** generic function
  (the DataAPI interop methods: `DataAPI.innerjoin`, `DataAPI.groupby`, `DataAPI.describe`,
  `DataAPI.nrow`, …) are not covered. Each of them takes at least one ChuiFrames frame argument,
  because a method for plain Tables.jl inputs would be type piracy. So `DataAPI.innerjoin` on two
  `NamedTuple`s stays a `MethodError`. ChuiFrames' own verbs for the same operations
  (`inner_join`, `group_by`, …) are covered.
- Apache Arrow IPC is the ecosystem's on-disk and inter-process columnar format (ADR-0009 §3).
  Files are read and written through CF-016.

**Example.**
```julia
using ChuiFrames, Tables
t = (a = [1, 2, 3], g = ["x", "y", "x"])        # a Tables.jl column table
f = filter(c.a .> 1)(t)                          # verbs take any Tables.jl source
Tables.istable(typeof(f)) && Tables.columntable(f).a == [2, 3]
```

test: `CF-001 Tables.jl guarantee` — for each frame type the downstream consumes: `Tables.istable`,
`Tables.columns`/`Tables.rows` round-trip to a `NamedTuple` of vectors with equal values; and
each verb the downstream uses gives frame-equal results on a `NamedTuple` of vectors and on a
`Vector` of `NamedTuple`s holding the same data.

### CF-002 `c.x` is a deferred column reference
`since=0.0.1 status=stable`

**Statement.**
- `c` is a singleton whose property access `c.name` (and `getproperty(c, :name)` for computed
  names) builds an expression node referring to column `name`. Building it reads no data and
  needs no table; it is evaluated only when a verb applies it to a table. (Indexing forms such as
  `c[:name]` and `c["name with spaces"]` are PROVISIONAL.)
- Expressions built from `c.x` are immutable values: they can be stored, reused across
  pipelines and tables, and printed.
- The ecosystem has no single-letter export other than `c` (ADR-0009 §6). Future packages reuse
  this `c` and this grammar (CF-002 to CF-006); they never define their own.
- **Known cost** (E-24): on Julia 1.10/1.11, a top-level `c = …` after `c` has been used from
  an import errors; on 1.13 it silently shadows. Documented, not changed by this contract.

names: `ChuiFrames.c`

**Example.**
```julia
using ChuiFrames
e = c.mass ./ c.len          # no data touched yet
p1 = mutate(ratio = e)       # the same node reused in two verbs
p2 = filter(e .> 0.5)
```

test: `CF-002 deferred column` — building `c.x`, `c.x .+ 1` and `sum(c.x)` with no table in
scope succeeds and returns non-`Vector` values; applying the same stored expression to two
different tables gives each table's result.

### CF-003 Dotted calls and dotted operators are elementwise
`since=0.0.1 status=stable`

**Statement.**
- Any broadcast involving a column expression (`f.(c.x, 1)`, `c.x .+ c.y`, `@. c.x * 2 + 1`,
  `ifelse.(c.x .> 0, c.x, 0)`, `in.(c.g, Ref(set))`) builds an **elementwise** node, through
  Julia's own broadcasting machinery, so dot fusion, `@.`, `Ref` and scalars behave as on
  `Vector`s.
- Evaluated on a table with `n` rows, an elementwise node yields `n` values, the same as the
  broadcast on the column vectors. Under grouping it is evaluated per group and scattered back,
  so the frame keeps its row count.
- `c.x .^ 3` gives the same values as `v .^ 3` on the column vector `v`, although Julia lowers
  it through `Base.literal_pow`.

**Example.**
```julia
t = (x = [1, -2, 3], y = [10, 20, 30])
mutate(z = abs.(c.x) .+ c.y)(t)           # z == abs.(t.x) .+ t.y == [11, 22, 33]
```

test: `CF-003 dots elementwise` — on fixed tables, compares each dotted form above with the same
broadcast on the raw column vectors, ungrouped and grouped.

### CF-004 Plain calls of reductions reduce the whole column
`since=0.0.1 status=stable`

**Statement.**
- A plain (undotted) call of a supported reduction on a column expression builds a
  **whole-column** node: evaluated, it receives the entire column (or, under grouping, the
  group's slice) and yields one value, exactly as the function would on a `Vector`.
- The supported set includes at least `sum`, `prod`, `length`, `count`, `maximum`, `minimum`,
  `extrema`, `first`, `last`, `any`, `all`, `mean`, `median`, `std`, `var`. The full list is
  PROVISIONAL (parity matrix). These are methods of the Base/Statistics functions on ChuiFrames'
  own expression type, never new bindings (CF-009).
- Reductions mix with elementwise expressions: `c.x .- mean(c.x)` subtracts the column (or group)
  mean from every row, a window function as in dplyr.
- Results agree with Base/Statistics on the same vectors (floats within CC-004's tolerance), and
  `count` errors on non-Bool data like Base. On empty input they follow CC-006: the same value
  where Base returns one, and CC-007's exception type where Base throws.

**Example.**
```julia
using Statistics
t = (g = ["a", "b", "a"], x = [1.0, 2.0, 4.0])
summarise(n = length(c.x), m = mean(c.x))(t)                    # one row: n = 3, m = 7/3
(group_by(:g) ⨟ mutate(d = c.x .- mean(c.x)))(t)                # d == [-1.5, 0.0, 1.5]
```

test: `CF-004 plain calls reduce` — for each listed reduction the downstream uses, compares the
summarised value with the Base/Statistics call on the column, ungrouped and per group, plus one
window expression (`c.x .- mean(c.x)`) under `group_by`.

### CF-005 Plain operators are not overloaded on column expressions
`since=0.0.1 status=stable`

**Statement.**
- ChuiFrames defines no methods of the plain (undotted) operators `+ - * / ^ < <= > >= & | !`
  or `isless` for column expressions. Comparisons and arithmetic on columns are written dotted
  (`c.x .> 1`, `(c.a .> 1) .& (c.b .< 2)`; `.&`/`.|` need parentheses because of precedence).
  A plain operator applied to a column expression therefore raises a `MethodError` (`c.x + 1`,
  `c.x > 1`, `!c.x`; E-35); it never silently builds a node.
- **Structural equality.** On expression nodes, `==` and `isequal` are the same function:
  **recursive `isequal` over the node's type and fields**, so they always return a `Bool` (never
  `missing`, even for a node holding a `missing` constant). Fields holding functions are compared
  with `===`. `hash` is consistent with it (`isequal(a, b)` implies `hash(a) == hash(b)`), so
  expressions are safe as `Dict` and `Set` keys, and `c.x == c.y` is `false` while
  `(c.x .+ 1) == (c.x .+ 1)` is `true`. **New work:** in the prototype only the leaf `c.x == c.x`
  is `true`; `(c.x .+ 1) == (c.x .+ 1)`, `isequal(sum(c.x), sum(c.x))` and the matching hashes
  are all `false` (E-35).
- **Known cost: silent `Bool` constants.** Because `==` is structural and `in` uses `==`,
  `c.x == 1` and `c.x in [1, 2]` evaluate at once to the constant `false`, not to a node. Passed to
  a verb, the constant is used as data: `mutate(z = c.x == 1)` gives an all-`false` column, and
  `filter(c.x == 1)` becomes `filter(false)`, which Base already defines as the curried
  `Base.Fix1(filter, false)`, so the mistake surfaces only when that is applied (E-35). The
  intended forms are `c.x .== 1` and `in.(c.x, Ref(set))`. ChuiFrames warns, at build time, when a
  bare `Bool` is passed to `mutate`/`summarise` (ChuiFrames ADR-0002 rule 17); the warning is not
  part of this entry.
- **Known cost: other silent constants** (ADR-0014; ChuiFrames ADR-0002 rule 3). The same happens
  with any plain Base call that is neither a supported reduction (CF-004) nor `|>` (CF-006),
  for which ChuiFrames defines no node method, and whose Base method accepts any value: `string(c.x)` and `hash(c.x)` return a `String` and a
  `UInt` at once, and `ismissing(c.x)` and `isnothing(c.x)` return `false`. So
  `mutate(s = string(c.x))` and `mutate(h = hash(c.x))` give constant columns, because constants
  are legal values (`mutate(z = 1)`, as in dplyr). The intended forms are dotted
  (`string.(c.x)`, `hash.(c.x)`, `ismissing.(c.x)`). ChuiFrames' own guards (ChuiFrames ADR-0002
  rules 3 and 8: `coalesce`/`something` with a node first and two or more arguments, and constant
  results inside `across`, `if_any` and `if_all` throw an `ArgumentError`) are not part of this
  entry.

**Example.**
```julia
(c.x == c.x) isa Bool                   # true
(c.x .+ 1) == (c.x .+ 1)                # true (structural)
(c.x == missing, missing == c.x)        # (false, false): a Bool, never missing
try c.x > 1 catch err; err isa MethodError end   # true: write c.x .> 1
Dict((c.x .+ 1) => 1)[c.x .+ 1] == 1    # usable as a key
```

test: `CF-005 no plain-operator overloads` — checks that `==`/`isequal` return `Bool`s with
structural meaning on leaf and compound nodes (`c.x`, `c.x .+ 1`, `sum(c.x)`, a node with a
`missing` constant), that `c.x == missing` and `missing == c.x` are `false`, that equal nodes
have equal hashes and work as `Dict` keys, and that `c.x + 1`, `c.x > 1` and `!c.x` throw
`MethodError`.

### CF-006 `c.x |> f` applies `f` to the whole column
`since=0.0.1 status=stable`

**Statement.** `c.x |> f` builds a whole-column node that, evaluated, calls `f` once on the full
column vector (or the group's slice). This is the escape hatch for any function the grammar does
not cover (a plain call `f(c.x)` of a function that is not a supported reduction is **not**
promised; write `c.x |> f`). Such nodes are never decomposed into partial aggregates, so lazy
plans may materialize the column to run them. What happens to `f`'s result depends on the verb:
- **In a column context** (`mutate`, and any elementwise position): an `AbstractVector` of the
  column's (or group's) length becomes the column; a non-vector value is a reduction and is
  repeated on every row (of the group); an `AbstractVector` of **any other length throws
  `DimensionMismatch`**. **New work:** the prototype silently produces a short column
  (`mutate(u = c.x |> unique)` on 3 rows gives 2 values, E-35).
- **In `summarise`:** the result is one cell, whatever it is; a vector result is stored as a
  single cell (a vector-valued cell), never spread over rows.

**Example.**
```julia
t = (x = [3, 1, 2],)
mutate(r = c.x |> sortperm)(t)          # r == sortperm(t.x) == [2, 3, 1]
summarise(s = c.x |> v -> sum(v) / 2)(t)
mutate(u = c.x |> unique)((x = [1, 1, 2],))   # throws DimensionMismatch
```

test: `CF-006 whole-column escape hatch` — a vector-returning and a scalar-returning `f` give
the same results as calling `f` on the column, ungrouped and per group, eagerly and lazily; a
wrong-length vector in `mutate` throws `DimensionMismatch`; a vector result in `summarise` is
one cell.

### CF-007 Verbs are values, composed with `⨟`
`since=0.0.1 status=stable`

**Statement.**
- Calling a verb without a table (`filter(c.x .> 1)`, `group_by(:g)`) returns a **step value**:
  it can be stored, printed, reused and composed. Applying a step to a table runs it:
  `step(t)` and `t |> step` are equivalent.
- `a ⨟ b` for steps or pipelines returns a **pipeline value** meaning "`a` then `b`": for every
  table `t`, `(a ⨟ b)(t)` is frame-equal (Definitions) to `b(a(t))`. This is a method of
  ChuiCore's single `⨟` binding (CC-001, CC-002), so both groupings of `a ⨟ b ⨟ d` give
  frame-equal results.
- The same step or pipeline value applies to an eager table and to a lazy query (CF-008).
  Applied to a lazy query it records itself in the plan instead of running.

**Example.**
```julia
using ChuiFrames, Statistics, Tables
p = filter(c.mass .> 3) ⨟ group_by(:species) ⨟ summarise(m = mean(c.mass))
t = (species = ["a", "b", "a"], mass = [3.1, 5.0, 4.0])
q = t |> filter(c.mass .> 3) |> group_by(:species) |> summarise(m = mean(c.mass))
isequal(Tables.columntable(p(t)), Tables.columntable(q))   # frame equality, ungrouped results
```

test: `CF-007 verbs as values` — checks, by frame equality, `(a ⨟ b)(t)` against `b(a(t))` and
both groupings of `⨟` on three steps the downstream uses, that `t |> p` equals `p(t)`, and that a
stored pipeline applied to two tables gives each table's result.

### CF-008 Lazy and eager execution agree
`since=0.0.1 status=stable`

**Statement.** For every pipeline `p` built from **deterministic, pure** functions (no
randomness, I/O or mutation of captured state: a lazy plan may call a function a different number
of times, on different chunks, in a different order) and every table `t`, running `p` lazily (on
the lazy view of `t`, then collecting) and eagerly agree:
- **Results** are approximately frame-equal (Definitions): the same column names in the same
  order, the same number of rows, the same grouping columns; values `isequal` when either is
  `missing` or not a float; floats from reductions within CC-004's tolerance, other floats
  `isequal`; tuples compared recursively.
- **Row order** is the same. The rows a grouped summary produces are **sorted ascending by the
  group keys** (`isless` order, lexicographic over several keys) on both paths, as the prototype
  does on both (E-35); a later `arrange` reorders them as usual.
- **Errors:** if one path throws, the other throws an exception of the **same type** (e.g. a
  summary of `maximum` over an empty group throws CC-007's `ArgumentError` on both).
- **Element types** may differ by promotion (e.g. `Float64` lazily vs `Real` eagerly; DESIGN §6,
  E-35); values must not.

The optimizer's rewrites (predicate and projection pushdown, partition pruning, fusion) must
preserve this, including for NaN/`missing` statistics and filters moved past `select`
(prototype regressions 7 and 8). This promise is ChuiFrames' core correctness guarantee; its own
property tests check it on random pipelines.

**Note: group-key order is not `arrange` order** (ADR-0014; informative, it adds no promise).
- Group keys sort by `isless`, which puts NaN before `missing`, and `missing` last.
- `arrange` (ChuiFrames ADR-0002 rule 13) puts NaN and `missing` together in **one tie class**,
  last in both directions and in input order, and ties `-0.0` with `0.0`.
- Both orders match dplyr, so they differ on purpose.
- Grouping merges `-0.0` and `0.0` into one group, whose shown key is the first seen in row
  order, and canonicalises NaN (ChuiFrames ADR-0003 rule 8). Dictionary-encoded keys sort by
  value, not by code.
- v0 has no ordered-level (ordered dictionary) columns; how level order meets this `isless`
  order is PROVISIONAL.

The `isless` facts the note relies on (Base only):
```julia
isless(NaN, missing)       # -> true
isless(-0.0, 0.0)          # -> true
isequal(-0.0, 0.0)         # -> false
```

**Example.**
```julia
p = filter(c.x .> 1) ⨟ mutate(y = c.x .* 2)
t = (x = [1, 2, 3],)
eager = p(t)
lazyr = collect(p(lazy(t)))         # `lazy`/`collect` are the prototype's names (PROVISIONAL)
```

test: `CF-008 lazy == eager` — for each pipeline shape the downstream relies on (a fixed list,
including a grouped summary, an empty result, a summary that throws on an empty group, and a
column with `missing`/`NaN`), compares lazy and eager results by the rules above, including the
sorted group order and the exception type.

### CF-009 No exported name collides with Base or a standard library; no piracy
`since=0.0.1 status=stable`

**Statement.**
- For every name `n` exported by ChuiFrames: if Base, Core or a standard-library module exports
  `n`, ChuiFrames' binding **is** that module's (e.g. `ChuiFrames.filter === Base.filter`).
  `c` is the only single-letter export. Same rule as CC-010 and CT-003 (ADR-0009 §6).
- **No piracy.** A verb or reduction that shares a Base name (`filter`, `first`, `count`,
  `fill`, `replace`, `join`, …) is a method of the Base function that takes at least one argument
  of a **ChuiFrames-owned type** (an expression node, a step, a frame): `count(c.g)`,
  `filter(c.x .> 1)`. Where the natural signature has no such argument (`first(3)` for "the first
  3 rows", `fill(:x)` with a `Symbol`), the verb gets a **distinct name** instead (e.g. `head(3)`)
  or takes a column expression (`fill(c.x)`). The final verb names are PROVISIONAL.
- If ChuiCore's name-conflict banner is accepted (PROVISIONAL in `chui-core.md`), ChuiFrames calls
  it from `__init__`; that is not part of this entry.

**Example** (Base only):
```julia
(Base.isexported(Base, :filter), Base.isexported(Base, :first))   # -> (true, true)
(Base.isexported(Base, :count), Base.isexported(Base, :fill), Base.isexported(Base, :replace))   # -> (true, true, true)
(Base.isexported(Base, :mutate), Base.isexported(Base, :c))       # -> (false, false)
```

test: `CF-009 no Base collisions` — runs CC-010's collision check over ChuiFrames' exports
against Base, Core and every loaded standard library; checks that `c` is the only single-letter
export; and, for each method ChuiFrames adds to a Base or standard-library function, that its
signature has an argument of a ChuiFrames-owned type (via `methods(f, ChuiFrames)` and the
method signatures).

### CF-010 `c` is a plain export of ChuiFrames
`since=0.0.1 status=stable`

**Statement.** ChuiFrames exports `c` with a plain `export c` (ADR-0009 §2 option (a), decided by
the user at the L0 checkpoint, 2026-10-19), so `using ChuiFrames` brings `c` into scope with no
extra import; `using ChuiFrames: c` also works. There is no `ChuiFrames.Grammar` submodule for
`c`. The reassignment cost (CF-002, E-24) is documented, not avoided. Moving `c` to opt-in or
to a submodule would be a breaking contract change (ADR-0010). Rule-only: the name itself is
covered by CF-002's `names:` line.

**Example.**
```julia
using ChuiFrames
Base.isexported(ChuiFrames, :c)    # true
e = c.x .+ 1                       # no `using ChuiFrames: c` needed
```

test: `CF-010 c is exported` — after `using ChuiFrames` in a fresh module, `isdefined(@__MODULE__, :c)`
and `Base.isexported(ChuiFrames, :c)` are `true`, and `c === ChuiFrames.c`.

### CF-011 A Source is four methods; any Tables.jl input is a Source
`since=0.0.1 status=stable`

**Statement.** (ChuiFrames ADR-0004 rules 2, 5, 9 and 10; ADR-0009 §7 and ADR-0010 rule 6: the
pushdown vocabulary extends Tables.jl, CF-012, and the other names are distinct from Tables.jl's.)
- `ChuiFrames.Source` is an abstract type. A new source is a subtype in its author's own package
  and needs no change to ChuiFrames.
- **Four required methods:**
  - `source_schema(s)::Tables.Schema`: column names and element types;
  - `source_label(s)::String`: the label `explain` shows;
  - `plan_partitions(s, scan::Tables.Scan; morsel)::Tuple{Vector,Tables.Scan}`: the partition
    handles, in partition order, and the **residual** (CF-012);
  - `read_partition(s, p)`: a Tables.jl table for handle `p`.
- **Handles carry the pushdown.** Each handle holds everything `read_partition` needs (the
  pushed projection, filter and per-partition limit), so `read_partition` takes no filter
  argument. The columns it returns **must** include every column that the residual and the
  engine's own remaining conjuncts reference.
- **Optional methods and their defaults:** `partition_stats(s, p, col) = nothing` (CF-013);
  `row_count(s) = nothing` and `partition_row_count(s, p) = nothing`, each otherwise
  `(n, exact::Bool)`; `source_groups(s) = Symbol[]` (pre-grouped columns);
  `source_boundedness(s) = :bounded` (CF-015); `source_ordering(s) = nothing` (its declaration
  is PROVISIONAL); `isthreadsafe(s) = false`.
- **Threading is fail-closed.** Reads from a source whose `isthreadsafe(s)` is `false` are
  serialized behind one lock; a source opts in by returning `true`.
- **Any Tables.jl input is a Source.** ChuiFrames wraps any `Tables.istable` input (its
  `TablesSource`; the constructor is PROVISIONAL): each element of `Tables.partitions` is one
  partition, iterated with `iterate`, and the partition list is **snapshotted when the source is
  built**, so `explain` followed by `collect` plans the same partitions. Its residual is the whole
  `Scan`.

names: `ChuiFrames.Source`, `ChuiFrames.source_schema`, `ChuiFrames.source_label`, `ChuiFrames.plan_partitions`, `ChuiFrames.read_partition`, `ChuiFrames.row_count`, `ChuiFrames.partition_row_count`, `ChuiFrames.source_groups`, `ChuiFrames.isthreadsafe`

**Example.**
```julia
using ChuiFrames, Tables
struct VecSource <: ChuiFrames.Source
    parts::Vector{NamedTuple{(:x,),Tuple{Vector{Int}}}}
end
ChuiFrames.source_schema(s::VecSource) = Tables.Schema((:x,), (Int,))
ChuiFrames.source_label(s::VecSource) = "VecSource"
ChuiFrames.plan_partitions(s::VecSource, scan::Tables.Scan; morsel) =
    (collect(eachindex(s.parts)), scan)          # pushes nothing: the residual is the whole Scan
ChuiFrames.read_partition(s::VecSource, p) = s.parts[p]
```

test: `CF-011 Source interface` — a source defined in the test with only the four required
methods and three partitions (one empty) gives, through the lazy entry point, results frame-equal
to the same pipeline run eagerly on the concatenated table, for a filter, a `select` and a grouped
summary; the optional methods return the defaults above for it (`isthreadsafe` is `false`,
`source_boundedness` is `:bounded`); and wrapping a partitioned Tables.jl input plans the same
partitions twice.

### CF-012 Pushdown is a `Tables.Scan`; the source answers with a residual
`since=0.0.1 status=stable`

**Statement.** (ChuiFrames ADR-0004 rules 1 and 3; Tables.jl 1.14, LC-10 in
`ChuiFrames.jl/docs/research/lane-checks.md`.)
- The engine passes the pushable part of a plan to `plan_partitions` as **one** `Tables.Scan`
  (projection, conjuncts, limit and offset). ChuiFrames requires
  `Tables = "1.14"` (ChuiFrames ADR-0004 rule 1).
- **The residual is the source's answer.** It follows `Tables.Scan`'s axis rules exactly
  (filter, then row bounds, then projection). A source that cannot apply a conjunct exactly leaves
  it in the residual and may still use it to prune; a source that does not consume the filter
  leaves `limit` and `offset` in the residual too. The engine applies the residual to every
  partition, plus everything it never pushed. Returning the request unchanged is always correct.
- A row is kept only when a pushed predicate is exactly `true`; `missing` excludes it.
- **Which conjuncts arrive is the engine's choice.** A conjunct is pushed only when `Scan` can
  express it and its `Scan` semantics equal ChuiFrames' for every value, NaN and `missing`
  included (so `in.` with a float NaN member is never pushed). A source must not depend on any
  conjunct being pushed.
- **Limits.** A limit is pushed only when the plan has no stage between the scan and the limit
  and the engine keeps no conjunct. A pushed limit means "the first *n* qualifying rows of **each
  partition**". The engine always applies the **global** limit, in partition order.
- **Offsets** are never pushed to a source with more than one partition: each per-partition
  `Scan` carries `offset = 0`, and with an offset *k* a pushed per-partition limit becomes
  *k + n*. The engine applies the global offset, then the global limit, in partition order.

names: `ChuiFrames.plan_partitions`

**Example.**
```julia
using ChuiFrames, Tables
# A source that applies the whole request itself answers with an empty residual;
# one that applies nothing answers with the request unchanged. Both give the same rows.
q = Tables.Scan(; select = [:x], filter = Tables.colcmp(>, Tables.col(:x), 1), limit = 2)
```

test: `CF-012 Scan residual` — two test sources over the same three partitions, one returning the
request unchanged as residual and one applying a pushed `colcmp` itself and returning a residual
without it, give results frame-equal to the eager result; with a `head`-style limit *n* after an
offset *k*, a recording source sees `offset = 0` and a per-partition limit of `k + n` (or none), and
the result is the eager result's rows *k + 1* to *k + n*.

### CF-013 Partition statistics are bounds; pruning is conservative
`since=0.0.1 status=stable`

**Statement.** (ChuiFrames ADR-0004 rule 4.)
- `partition_stats(s, p, col)` returns `nothing` or `(; lo, hi, nnull, nnan, ndistinct)`, with
  every field present and each field possibly `nothing`. `lo` and `hi` are **bounds**, not exact
  values; `nnull` counts `missing`, `nnan` counts NaN.
- The engine keeps a partition whenever its statistics are `nothing`, a bound is NaN or
  `missing`, or the comparison throws.
- **Min/max pruning needs both safety conditions:** a predicate that can be true on NaN
  (negations, `.!=`, `isnan.`) prunes only with `nnan == 0` known; a predicate that can be true on
  `missing` (`ismissing.`, `.|` with one) prunes only with `nnull == 0` known. A predicate the
  engine cannot classify never prunes.
- So a source may report bounds that leave NaN out (as pyarrow's Parquet statistics do, LC-11)
  without changing results.

names: `ChuiFrames.partition_stats`

**Example.**
```julia
# Partition holding [1.0, NaN, 2.0]; its statistics leave NaN out and do not count it:
stats = (; lo = 1.0, hi = 2.0, nnull = 0, nnan = nothing, ndistinct = nothing)
# filter(.!(c.f .<= 2.0)) must keep the NaN row, so this partition is not pruned.
```

test: `CF-013 conservative pruning` — a test source whose statistics are the example's keeps the
NaN row under `filter(.!(c.f .<= 2.0))`, a partition `[1.0, NaN]` with `lo = hi = 1.0` and
`nnan = nothing` keeps its NaN row under `filter(c.f .!= 1.0)`, a source with a `missing`
bound and one whose statistics throw keep every partition, and in each case the lazy result is
frame-equal to the eager one.

### CF-014 Sinks are transactional
`since=0.0.1 status=stable`

**Statement.** (ChuiFrames ADR-0004 rule 7.)
- `ChuiFrames.Sink` is an abstract type with four methods: `open_sink(k, schema::Tables.Schema)`
  returns a state; `write_partition!(state, part)` takes one Tables.jl table, in partition order;
  `close_sink!(state)` flushes, writes footer and metadata, and commits; `abort_sink!(state, err)`
  discards.
- The engine calls `abort_sink!` on **any** exception after `open_sink`, and then not
  `close_sink!`.
- `write_partition!` **must** convert each partition to the declared schema, or raise an
  `ArgumentError`; it never passes a mismatched batch to a writer.
- **Built-in file sinks commit atomically:** they write to a temporary path in the same directory
  and rename in `close_sink!`; `abort_sink!` deletes the temporary file. Appending to an Arrow
  stream is documented as not atomic.
- The built-in Arrow IPC sink writes the **file format** by default; the stream format is used
  for `.arrows` paths and explicit append. A sink that cannot know the final dictionary up front
  decodes dictionary columns to plain values, or buffers until the dictionary is unified.

names: `ChuiFrames.Sink`, `ChuiFrames.open_sink`, `ChuiFrames.write_partition!`, `ChuiFrames.close_sink!`, `ChuiFrames.abort_sink!`

**Example.**
```julia
using ChuiFrames, Tables
mutable struct LogSink <: ChuiFrames.Sink
    log::Vector{Symbol}
end
ChuiFrames.open_sink(k::LogSink, schema::Tables.Schema) = (push!(k.log, :open); k)
ChuiFrames.write_partition!(k::LogSink, part) = push!(k.log, :write)
ChuiFrames.close_sink!(k::LogSink) = push!(k.log, :close)
ChuiFrames.abort_sink!(k::LogSink, err) = push!(k.log, :abort)
```

test: `CF-014 transactional sinks` — a recording sink sees `open`, then one `write` per partition
in partition order, then one `close`; when the pipeline throws after `open`, it sees one `abort`
and no `close`; writing through the built-in Arrow sink, a pipeline that throws leaves no file at
the target path; and, through the built-in Arrow sink, a partition that cannot be converted to the
declared schema (a `String` column declared `Int`) raises `ArgumentError`, while a convertible one
(`Int` declared `Float64`) is written converted.

### CF-015 v0 sources are bounded
`since=0.0.1 status=stable`

**Statement.** (ChuiFrames ADR-0004 rule 8; the choice ADR-0009 §7 and ADR-0010 rule 6 ask for.)
- `plan_partitions` returns a **finite** `Vector` of handles; every verb works on every source.
- `source_boundedness(s)` is reserved, with the default `:bounded`.
- A streaming variant, when it comes, adds a **new** method and never changes `plan_partitions`
  (its shape is PROVISIONAL). The ChuiTypes stream adapter ships first as a bounded source.

names: `ChuiFrames.source_boundedness`

**Example.**
```julia
using ChuiFrames, Tables
src = VecSource([(x = [1, 2],), (x = [3],)])   # CF-011's example source
ChuiFrames.source_boundedness(src)              # :bounded, the default
first(ChuiFrames.plan_partitions(src, Tables.Scan(); morsel = 65_536)) isa Vector   # true
```

test: `CF-015 bounded sources` — for a test source with no `source_boundedness` method and for
each built-in source the downstream uses, `source_boundedness` is `:bounded` and the handles
`plan_partitions` returns are a `Vector`.

### CF-016 File formats go through one registry
`since=0.0.1 status=stable`

**Statement.** (ChuiFrames ADR-0004 rule 9.)
- Files are read with `scan_file(path; format = :auto)` and written with
  `write_file(x, path; format = :auto)`. `scan_file` gives a query over the format's `Source`
  (its type is PROVISIONAL with the lazy entry points); `write_file` accepts any Tables.jl source
  (CF-001) and writes through the format's `Sink` (CF-014).
- Both dispatch through **one format registry**. A package extension registers a format from its
  `__init__` with `register_format!(key::Symbol; source, sink)`, so a format extension adds no
  line to ChuiFrames.
- Registering an already-registered key raises an `ArgumentError`. Alternatives use distinct
  keys, chosen with an explicit `format =` (e.g. `:parquet_duckdb`).
- An unknown format raises one generic error, "no reader/writer registered for `<ext>`; load the
  package that provides it", with no per-format hint.
- Built in: the Arrow IPC source and sink, and the CSV source and sink. Parquet is a package
  extension (on Parquet2). Format-specific options are PROVISIONAL.

names: `ChuiFrames.scan_file`, `ChuiFrames.write_file`, `ChuiFrames.register_format!`

**Example.**
```julia
using ChuiFrames
ChuiFrames.write_file((x = [1, 2, 3],), "t.arrow")   # Arrow IPC file format
collect(ChuiFrames.scan_file("t.arrow"))             # `collect` is PROVISIONAL (CF-008)
```

test: `CF-016 format registry` — an Arrow and a CSV round trip through `write_file` and
`scan_file` are frame-equal to the input; registering a test format twice under one key raises
`ArgumentError`; a test format registered under a fresh key is read and written by
`format = <key>`; and an unregistered extension raises an error whose message contains
"no reader/writer registered".

### CF-017 Each verb's option keywords are reserved
`since=0.0.1 status=stable`

**Statement.** (ChuiFrames ADR-0002 rule 14.)
- In `mutate` and `summarise`, keyword arguments name output columns, except the verb's
  **reserved option keywords**:
  - `mutate` reserves `by`, `keep`, `before` and `after`;
  - `summarise` reserves `by` and `groups`.
- A reserved keyword given a column expression raises an `ArgumentError` that points to the Pair
  form. A column with a reserved name is created with a Pair: `mutate("keep" => c.x .+ 1)`.
- **Adding a reserved keyword to a verb is a breaking change** to this entry (ADR-0010). The
  reserved lists of other verbs are added here, with new IDs, when ChuiFrames accepts them.

**Example.**
```julia
using ChuiFrames
t = (x = [1, 2],)
mutate("keep" => c.x .+ 1)(t)                 # a column named keep
try mutate(keep = c.x .+ 1)(t) catch err; err isa ArgumentError end   # true: use the Pair form
```

test: `CF-017 reserved keywords` — for each reserved keyword of `mutate` and `summarise`, passing
it a column expression raises `ArgumentError`, and the Pair form creates a column of that name;
an unreserved keyword creates its column.

---

## PROVISIONAL

No IDs and no contract tests. Each item gets an ID when ChuiFrames' ADR accepts it (ADR-0010).

- **Indexing forms of `c`:** `c[:name]`, `c["name with spaces"]`, and computed column sets.
- **The verb set and names** (dplyr/tidyr parity matrix), `desc`, `across`, joins, `nest`/`unnest`,
  and the distinct names CF-009 requires for Base-named verbs without a ChuiFrames argument.
- **The frame types**, their constructors, the grouping-columns accessor (`groupcols` in
  Definitions), and tibble-style printing.
- **The lazy entry points** (`lazy`, `collect`, `explain`, `code_lowered`, `optimize`,
  `physical`, `execute` in the prototype) and the plan printers' output. *Decided* (ChuiFrames
  ADR-0003 rule 13): `code_lowered(q)` prints the `CodeInfo` of a **rendered kernel**, a Julia
  function expression generated from each fused stage and lowered with `Meta.lower`. It is not the
  lowered code of the closure kernel that runs, which is the same generic loop for every plan.
  `explain` labels that section "rendered kernel". Its output is not promised.
- **Whole-column calls that return one value per row:** `lag(c.x, k)`, `lead(c.x, k)`,
  `cumsum(c.x)`, `cumprod`, `accumulate`, and `row_number()`, evaluated per group (ChuiFrames
  ADR-0002 rule 9; ADR-0009 §2 as amended 2026-10-20). Names are settled by phase-2 parity.
- **The full list of reductions** under CF-004, and `missing`-aware aggregates. *Decided*
  (ChuiFrames ADR-0002 rule 10): `skipmissing(c.x)` is a node valid only as a reduction's argument
  (`sum(skipmissing(c.x))`), and an `ArgumentError` anywhere else; reductions otherwise propagate
  `missing`. Whether ChuiCore owns `skipmissing` aggregator variants is request
  `chui-frames-to-chui-core-missing-aggregators`.
- **The bare-`Bool` lint** (CF-005's known cost). *Decided* (ChuiFrames ADR-0002 rule 17): a
  build-time warning when a bare `Bool` is passed to `mutate`/`summarise`, silenced by wrapping
  the value (`lit(true)`; the name is a placeholder).
- **Ordered-level columns** (ordered dictionaries, phase 6; ChuiFrames ADR-0001 rule 5). Until
  then the Arrow reader raises an `ArgumentError` for `isOrdered = true`. Recommended direction
  (ADR-0014): the element type of an ordered-level column defines `isless` by level order, so
  CF-008's "`isless` order" gives level order with no change to CF-008's text. Phase 6's ADR
  decides.
- **Source ordering declarations** (ChuiFrames ADR-0004 rule 6). *Decided:* `source_ordering(s)`
  (default `nothing`, CF-011) declares sort keys, directions, NaN/`missing` placement, the
  treatment of `±0.0`, and a flag `global::Bool` (partitions sorted across partition order too,
  with non-overlapping key ranges). The engine skips an `arrange` only when the declaration
  matches `arrange`'s order (ChuiFrames ADR-0002 rule 13) exactly and `global` is `true`; with
  order only within partitions it k-way merges, breaking ties by partition index then row
  position, so the result equals a stable `arrange`; otherwise it sorts. *Open:* the
  declaration's type and constructor.
- **Streaming sources** (ChuiFrames ADR-0004 rule 8). A later variant adds
  `stream_partitions(s, scan)`, returning a possibly infinite iterator, for sources whose
  `source_boundedness(s)` is `:unbounded`. Row-wise verbs (`filter`, `select`, `rename`, row-wise
  `mutate`, `head`) accept them; blocking verbs reject them at plan time unless windowed.
- **Reader and writer options** per format (Arrow, CSV, Parquet), beyond CF-016's entry points.
- **The ChuiTypes stream adapter's API.** Its placement is decided (ADR-0002 §1: in ChuiFrames,
  using only ChuiTypes' public stream API; no ChuiTypes extension on ChuiFrames). It ships first as
  a bounded source (CF-015) once ChuiTypes releases that API (request
  `chui-frames-to-chui-types-effects-and-streams`).
