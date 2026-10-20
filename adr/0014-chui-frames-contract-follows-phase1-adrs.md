# ADR-0014: `chui-frames.md` follows ChuiFrames' accepted phase-1 ADRs: the Source/Sink interface and reserved verb keywords become entries, and three stable entries get compatible clarifications

- **Status:** Proposed
- **Date:** 2026-10-20
- **Deciders:** the user (contract files are T3, `risk.toml`)
- **Scope:** ecosystem (contract ADR for `contracts/chui-frames.md`, ADR-0010)

This ADR is longer than 120 lines because it carries the exact contract text, ready to apply. The
assembled file (the current `chui-frames.md` with every edit below applied) was checked with
`contracts/check.jl` (Verification).

## Context

- **ChuiFrames' phase-1 ADRs 0001–0020 were accepted by the user on 2026-10-20** (ChuiFrames main
  c5db1cb, `docs/adr/`). Several of them say what `chui-frames.md` should now say:
  - ChuiFrames ADR-0004, Consequences: "`chui-frames.md`'s PROVISIONAL Source/Sink sketch is
    replaced by rules 1–9 … The interface gets contract IDs after acceptance."
  - ChuiFrames ADR-0003, Consequences: "`chui-frames.md` should gain a note that `code_lowered`
    shows a rendered kernel."
  - ChuiFrames ADR-0002, Consequences: CF-005's contract test "gains the `== missing` cases";
    "CF-008 should note that `arrange` order (rule 13) differs from group-key order";
    "ordered-factor sort order (ADR-0001 rule 5) is still open".
  - ChuiFrames ADR-0002 rule 14: each verb's option keywords are "listed per verb in the contract
    … Adding a reserved name later is a breaking change."
  - ChuiFrames ADR-0002 rule 3: `mutate(s = string(c.x))` and `mutate(h = hash(c.x))` make a
    constant column; "The docs list this as part of CF-005's known cost."
  - ChuiFrames ADR-0002 rule 5: "Whether CF-001 also covers interop methods is a contract reading
    the lead confirms."
  - ChuiFrames ADR-0001 rule 5: ordered levels wait for phase 6, "which must also settle how
    CF-008's `isless` order meets level order. That is a contract question, raised to the lead."
  - ChuiFrames ADR-0002 rule 9: `lag`, `lead` and the running operations are plain calls that
    return one value per row, "a stated exception to ADR-0009 §2's 'plain calls are reductions'"
    (ADR-0009's amendment of 2026-10-20 records it).
- **ADR-0010 and `contracts/README.md`:**
  - a PROVISIONAL item that the owning package's ADR accepts gets the next free ID;
  - a breaking change to a stable entry retires it and gives a new ID;
  - the change table has **no row for a compatible in-place edit of a stable entry**. ADR-0012
    asked the user for that exception for CC-001, and the user granted it (2026-10-20).
- **Nobody relies on `chui-frames.md` yet.** It has no consumers (ChuiStats, ChuiLearn,
  ChuiSpatial and ChuiPlot do not exist), and ChuiFrames 0.0.1 is unreleased.
- **The pushdown vocabulary exists.** Tables.jl 1.14.0 defines `Tables.Scan(; select, filter,
  limit, offset, validate)` and `Tables.colcmp(op, col, value)` (ChuiFrames LC-10; read by this
  lane in the installed `Tables/qGyu7/src/scan.jl`, lines 280, 301–326 and 151).

## Decision

1. **New stable entries, `since=0.0.1`** (the release manager corrects `since=` if ChuiFrames
   0.0.1 ships without them):

   | ID | Title | From ChuiFrames |
   |---|---|---|
   | CF-011 | A Source is four methods; any Tables.jl input is a Source | ADR-0004 rules 2, 5, 9, 10 |
   | CF-012 | Pushdown is a `Tables.Scan`; the source answers with a residual | ADR-0004 rules 1, 3 |
   | CF-013 | Partition statistics are bounds; pruning is conservative | ADR-0004 rule 4 |
   | CF-014 | Sinks are transactional | ADR-0004 rule 7 |
   | CF-015 | v0 sources are bounded | ADR-0004 rule 8 |
   | CF-016 | File formats go through one registry | ADR-0004 rule 9 |
   | CF-017 | Each verb's option keywords are reserved | ADR-0002 rule 14 |

   - **ADR-0004 rule 6 (ordering) stays PROVISIONAL.** Its rules are decided, but the declaration's
     type and constructor are not named, so no test can build one. The decided part is recorded
     in the PROVISIONAL bullet.
   - **The Source/Sink names are written qualified** and their export is not promised. ChuiFrames
     ADR-0004 names them but does not tier them.
   - CF-015 is the choice that ADR-0009 §7 and ADR-0010 rule 6 required: **bounded-only v0**,
     with names distinct from Tables.jl's except the pushdown request, which extends Tables.jl
     (`Tables.Scan`).
2. **Compatible in-place edits to stable entries** (no new IDs, `since=` unchanged), the same
   exception the user granted in ADR-0012 (★ Q1):
   - **CF-001:** a *Scope* bullet. CF-001 covers ChuiFrames' own functions; the DataAPI interop
     methods are not covered, because each takes a ChuiFrames frame argument (a method for plain
     Tables.jl inputs would be piracy). The Arrow bullet points to CF-016.
   - **CF-005:** the known cost gains the other silent constants (`string`, `hash`, `ismissing`,
     `isnothing`); the bare-`Bool` lint is recorded as decided but outside the entry; the example
     and test gain `c.x == missing` and `missing == c.x` (both `false`). This tightens the test of
     a promise CF-005 already makes ("always return a `Bool`").
   - **CF-008:** an informative note, adding no promise, that group-key order is not `arrange`
     order, with a Base-only block for the `isless` facts it relies on.
   - The preamble's **Sources**, **Format** and **Names** bullets.
3. **Readings the lead confirms here:**
   - CF-001 does not cover methods ChuiFrames adds to another package's function (ChuiFrames
     ADR-0002 rule 5).
   - **Ordered levels:** recommended direction, not decided. The element type of an ordered-level
     column defines `isless` by level order, so CF-008's "`isless` order" gives level order with
     no change to its text. ChuiFrames' phase-6 ADR decides. Until then the Arrow reader rejects
     ordered dictionaries (ChuiFrames ADR-0001 rule 10).
