# Tidy.jl: design notes and status

A dplyr/purrr-style data library in plain Julia, with no macros. It runs eagerly (step by step on in-memory tables) or lazily (the whole query is planned first, then run).
In lazy mode it has a query optimizer, physical planning, a fused parallel engine built on transducers, and Arrow/Parquet scans.
This file is for an agent (or person) picking the work up: what exists, why it is built this way, and what to do next.

Status as of 2026-10-19: a working prototype. It has about 950 lines in the core plus a 73-line I/O adapter, and every check script passes on Julia 1.11.7 with `-t 4`.

---

## 1. Files

| File | Role |
|---|---|
| `Tidy.jl` | The core module, standard library only (Statistics). It holds expressions, transducers, monoids, tables, verbs, the lazy planner and optimizer, execution, and the plan printers. |
| `TidyIO.jl` | Arrow and Parquet `Source` adapters, as a separate module that uses Arrow, Parquet2 and Tables. |
| `demo.jl` | Tour of the core API and in-memory lazy execution. `julia -t 4 demo.jl` |
| `io_demo.jl` | A complex Parquet scan, an Arrow scan with a limit, and `explain` / `code_lowered` output. `julia --project=io/env -t 4 io_demo.jl` |
| `io/env/` | Julia environment: Arrow 2.8.1, Parquet2 0.2.37, Tables 1.14.0. |
| `io/probe.jl` | Verified usage of the Arrow.jl and Parquet2 APIs: column subsets, batches, row groups, statistics, concurrent reads. |
| `review/fixcheck.jl` | Regression checks: Int overflow in mean, `Take` in parallel folds, `desc(:sym)`, `count` semantics, method ambiguities. |
| `review/optcheck.jl` | The optimizer must preserve results: lazy and eager must agree on 6 adversarial pipelines. |
| `review/nancheck.jl` | NaN row-group statistics; a filter moved ahead of a `select` that drops its column. |
| `review/explaincheck.jl` | Prints every plan view for a sample query. |
| `review/t1.jl`, `t2.jl` | The reviewer agent's probe scripts. |
| `review/Tidy.before-*.jl` | Snapshots taken before the I/O and explain refactors. |

## 2. User-facing API

```julia
using .Tidy, Statistics
df = Tbl(species = ["a","b"], mass = [3.1, 5.0], len = [10, 15])

df |> filter(c.mass .> 3) |>                      # c.x is a deferred column reference
      mutate(ratio = c.mass ./ c.len) |>          # dots mean elementwise
      group_by(:species) |>
      summarise(n = length(c.species), m = mean(c.ratio)) |>   # plain calls mean reductions
      arrange(desc(c.m))

p = group_by(:g) ⨟ summarise(m = mean(c.a))       # verbs are values; ⨟ composes them
p(df); p(lazy(df))                                # the same pipeline, run eagerly or lazily

q = scan_parquet("f.parquet") |> filter(c.ts .>= 10) |> summarise(s = sum(c.a))
explain(q); code_lowered(q); collect(q)
```

Other pieces:
- **Verbs:** `filter select mutate summarise arrange group_by ungroup head nest unnest`.
- **Elementwise:** any `f.(...)` or `.op`, and `map(f, c.x, c.y)`.
- **Reductions:** `sum prod length count maximum minimum extrema first last any all mean median std var quantile reduce mapreduce foldl foldr`.
- **Running totals (scans):** `cumsum cumprod accumulate`.
- **Escape hatch:** `c.x |> f` applies any function to the whole column.
- **Transducers:** `Map Filter MapCat Take ⨟ foldxl foldxt`; `rows(t)` iterates rows as NamedTuples.

## 3. Key decisions, and why

