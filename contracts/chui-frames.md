# Contract: chui-frames (v0)

> **Binding since 2026-10-19** (ADR-0002/0004/0007/0009/0010 Accepted at the L0 checkpoint).
> Stable entries change only through a contract ADR (see [README.md](README.md)).

- **Owner:** ChuiFrames. **Consumers:** ChuiStats, ChuiLearn, ChuiSpatial, ChuiPlot (none exist
  yet; ADR-0002 §1).
- **Contract version:** v0, describing ChuiFrames 0.0.1 (unreleased).
- **Sources:** ADR-0009 §2, §3, §6, §7; ADR-0010 (format, rule 6); the prototype
  (`reference/prototype/DESIGN.md` §2–§3) for the `c.x` grammar only. Where an entry promises
  more than the prototype does, it says "new work" and cites the probe (E-35).
- **Format:** see [README.md](README.md). Undecided items, including the Source/Sink interface,
  are under [PROVISIONAL](#provisional).
- **Names in examples and tests.** Verb names (`filter`, `mutate`, `group_by`, `summarise`,
  `arrange`), the frame type, and the lazy entry points `lazy`/`collect` come from the prototype
  and are PROVISIONAL until ChuiFrames' parity matrix and grammar ADR accept them. The *rules*
  below are stable. Contract tests use the names of the ChuiFrames release under test and are
  re-written when an accepted ADR renames them (README, "Tests that need PROVISIONAL names").
  `c` is a plain export of ChuiFrames (CF-010), so `using ChuiFrames` brings it into scope.

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
- Apache Arrow IPC is the ecosystem's on-disk and inter-process columnar format (ADR-0009 §3);
  the reader/writer API is PROVISIONAL.

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
  intended forms are `c.x .== 1` and `in.(c.x, Ref(set))`. A lint for this is PROVISIONAL.

**Example.**
```julia
(c.x == c.x) isa Bool                   # true
(c.x .+ 1) == (c.x .+ 1)                # true (structural)
try c.x > 1 catch err; err isa MethodError end   # true: write c.x .> 1
Dict((c.x .+ 1) => 1)[c.x .+ 1] == 1    # usable as a key
```

test: `CF-005 no plain-operator overloads` — checks that `==`/`isequal` return `Bool`s with
structural meaning on leaf and compound nodes (`c.x`, `c.x .+ 1`, `sum(c.x)`, a node with a
`missing` constant), that equal nodes have equal hashes and work as `Dict` keys, and that
`c.x + 1`, `c.x > 1` and `!c.x` throw `MethodError`.

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

---

## PROVISIONAL

No IDs and no contract tests. Each item gets an ID when ChuiFrames' ADR accepts it (ADR-0010).

- **Indexing forms of `c`:** `c[:name]`, `c["name with spaces"]`, and computed column sets.
- **The verb set and names** (dplyr/tidyr parity matrix), `desc`, `across`, joins, `nest`/`unnest`,
  and the distinct names CF-009 requires for Base-named verbs without a ChuiFrames argument.
- **The frame types**, their constructors, the grouping-columns accessor (`groupcols` in
  Definitions), and tibble-style printing.
- **The lazy entry points** (`lazy`, `collect`, `explain`, `code_lowered`, `optimize`,
  `physical`, `execute` in the prototype) and the plan printers' output.
- **The full list of reductions** under CF-004, and `missing`-aware aggregates.
- **A lint for silent `Bool` constants** (CF-005's known cost), e.g. `mutate` warning when an
  argument is a bare `Bool`.
- **Arrow, CSV and Parquet reader/writer API.**
- **The ChuiTypes stream adapter's API.** Its placement is decided (ADR-0002 §1: in ChuiFrames,
  using only ChuiTypes' public stream API; no ChuiTypes extension on ChuiFrames); its API waits
  for the Source interface below.

#### Source and Sink interface (sketch)

ADR-0009 §7 and ADR-0010 rule 6 require names distinct from Tables.jl's `schema`/`partitions`
(or consistent extensions of them) and a choice between a bounded-only v0 and a streaming
variant. Neither is decided; the sketch below only fixes the shape, using distinct names. It
replaces the prototype's `schema`, `partitions`, `read_partition`, `stats`, `describe`,
`threadsafe`, `source_groups` (DESIGN §3.8).

```julia
abstract type Source end
source_schema(s::Source)::Vector{Pair{Symbol,Type}}        # column names and element types
source_partitions(s::Source; morsel::Int)                  # partition handles (row ranges, batches, row groups)
read_partition(s::Source, p, cols::Vector{Symbol}; filters = ())  # → a Tables.jl table of just `cols`
partition_stats(s::Source, p, col::Symbol)                 # (lo, hi) or nothing; optional; NaN/missing ⇒ nothing
source_label(s::Source)::String                            # for explain()
isthreadsafe(s::Source)::Bool = true                       # optional; false ⇒ reads serialized behind a lock
source_groups(s::Source)::Vector{Symbol} = Symbol[]        # optional; pre-grouped sources

abstract type Sink end
open_sink(k::Sink, schema)                                 # → a sink state
write_partition!(state, part)                              # one Tables.jl partition, in order
close_sink!(state)                                         # flush, finalize metadata
```

Requirements carried from the brief: adding a new source takes one file and no core changes;
`filters` carries pushed-down conjuncts the source may use or ignore (the engine re-applies
them); pruning keeps a partition whenever statistics are missing, NaN, or the comparison throws.

**Open choice: bounded vs streaming.**
- *(A) Bounded-only v0:* `source_partitions` returns a finite `Vector`; every verb works.
  ChuiTypes streams (unbounded) are not Sources until a later contract change.
- *(B) Streaming variant:* `source_partitions` may return a possibly infinite iterator, with
  `isbounded(s)::Bool` (default `true`). Row-wise verbs (`filter`, `mutate`, `select`, `head`)
  work on unbounded sources; verbs that need all input (`arrange`, a non-windowed `summarise`,
  joins with an unbounded build side) reject them, or require a window. This is what the
  ChuiTypes stream adapter (above) would need.
- *Alternative to distinct names:* extend `Tables.schema`/`Tables.partitions` consistently,
  i.e. a Source would *be* a Tables.jl partitioned table. Rejected for the sketch because a
  Source's partitions are lazy handles read with column selection and filters, which
  `Tables.partitions` does not model.