4. **The PROVISIONAL section is rewritten** (text below): the Source/Sink sketch is removed, and
   the decided parts of `code_lowered`, the per-row whole-column calls, `skipmissing`, the
   bare-`Bool` lint, ordered levels, source ordering, streaming sources and the stream adapter are
   recorded.
5. **Exact text.** The full proposed file is the current `chui-frames.md` with the edits below.

### Exact edits

**(a) Preamble.** Replace the **Sources** and **Format** bullets, and append to the **Names**
bullet:

```markdown
- **Sources:** ADR-0009 §2, §3, §6, §7; ADR-0010 (format, rule 6); ADR-0014 (this file's update
  to ChuiFrames' phase-1 ADRs); ChuiFrames' ADR-0001 to ADR-0004 (accepted 2026-10-20, ChuiFrames
  `docs/adr/`); the prototype (`reference/prototype/DESIGN.md` §2–§3) for the `c.x` grammar only.
  Where an entry promises more than the prototype does, it says "new work" and cites the probe
  (E-35).
- **Format:** see [README.md](README.md). The Source and Sink interface is CF-011 to CF-016
  (ChuiFrames ADR-0004). Undecided items are under [PROVISIONAL](#provisional).
```

```markdown
  The Source and Sink names (CF-011 to CF-016) are decided by ChuiFrames ADR-0004; whether each
  is exported is not promised, so entries and tests write them qualified (`ChuiFrames.Source`).
```

**(b) CF-001.** Replace the last Statement bullet ("Apache Arrow IPC … PROVISIONAL.") with:

```markdown
- **Scope** (ADR-0014; ChuiFrames ADR-0002 rule 5). "ChuiFrames function or verb" means a
  function ChuiFrames owns. Methods ChuiFrames adds to **another package's** generic function
  (the DataAPI interop methods: `DataAPI.innerjoin`, `DataAPI.groupby`, `DataAPI.describe`,
  `DataAPI.nrow`, …) are not covered. Each of them takes at least one ChuiFrames frame argument,
  because a method for plain Tables.jl inputs would be type piracy. So `DataAPI.innerjoin` on two
  `NamedTuple`s stays a `MethodError`. ChuiFrames' own verbs for the same operations
  (`inner_join`, `group_by`, …) are covered.
- Apache Arrow IPC is the ecosystem's on-disk and inter-process columnar format (ADR-0009 §3).
  Files are read and written through CF-016.
```

**(c) CF-005.** In the bullet "**Known cost: silent `Bool` constants.**", replace its last
sentence ("A lint for this is PROVISIONAL.") with:

```markdown
ChuiFrames warns, at build time, when a
  bare `Bool` is passed to `mutate`/`summarise` (ChuiFrames ADR-0002 rule 17); the warning is not
  part of this entry.
```

Add a bullet after it:

```markdown
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
```

In the Example block, insert after the `(c.x .+ 1) == (c.x .+ 1)` line:

```markdown
(c.x == missing, missing == c.x)        # (false, false): a Bool, never missing
```

Replace the `test:` paragraph with:

```markdown
test: `CF-005 no plain-operator overloads` — checks that `==`/`isequal` return `Bool`s with
structural meaning on leaf and compound nodes (`c.x`, `c.x .+ 1`, `sum(c.x)`, a node with a
`missing` constant), that `c.x == missing` and `missing == c.x` are `false`, that equal nodes
have equal hashes and work as `Dict` keys, and that `c.x + 1`, `c.x > 1` and `!c.x` throw
`MethodError`.
```

**(d) CF-008.** Insert after the paragraph that ends "its own property tests check it on random
pipelines.", before **Example**:

````markdown
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
````

**(e) New entries**, inserted after CF-010, before the `---` that precedes `## PROVISIONAL`:

````markdown
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

**Statement.** (ChuiFrames ADR-0004 rules 1 and 3; Tables.jl 1.14, LC-10 in ChuiFrames'
`docs/research/lane-checks.md`.)
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
````

**(f) PROVISIONAL.** Keep the section's first sentence and the bullets "Indexing forms of `c`",
"The verb set and names" and "The frame types". Replace every other bullet, and delete the
`#### Source and Sink interface (sketch)` subsection with everything under it, with:

```markdown
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
```