### 3.1 Capturing expressions without macros
- **Columns are objects.** `c.x` is a `Col` node; `c` is a singleton whose `getproperty` builds nodes. A bare `_` (as Ibis uses) is impossible: Julia's all-underscore identifiers are write-only. `c` was chosen over `_t`, `ç` and `∂` because it's ASCII and short.
- **Elementwise work goes through Julia's own broadcasting.** A custom `BroadcastStyle` (`NodeStyle`) intercepts `broadcasted`, so `f.(c.x, 1)` and `c.x .+ 1` build `Call` nodes. Dot fusion, `@.`, `ifelse.`, `in.(x, Ref(set))` and `Ref` all work unchanged. `x .^ 3` (Julia's `literal_pow`) is normalized back to `^`.
- **Reductions are plain calls**, exactly as on a `Vector`: `sum(c.x)` builds a whole-column node. Plain operators (`c.x > 1`) are deliberately not overloaded. That keeps the rule "a column behaves like a Vector", and avoids `==` returning a node, which would break `Dict`/`Set`. Cost: you must write `.>`, and `.&`/`.|` need parentheses.
- **Every `Call` records:** `whole` (reduction vs elementwise), a printable `label`, and `agg` (its monoid, or `nothing`).
- **Rejected:** a `lift(f)` / `reducer(f)` API (replaced by dots and plain calls), and macros (the user wanted ordinary Julia).

### 3.2 Evaluation
- **A vectorized interpreter.** `ev(node, cols, nrow)` evaluates one column at a time: one dynamic dispatch per column, with compiled broadcast loops inside. Whole-column calls get whole columns; elementwise calls broadcast.
- **Grouped evaluation** runs per group on views and scatters results back. So `c.x .- mean(c.x)` under `group_by` is a window function, as in dplyr.

### 3.3 Tables
- **`Tbl`** is an immutable `NamedTuple` of vectors (the Tables.jl column-table layout) plus `groups::Vector{Symbol}`.
- **`mutate` keyword arguments apply in order**, so a later column can use an earlier one, as in dplyr.

### 3.4 Verbs are data
- Each verb is a `Step` struct (`FilterStep`, `MutateStep`, …).
- `(s::Step)(t::Tbl)` runs it now; `(s::Step)(l::LazyTbl)` appends it to the plan.
- `⨟` builds a `Pipeline`. This "initial encoding" is what lets the same pipeline run eagerly or lazily, and lets the optimizer inspect it.

### 3.5 Transducers (a hand-rolled minimal version, about 60 lines)
- **Model:** a transducer maps a reducing function to a new one (`xf(rf) -> rf′`), as in Clojure and Transducers.jl.
- **Available:** `Map`, `Filter`, `MapCat`, `Take`, `Composed`; early termination via `Reduced`.
- **`foldxt`** splits work into contiguous batches per task and combines results *in order*, so `combine` only needs to be associative. `init` is a factory, so each task gets a fresh accumulator.
- **Plans containing `Take`/`TakeRows` run sequentially**, because they need one shared counter. (A bug once applied `Take` separately in each batch.)
- **Not depending on Transducers.jl** keeps the core dependency-free. The names match it, so switching later is easy.