**★ for the user:**
- **Q1.** Grant the same in-place exception as ADR-0012 Q1 for the compatible edits (b)–(d) to
  CF-001, CF-005 and CF-008 (recommended: yes; none changes what a passing implementation must
  do, except CF-005's test, which checks a promise CF-005 already makes)? Note that CF-001's
  *Scope* bullet **narrows** what a consumer may rely on: a broad reading of the old text would
  have covered DataAPI interop methods on plain Tables.jl inputs (piracy, so never implementable).
  The alternative is to retire each and re-issue it under a new ID.
- **Q2.** Give the Source/Sink interface stable IDs now, as CF-011 to CF-016 (recommended: yes;
  ChuiFrames ADR-0004 says it "gets contract IDs after acceptance", and no consumer exists), or
  keep the same text under PROVISIONAL as a `####` subsection without IDs until ChuiFrames phase 3
  builds the engine side?
- **Q3.** CF-017 makes "adding a reserved keyword" a breaking change, as ChuiFrames ADR-0002
  rule 14 says. Accept it as stable now (recommended), or keep it PROVISIONAL until phase-2
  parity confirms `mutate`/`summarise`'s option names?
- **Q4.** Record the ordered-level direction (Decision 3) as the recommendation for ChuiFrames'
  phase-6 ADR (recommended), or leave the question fully open?
- **Q5.** Confirm ADR-0009's dated amendment of §2 ("plain calls are reductions" becomes "plain
  calls of the grammar's whole-column functions are whole-column calls"; recommended: yes). It
  changes no contract entry; if declined, the amendment section is withdrawn and ChuiFrames
  ADR-0002 rule 9 stays a stated exception.

**Follow-up for ChuiFrames (not decided here).** CF-012's offset rule repeats ChuiFrames ADR-0004
rule 3, which speaks of a "per-partition `Scan`", while `plan_partitions` receives one `Scan`
before the source has chosen its partitions. A single-partition source given an offset *k* and
returning it in the residual would see the engine apply *k* again. ChuiFrames' phase-3 lane should
settle whether the engine always passes `offset = 0`; the contract text follows its answer.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep the Source/Sink sketch until phase 3 | ChuiFrames ADR-0004 is accepted and replaces it; the sketch's names (`source_partitions`, `read_partition(s, p, cols; filters)`) are now wrong. |
| One entry for the whole Source/Sink interface | A downstream that writes only a sink would list rules for sources it never uses; separate IDs map `names:` to what each consumer relies on. |
| A stable ID for source ordering now | The declaration has no type or constructor yet, so no test can build one (ADR-0010: "stable IDs for undecided items" rejected). |
| Promising the `coalesce`/`something` guards and the `Bool` lint in CF-005 | They are ChuiFrames' choices, narrow and silenceable; promising them would turn each guard tweak into a contract change. |
| Read CF-001 as covering DataAPI interop methods | Making `DataAPI.innerjoin` accept two plain `NamedTuple`s is type piracy, against ADR-0009 §6 and CF-009's rule. |
| Define ordered-level order now as level order in CF-008's text | v0 has no ordered levels; the element-type route needs no text change, and phase 6 decides. |

## Consequences

- **T3 edits the user must authorize**, all in `contracts/chui-frames.md`: (a)–(f) above. The
  assembled file is ready for the user (see the lead's report). `contracts/README.md` needs no
  change: the contract version stays v0, since ChuiFrames is unreleased.
- **ChuiFrames' contract docs:** its vendored copies, if any, refresh in ChuiFrames' own commit
  (ADR-0010 rule 4). ChuiFrames' own tests implement CF-011 to CF-017 when the engine side exists
  (phase 2 for CF-017, phase 3 for the lazy paths of CF-011 to CF-013).
- **ChuiFrames ADR-0006** must require `Tables = "1.14"` (ChuiFrames ADR-0004 rule 1 already says
  so); CF-012 states it.
- **Requests R6–R10** (filed with this ADR, `requests/`) carry the upstream needs the same ADRs
  raise; R10 stays open while ChuiFrames' Task shim exists.

## Verification

- ChuiFrames ADR-0001 to ADR-0004, ADR-0014 and ADR-0015 read on ChuiFrames main c5db1cb (the
  accept commit changes only status lines and two approval notes against 685bc6a).
- `Tables.Scan`'s keyword constructor, its `offset::Int` field, and `colcmp(op, col, value)`:
  read in the installed Tables 1.14.0 source (`scan.jl` lines 151, 280, 301–326).
- `Base.isexported(Base, :SkipMissing)` is `false` on 1.13.2 and 1.10.12 (run by this lane, for
  R8).
- The assembled file was checked with `contracts/check.jl` beside unchanged copies of the other
  contract files and `adr/`: 0 errors on Julia 1.13.2 and 1.10.12; 17 entries, 17 stable, IDs
  unique and sequential; 33 julia blocks parsed; 6 Base-only blocks executed; 20 value
  expectations checked, including the new `isless(NaN, missing)`, `isless(-0.0, 0.0)` and
  `isequal(-0.0, 0.0)`.
- UNVERIFIED: every ChuiFrames example above beyond parsing (nothing is implemented); that
  `Tables.Scan` exists before 1.14.0 (ChuiFrames ADR-0004 lists the same gap).

## Revisit when

- ChuiFrames phase 2 or 3 renames a Source/Sink function, a reserved keyword, or the lazy entry
  points.
- ChuiFrames accepts the ordering declaration's type (source ordering gets an ID) or the
  streaming variant (ChuiTypes' stream API, R10).
- ChuiFrames' phase-6 ADR decides ordered levels.