### 3.6 Monoid aggregations
- **Each aggregate is three functions:** `partial` (one chunk), `combine` (associative merge), `final`.
- **Covered:** Sum, Prod, Count, CountTrue (`count`; Bool-only, like Base), Max, Min, Extrema, First, Last, AnyM, AllM, Mean = (float sum, n), Moments (var/std via Chan's parallel merge), ReduceM(op), MapM(f, inner).
- **Decomposable only when safe.** Any keyword argument (e.g. `init`) turns decomposition off, because `init` would be added once per chunk.
- **Never decomposed:** `foldl`/`foldr` (order matters), `median`, `quantile`, `|> f`.
- **Mixed expressions still work.** In `std(a) ./ abs.(mean(a))`, each aggregate becomes a `Slot`, and the outer arithmetic runs at the finalize step.

### 3.7 Lazy pipeline: logical → optimized → physical → execute
Each stage is a value you can inspect: `optimize(q)`, `physical(q)`, `execute(pp)`.

1. **Logical plan.** `LazyTbl(src::Source, steps)`, as written.
2. **Optimizer** (each rule is logged; each preserves results):
   - **Split filters:** `a .& b` becomes separate conjuncts.
   - **Predicate pushdown:** a row-wise filter moves earlier past a step only when that is safe:
     - past a row-wise `mutate` that doesn't define a column the filter uses;
     - past `group_by`, `ungroup` and `arrange`;
     - past a `select` only if every column the filter uses survives it.
     - It never moves past `head`, `summarise`, `nest`, `unnest`, or a `mutate` with whole-column calls.
     - Filters that reach the front become `Scan.preds`.
   - **Projection pushdown and dead-column elimination:** a backward pass computes which columns are still needed. Unused `mutate` entries are dropped, and only the needed columns are read.
3. **Physical plan:**
   - **Partitions:** row ranges, Arrow record batches split into chunks, or Parquet row groups.
   - **Min/max pruning:** `col op literal` conjuncts (with the literal on either side; `<`, `<=`, `>`, `>=`, `==`) are checked against each partition's statistics. Missing or NaN statistics, or a comparison that throws, mean "keep the partition".
   - **Fused stage:** the longest streamable run of steps becomes one per-partition stage, `*(1)` as in Spark whole-stage codegen.
   - **Sink:** a two-phase `HashAggregate` (partial per partition → merge in order → final) when the next step is a summarise made of monoids; otherwise `Materialize` (concatenate).
   - Everything after the sink runs eagerly in memory.
4. **Execute:** one `Composed` transducer (read → fused filter → steps) folded over the partitions with `foldxt`. It uses `foldxl` when a `head` needs a shared counter; `TakeRows` stops the scan early.

### 3.8 Sources (the I/O interface)
```julia
schema(s) -> Vector{Pair{Symbol,Type}}
partitions(s, morsel) -> Vector
read_partition(s, p, cols) -> Tbl
stats(s, p, col) -> (lo, hi) | nothing     # optional
describe(s) -> String
threadsafe(s) -> Bool                      # optional; default true, else reads are serialized behind a lock
source_groups(s)                           # optional
```
- `TblSource` lives in the core.
- **`ArrowSource`:** `Arrow.Table` is memory-mapped, and numeric columns are read as views without copying. Batches come from the `ChainedVector.arrays` field. Arrow has no statistics.
- **`ParquetSource`:** `Parquet2.Dataset`. One partition is one row group, and only the requested columns are read (`Parquet2.load(rg, name)`). Statistics come from `Parquet2.ColumnStatistics`.
  - Strings arrive as `StringRefVector`s (references into the file buffer) and are converted to `Vector{String}`.
  - Statistics are only written if `writefile(...; compute_statistics=true)`.
  - Each partition passed to `writefile` becomes one row group; there is no row-group-size option.
- **Concurrent reads were checked:** reading row groups from one `Dataset` and batches from one Arrow table on 4 threads gave the same results as sequential reads, 20 runs each.

### 3.9 Plan printing
`explain(q)` prints four sections, in the style of Spark's `explain(extended=true)`:
- **Parsed Logical Plan** and **Optimized Logical Plan:** root-first trees joined by `+-`, with `PushedFilters` and the list of rules that fired.
- **Physical Plan:** `*(1)` markers for fused operators, `HashAggregate` partial/final with an `Exchange` between them, `ReadSchema`, `Partitions: k/n (pruned m by min/max statistics)`, and the execution mode with task counts.
- **Lowered Kernel:** `@code_lowered`-style `CodeInfo(` listings in SSA form: one for the per-partition kernel and one for the finalize step.

`code_lowered(q)` prints just the kernel. `show(q)` prints the physical plan only.

## 4. Measured results (Apple Silicon, `-t 4`)
- **In-memory, 2M rows:** filter → mutate → group_by → 6 aggregates → arrange took **0.20 to 0.25 s lazy vs 0.76 to 0.89 s eager**, with identical results (checked with `isapprox`).
- **Parquet, 2M rows, 16 row groups:** the complex query (3-way filter, mutate with a dead column, 7 monoid aggregates, a sort) read **5 of 16 row groups and 5 of 6 columns**. It took 0.18 to 0.21 s from disk vs 0.21 to 0.32 s eager in memory, with identical results.
- **Arrow `filter ⨟ select ⨟ head(5)`:** read **1 of 32** partitions (confirmed by counting reads).

## 5. Bugs found by review and fixed (keep these as regression tests)
1. **Lazy `mean` overflowed on Int columns:** it now uses a float sum.
2. **`foldxt` applied `Take` separately in each batch:** plans with `Take` now run sequentially.
3. **`desc(:sym)` sorted by a constant:** it now builds `Desc(Col(:sym))`.
4. **Lazy `count` summed non-Bool values:** it now uses the `CountTrue` monoid, which errors like Base.
5. **A broadcast-style method ambiguity:** fixed with a `NodeStyle`/`Unknown` method.
6. **`unnest` on an empty table dropped the group keys:** fixed.
7. **NaN in Parquet statistics skipped row groups that held matching rows:** NaN statistics are now ignored, in both the adapter and the generic check.
8. **A filter could move ahead of a `select` that drops its column:** it now moves only when every column it uses survives.

Lesson: the reviewer agent sometimes sends a short report first and a fuller one later. Wait for the final report before declaring a review clean.

## 6. Known limitations
- **Types:** lazy and eager can return different element types. `vcat` of partitions promotes types (e.g. `Float64` lazy vs `Real` eager); the values are equal.
- **Missing functions:** `first(c.x, n)` is not supported (only one-argument `first`/`last`).
- **Empty input:** `unnest` on an empty table can't recover the nested columns.
- **`in.(...)` filters** are applied, but don't skip row groups.
- **Lazy fallback:** non-monoid aggregates (`median`, `quantile`) materialize the stream before summarising.
- **Grouping cost:** `groupindices` uses a `Dict{Any}` with tuple keys and a per-row loop, which is slow for many groups and large data.
- **Interpreter cost:** one dynamic dispatch per column, with no code generation.
- **Not built yet:** joins, `distinct`, `pivot_*`, `slice_*`, `across()`, writing results to Parquet or Arrow.
- **Data files:** `io/events.parquet` and `io/events.arrow` (about 150 MB) are not kept in the folder; `io_demo.jl` regenerates them.

## 7. Areas to work on (roughly by value)
1. **Joins:** hash join with a build side and a probe side. Add `Join` to the logical plan (it becomes a tree, not a chain), push filters to the correct side, and use a broadcast join when one side is small. The plan printers already draw trees.
2. **Fast group-by:** typed keys (one column, or a `Tuple` with concrete types), radix partitioning per thread, and dictionary-encoded strings. This is currently the main bottleneck.
3. **Code generation:** compile each fused stage into one loop specialized on column types (`@generated` / RuntimeGeneratedFunctions), cached by plan shape. Keep the interpreter for small inputs, because compiling takes time.
4. **Better statistics use:** handle `in.(...)` against min/max, use Parquet page indexes and bloom filters, compute statistics for Arrow and in-memory sources, and estimate selectivity.
5. **A cost-based optimizer:** join order, and choosing the build side using statistics. E-graphs (Metatheory.jl) are the Calcite-style option.
6. **Out-of-core work:** spill hash tables and sort runs to disk, and use a buffer pool.
7. **Standards for exchanging data and plans:** export/import Substrait plans, so plans can run on DuckDB, DataFusion or Velox; Arrow Flight for distribution (Dagger.jl for scheduling); `Tables.jl` sources and sinks for `Tbl`.
8. **GPU:** KernelAbstractions kernels for numeric pipelines, and choosing CPU or GPU per operator.
9. **API completeness:** `across`, `distinct`, `slice_*`, `pivot_longer/wider`, `rename`, `relocate`, and writing to Parquet/Arrow.
10. **Missing values:** consistent `missing` handling in monoids (`skipmissing` variants) and in statistics.
11. **Tests:** turn `review/*.jl` into a `Test` suite with a *property test* comparing lazy and eager on randomly generated pipelines. That is the strongest guarantee this design has.

## 8. How the work was done (for the next agent)
- **Lanes:** one agent built the core. Separate lanes were a reviewer agent (read-only bug hunting, three rounds) and probe agents (to verify the Arrow and Parquet2 APIs by running code, not by recalling them; Context7 does not index those packages).
- **The user's preferences:** minimal, plain Julia, no macros, functional-programming idioms, outputs verified by running them, and honest reporting of skipped or failed steps.
- **Python:** the Homebrew Python on this machine is broken. Use `uv` for any Python work. (None was needed here.)
