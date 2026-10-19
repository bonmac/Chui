module Tidy

using Statistics

export Tbl, c, nrow, desc, lazy, explain, rows, optimize, physical, execute, Source,
       select, mutate, summarise, arrange, group_by, ungroup, head, nest, unnest,
       ⨟, Map, Filter, MapCat, Take, foldxl, foldxt

# ════════════════════════════════════════════════════════════════════════════
# Transducers: source- and sink-independent transformations of reducing
# functions. `xf(rf)` returns a new rf; composition fuses steps into one pass.
# ════════════════════════════════════════════════════════════════════════════
abstract type Transducer end
struct Map{F} <: Transducer; f::F end
struct Filter{P} <: Transducer; p::P end
struct MapCat{F} <: Transducer; f::F end
struct Take <: Transducer; n::Int end
struct Composed{T<:Tuple} <: Transducer; xfs::T end

struct Reduced{T}; value::T end     # early-termination signal
unreduced(x) = x isa Reduced ? x.value : x

(x::Map)(rf)    = (acc, v) -> rf(acc, x.f(v))
(x::Filter)(rf) = (acc, v) -> x.p(v) ? rf(acc, v) : acc
(x::MapCat)(rf) = function (acc, v)
    for u in x.f(v)
        acc = rf(acc, u)
        acc isa Reduced && return acc
    end
    acc
end
function (x::Take)(rf)
    seen = Ref(0)
    function (acc, v)
        seen[] >= x.n && return Reduced(acc)
        seen[] += 1
        acc = rf(acc, v)
        acc isa Reduced || seen[] < x.n ? acc : Reduced(acc)
    end
end
(x::Composed)(rf) = foldr((xf, r) -> xf(r), x.xfs; init = rf)
hastake(x::Transducer) = any(t -> t isa Union{Take,TakeRows}, xfs(x))

xfs(x::Transducer) = (x,)
xfs(x::Composed) = x.xfs
# `a ⨟ b`: a then b (reads left to right, like |>)
⨟(a::Transducer, b::Transducer) = Composed((xfs(a)..., xfs(b)...))
⨟(f, g) = g ∘ f

function foldxl(rf, xf::Transducer, itr; init)
    f = xf(rf)
    acc = init
    for v in itr
        acc = f(acc, v)
        acc isa Reduced && return acc.value
    end
    acc
end

# Parallel fold: contiguous batches per task, then an in-order `combine`
# (so `combine` need only be associative). `init` is a factory: one fresh
# accumulator per task. Plans containing Take run sequentially.
function foldxt(rf, xf::Transducer, itr; init, combine = rf, ntasks = Threads.nthreads())
    hastake(xf) && return foldxl(rf, xf, itr; init = init())   # Take needs one shared counter
    parts = collect(itr)
    isempty(parts) && return init()
    batches = Iterators.partition(parts, cld(length(parts), ntasks))
    tasks = map(b -> Threads.@spawn(foldxl(rf, xf, b; init = init())), batches)
    reduce(combine, map(fetch, tasks))
end

# ════════════════════════════════════════════════════════════════════════════
# Monoids: aggregations as partial / associative combine / final, so they can
# run per morsel and per thread and merge afterwards (mean = (sum, n), etc.)
# ════════════════════════════════════════════════════════════════════════════
abstract type Monoid end
struct Sum <: Monoid end
struct Prod <: Monoid end
struct Count <: Monoid end
struct CountTrue <: Monoid end                     # `count`: Bool-only, like Base
struct Max <: Monoid end
struct Min <: Monoid end
struct Extrema <: Monoid end
struct First <: Monoid end
struct Last <: Monoid end
struct AnyM <: Monoid end
struct AllM <: Monoid end
struct Mean <: Monoid end
struct Moments <: Monoid; std::Bool end              # var/std via Chan's parallel merge
struct ReduceM{F} <: Monoid; op::F end              # Julia's `reduce` contract: op is associative
struct MapM{F,M<:Monoid} <: Monoid; f::F; inner::M end

partial(::Sum, v) = sum(v);           combine(::Sum, a, b) = a + b
partial(::Prod, v) = prod(v);         combine(::Prod, a, b) = a * b
partial(::Count, v) = length(v);      combine(::Count, a, b) = a + b
partial(::CountTrue, v) = count(v);   combine(::CountTrue, a, b) = a + b
partial(::Max, v) = maximum(v);       combine(::Max, a, b) = max(a, b)
partial(::Min, v) = minimum(v);       combine(::Min, a, b) = min(a, b)
partial(::Extrema, v) = extrema(v);   combine(::Extrema, a, b) = (min(a[1], b[1]), max(a[2], b[2]))
partial(::First, v) = first(v);       combine(::First, a, b) = a
partial(::Last, v) = last(v);         combine(::Last, a, b) = b
partial(::AnyM, v) = any(v);          combine(::AnyM, a, b) = a | b
partial(::AllM, v) = all(v);          combine(::AllM, a, b) = a & b
partial(::Mean, v) = (sum(float, v), length(v))   # float sum, like Statistics.mean: no Int overflow
combine(::Mean, a, b) = (a[1] + b[1], a[2] + b[2])
final(::Mean, a) = a[1] / a[2]
partial(::Moments, v) = (m = mean(v); (length(v), m, sum(x -> abs2(x - m), v)))
function combine(::Moments, (na, ma, Ma), (nb, mb, Mb))
    n = na + nb
    δ = mb - ma
    (n, ma + δ * nb / n, Ma + Mb + δ^2 * na * nb / n)
end
final(m::Moments, (n, _, M2)) = (v = M2 / (n - 1); m.std ? sqrt(v) : v)
partial(m::ReduceM, v) = reduce(m.op, v); combine(m::ReduceM, a, b) = m.op(a, b)
partial(m::MapM, v) = partial(m.inner, map(m.f, v))
combine(m::MapM, a, b) = combine(m.inner, a, b)
final(m::MapM, a) = final(m.inner, a)
final(::Monoid, a) = a

Base.show(io::IO, m::Monoid) = print(io, nameof(typeof(m)))
Base.show(io::IO, m::Moments) = print(io, m.std ? "Std" : "Var")
Base.show(io::IO, m::MapM) = print(io, "MapM(", fname(m.f), ", ", m.inner, ")")

# ════════════════════════════════════════════════════════════════════════════
# Expressions: deferred column computations (the stand-in for R's quosures)
# ════════════════════════════════════════════════════════════════════════════
abstract type Node end
struct Col <: Node; name::Symbol end
struct Lit{T} <: Node; value::T end
struct Desc <: Node; inner::Node end
struct Slot <: Node; i::Int end      # a finished aggregate, used when finalizing monoids
struct Call <: Node
    f::Any
    args::Vector{Node}
    whole::Bool        # true: f gets whole columns (reduction); false: f is broadcast per element
    label::String
    agg::Any           # the Monoid behind a decomposable reduction, else nothing
end

node(x::Node) = x
node(x) = Lit(x)

# `c.mass`, `c[:mass]`, `c["my var"]`: Ibis-style deferred column references
struct Deferred end
Base.getproperty(::Deferred, s::Symbol) = Col(s)
Base.getindex(::Deferred, s) = Col(Symbol(s))
const c = Deferred()

Base.show(io::IO, x::Col) = print(io, x.name)
Base.show(io::IO, x::Lit) = show(io, x.value)
Base.show(io::IO, x::Lit{<:Base.RefValue}) = show(io, x.value[])
Base.show(io::IO, x::Desc) = print(io, "desc(", x.inner, ")")
Base.show(io::IO, x::Slot) = print(io, "slot", x.i)
Base.show(io::IO, x::Call) = print(io, x.label)

fname(f) = (s = f isa Function ? string(nameof(f)) : repr(f); startswith(s, "#") ? "λ" : s)
isop(s) = Base.isbinaryoperator(Symbol(s)) && !all(isletter, s)

# Elementwise: Julia's own dot syntax. `f.(c.x, 1)` and `c.x .+ 1` build nodes
struct NodeStyle <: Broadcast.BroadcastStyle end
Base.broadcastable(x::Node) = x
Broadcast.BroadcastStyle(::Type{<:Node}) = NodeStyle()
Broadcast.BroadcastStyle(s::NodeStyle, ::Broadcast.BroadcastStyle) = s
Broadcast.BroadcastStyle(s::NodeStyle, ::NodeStyle) = s
Broadcast.BroadcastStyle(s::NodeStyle, ::Broadcast.Unknown) = s
function Broadcast.broadcasted(::NodeStyle, f, args...)
    ns = Node[node(a) for a in args]
    name = fname(f)
    label = length(ns) == 2 && isop(name) ? "($(ns[1]) .$name $(ns[2]))" : "$name.($(join(repr.(ns), ", ")))"
    Call(f, ns, false, label, nothing)
end

# `x .^ 3` lowers to literal_pow; keep it as a plain `.^` node
Broadcast.broadcasted(s::NodeStyle, ::typeof(Base.literal_pow), ::Base.RefValue{typeof(^)}, x, ::Base.RefValue{Val{p}}) where {p} =
    Broadcast.broadcasted(s, ^, x, p)

# map over columns is elementwise too, as on vectors
Base.map(f, a::Node, rest::Node...) =
    Call(f, Node[a, rest...], false, "map($(fname(f)), $(join(repr.((a, rest...)), ", ")))", nothing)

# Whole-column: plain calls reduce, exactly as on a Vector
function whole(f, name, args::Node...; prefix = (), agg = nothing)
    label = string(name, "(", join([fname.(prefix)..., repr.(args)...], ", "), ")")
    Call(f, Node[args...], true, label, agg)
end

for (f, m) in ((:sum, Sum()), (:prod, Prod()), (:maximum, Max()), (:minimum, Min()),
               (:extrema, Extrema()), (:any, AnyM()), (:all, AllM()), (:count, CountTrue()))
    @eval Base.$f(a::Node; kw...) = whole(v -> $f(v; kw...), $(string(f)), a; agg = isempty(kw) ? $m : nothing)
    @eval Base.$f(g, a::Node; kw...) =
        whole(v -> $f(g, v; kw...), $(string(f)), a; prefix = (g,), agg = isempty(kw) ? MapM(g, $m) : nothing)
end
for (f, m) in ((:length, Count()), (:first, First()), (:last, Last()))
    @eval Base.$f(a::Node) = whole($f, $(string(f)), a; agg = $m)
end
for (f, m) in ((:mean, Mean()), (:median, nothing), (:std, Moments(true)), (:var, Moments(false)))
    @eval Statistics.$f(a::Node; kw...) = whole(v -> $f(v; kw...), $(string(f)), a; agg = isempty(kw) ? $m : nothing)
end
Statistics.quantile(a::Node, p; kw...) = Call(v -> quantile(v, p; kw...), Node[a], true, "quantile($a, $p)", nothing)

Base.reduce(op, a::Node; kw...) =
    whole(v -> reduce(op, v; kw...), "reduce", a; prefix = (op,), agg = isempty(kw) ? ReduceM(op) : nothing)
Base.mapreduce(f, op, a::Node, rest::Node...; kw...) =
    whole((vs...) -> mapreduce(f, op, vs...; kw...), "mapreduce", a, rest...; prefix = (f, op),
          agg = isempty(kw) && isempty(rest) ? MapM(f, ReduceM(op)) : nothing)
Base.foldl(op, a::Node; kw...) = whole(v -> foldl(op, v; kw...), "foldl", a; prefix = (op,))
Base.foldr(op, a::Node; kw...) = whole(v -> foldr(op, v; kw...), "foldr", a; prefix = (op,))

# Scans: whole-column, column-shaped results (running totals; per group when grouped)
Base.accumulate(op, a::Node; kw...) = whole(v -> accumulate(op, v; kw...), "accumulate", a; prefix = (op,))
Base.cumsum(a::Node) = whole(cumsum, "cumsum", a)
Base.cumprod(a::Node) = whole(cumprod, "cumprod", a)

# Any other whole-column function: pipe the column into it
Base.:|>(a::Node, f) = whole(f, fname(f), a)

desc(x) = Desc(node(x))
desc(s::Symbol) = Desc(Col(s))

# Row-wise expressions need no other rows, so they can run per morsel
rowwise(::Union{Col,Lit}) = true
rowwise(x::Desc) = rowwise(x.inner)
rowwise(::Slot) = false
rowwise(x::Call) = !x.whole && all(rowwise, x.args)

# Evaluation: a vectorized interpreter, one dynamic dispatch per column
ev(x::Col, cols, nr) = haskey(cols, x.name) ? cols[x.name] : error("unknown column `$(x.name)`")
ev(x::Lit, cols, nr) = x.value
ev(x::Desc, cols, nr) = ev(x.inner, cols, nr)
ev(x::Slot, env, nr) = env[x.i]
function ev(x::Call, cols, nr)
    args = map(a -> ev(a, cols, nr), x.args)
    x.whole ? x.f(args...) : x.f.(args...)
end

fit(v::AbstractVector, nr) = v
fit(v, nr) = fill(v, nr)

# ════════════════════════════════════════════════════════════════════════════
# Tables: an immutable column table (NamedTuple of vectors) + group keys
# ════════════════════════════════════════════════════════════════════════════
abstract type AbstractTbl end
struct Tbl <: AbstractTbl
    cols::NamedTuple
    groups::Vector{Symbol}
end
Tbl(nt::NamedTuple) = Tbl(nt, Symbol[])
Tbl(; kw...) = Tbl(values(kw))

nrow(t::Tbl) = isempty(t.cols) ? 0 : length(first(t.cols))
Base.getindex(t::Tbl, s::Symbol) = t.cols[s]
rows(t::Tbl) = (map(v -> v[i], t.cols) for i in 1:nrow(t))    # NamedTuple rows, for transducers
colname(s::Symbol) = s
colname(s::AbstractString) = Symbol(s)
colname(x::Col) = x.name
take(t::Tbl, idx) = Tbl(map(v -> v[idx], t.cols), t.groups)
viewcols(t::Tbl, idx) = map(v -> view(v, idx), t.cols)

function groupindices(t::Tbl)
    keycols = Tuple(t.cols[g] for g in t.groups)
    d = Dict{Any,Vector{Int}}()
    for i in 1:nrow(t)
        push!(get!(Vector{Int}, d, map(v -> v[i], keycols)), i)
    end
    [(k, d[k]) for k in sort!(collect(keys(d)))]
end

# Evaluate an expression to a full-length column, per group when grouped
# (so `c.x .- mean(c.x)` is a window function on grouped data, as in dplyr).
function column(t::Tbl, e::Node)
    nr = nrow(t)
    isempty(t.groups) && return fit(ev(e, t.cols, nr), nr)
    parts = [(idx, fit(ev(e, viewcols(t, idx), length(idx)), length(idx))) for (_, idx) in groupindices(t)]
    out = Vector{mapreduce(p -> eltype(p[2]), promote_type, parts)}(undef, nr)
    for (idx, v) in parts
        out[idx] = v
    end
    out
end

# ════════════════════════════════════════════════════════════════════════════
# Verbs are values (Steps). Called on a Tbl they run now; on a LazyTbl they
# append to its plan; `⨟` composes them into reusable pipelines.
# ════════════════════════════════════════════════════════════════════════════
abstract type Step end
struct FilterStep <: Step; pred::Node end
struct MutateStep <: Step; kw::Vector{Pair{Symbol,Node}} end
struct SelectStep <: Step; cols::Vector{Symbol} end
struct GroupStep <: Step; keys::Vector{Symbol} end
struct UngroupStep <: Step end
struct SummariseStep <: Step; kw::Vector{Pair{Symbol,Node}} end
struct ArrangeStep <: Step; keys::Vector{Node} end
struct HeadStep <: Step; n::Int end
struct NestStep <: Step; by::Vector{Symbol}; name::Symbol end
struct UnnestStep <: Step; col::Symbol end
struct Pipeline <: Step; steps::Vector{Step} end

steps(p::Pipeline) = p.steps
steps(s::Step) = Step[s]
⨟(a::Step, b::Step) = Pipeline([steps(a); steps(b)])
(p::Pipeline)(t::Tbl) = foldl((t, s) -> s(t), p.steps; init = t)
(s::Step)(t::Tbl) = apply(t, s)

kwnodes(kw) = Pair{Symbol,Node}[k => node(v) for (k, v) in pairs(kw)]

Base.filter(p::Node) = FilterStep(p)
Base.filter(t::AbstractTbl, p::Node) = FilterStep(p)(t)
mutate(; kw...) = MutateStep(kwnodes(kw))
mutate(t::AbstractTbl; kw...) = mutate(; kw...)(t)
select(cs...) = SelectStep(Symbol[colname(x) for x in cs])
select(t::AbstractTbl, cs...) = select(cs...)(t)
group_by(ks...) = GroupStep(Symbol[colname(k) for k in ks])
group_by(t::AbstractTbl, ks...) = group_by(ks...)(t)
const ungroup = UngroupStep()
summarise(; kw...) = SummariseStep(kwnodes(kw))
summarise(t::AbstractTbl; kw...) = summarise(; kw...)(t)
arrange(ks...) = ArrangeStep(Node[k isa Symbol ? Col(k) : node(k) for k in ks])
arrange(t::AbstractTbl, ks...) = arrange(ks...)(t)
head(n::Integer) = HeadStep(n)
head(t::AbstractTbl, n::Integer) = head(n)(t)
nest(by...; name = :data) = NestStep(Symbol[colname(k) for k in by], name)
nest(t::AbstractTbl, by...; name = :data) = nest(by...; name)(t)
unnest(col) = UnnestStep(colname(col))
unnest(t::AbstractTbl, col) = unnest(col)(t)

apply(t::Tbl, s::FilterStep) = take(t, findall(isequal(true), column(t, s.pred)))   # drops missing, like NA
apply(t::Tbl, s::GroupStep) = Tbl(t.cols, s.keys)
apply(t::Tbl, ::UngroupStep) = Tbl(t.cols)
apply(t::Tbl, s::HeadStep) = take(t, 1:min(s.n, nrow(t)))

function apply(t::Tbl, s::SelectStep)
    names = Tuple(s.cols)
    Tbl(NamedTuple{names}(map(n -> t.cols[n], names)), filter(in(names), t.groups))
end

function apply(t::Tbl, s::MutateStep)
    for (name, e) in s.kw                       # sequential: later columns may use earlier ones
        t = Tbl(merge(t.cols, NamedTuple{(name,)}((column(t, e),))), t.groups)
    end
    t
end

function apply(t::Tbl, s::SummariseStep)
    groups = isempty(t.groups) ? [((), collect(1:nrow(t)))] : groupindices(t)
    keycols = [g => [k[i] for (k, _) in groups] for (i, g) in enumerate(t.groups)]
    aggcols = [name => [ev(e, viewcols(t, idx), length(idx)) for (_, idx) in groups] for (name, e) in s.kw]
    Tbl((; keycols..., aggcols...))
end

function apply(t::Tbl, s::ArrangeStep)
    flat = Tbl(t.cols)
    perm = collect(1:nrow(t))
    for k in reverse(s.keys)                    # stable sorts, last key first
        v = column(flat, k)[perm]
        perm = perm[sortperm(v; rev = k isa Desc)]
    end
    take(t, perm)
end

# purrr/tidyr list-columns: one row per group, the rest nested as a Tbl
function apply(t::Tbl, s::NestStep)
    by = isempty(s.by) ? t.groups : s.by
    groups = groupindices(Tbl(t.cols, by))
    rest = Tuple(n for n in keys(t.cols) if n ∉ by)
    data = [Tbl(NamedTuple{rest}(map(n -> t.cols[n][idx], rest))) for (_, idx) in groups]
    Tbl((; [g => [k[i] for (k, _) in groups] for (i, g) in enumerate(by)]..., s.name => data))
end

# unnest is MapCat: each row expands to the rows of its nested value
function apply(t::Tbl, s::UnnestStep)
    inner = t.cols[s.col]
    outer = Tuple(n for n in keys(t.cols) if n != s.col)
    isempty(inner) && return Tbl(NamedTuple{outer}(map(n -> t.cols[n], outer)), filter(!=(s.col), t.groups))
    lens = [x isa Tbl ? nrow(x) : length(x) for x in inner]
    rep = reduce(vcat, [fill(i, l) for (i, l) in enumerate(lens)])
    outercols = NamedTuple{outer}(map(n -> t.cols[n][rep], outer))
    innercols = first(inner) isa Tbl ?
        map((vs...) -> reduce(vcat, vs), map(x -> x.cols, inner)...) :
        NamedTuple{(s.col,)}((reduce(vcat, inner),))
    Tbl(merge(outercols, innercols), filter(!=(s.col), t.groups))
end

# ════════════════════════════════════════════════════════════════════════════
# Sources: what a scan reads. Each source is cut into partitions (row ranges,
# Arrow record batches, Parquet row groups) that can be read independently.
# Interface:
#   schema(s)                 -> Vector{Pair{Symbol,Type}}
#   partitions(s, morsel)     -> Vector of partition handles
#   read_partition(s, p, cols)-> Tbl with just `cols`
#   stats(s, p, col)          -> (min, max) or nothing   (for pruning)
#   describe(s)               -> String
# ════════════════════════════════════════════════════════════════════════════
abstract type Source end
stats(::Source, p, col) = nothing
source_groups(::Source) = Symbol[]
threadsafe(::Source) = true
schemanames(s::Source) = first.(schema(s))

struct TblSource <: Source; t::Tbl end
schema(s::TblSource) = [n => eltype(v) for (n, v) in pairs(s.t.cols)]
partitions(s::TblSource, morsel) = collect(Iterators.partition(1:nrow(s.t), morsel))
read_partition(s::TblSource, r, cols) = Tbl(NamedTuple{Tuple(cols)}(map(n -> view(s.t.cols[n], r), Tuple(cols))))
describe(s::TblSource) = "Tbl $(nrow(s.t)) × $(length(s.t.cols))"
source_groups(s::TblSource) = s.t.groups

# ════════════════════════════════════════════════════════════════════════════
# Logical plan: a source plus the user's steps, exactly as written.
# ════════════════════════════════════════════════════════════════════════════
struct LazyTbl <: AbstractTbl
    src::Source
    steps::Vector{Step}
end
lazy(t::Tbl) = LazyTbl(TblSource(t), Step[])
lazy(s::Source) = LazyTbl(s, Step[])
(s::Step)(l::LazyTbl) = LazyTbl(l.src, [l.steps; s])
(p::Pipeline)(l::LazyTbl) = LazyTbl(l.src, [l.steps; p.steps])

streamable(s::FilterStep) = rowwise(s.pred)
streamable(s::MutateStep) = all(rowwise ∘ last, s.kw)
streamable(::Union{SelectStep,GroupStep,UngroupStep,HeadStep,UnnestStep}) = true
streamable(::Step) = false

refs(x::Col) = Set([x.name])
refs(::Union{Lit,Slot}) = Set{Symbol}()
refs(x::Desc) = refs(x.inner)
refs(x::Call) = mapreduce(refs, union, x.args; init = Set{Symbol}())

# ════════════════════════════════════════════════════════════════════════════
# Optimizer: logical → logical rewrites, each one semantics-preserving.
#   1. split `a .& b` filters into conjuncts
#   2. push row-wise filters down past row-wise mutates, selects, group_by,
#      arrange — into the scan when nothing is left in front of them
#   3. projection pushdown + dead-column elimination (backward liveness)
# ════════════════════════════════════════════════════════════════════════════
struct Scan
    src::Source
    cols::Vector{Symbol}      # projection pushed into the reader
    preds::Vector{Node}       # filters pushed into the scan (also used for pruning)
end
struct Optimized
    scan::Scan
    steps::Vector{Step}
    log::Vector{String}       # which rules fired
end

isand(e) = e isa Call && !e.whole && e.f === (&) && length(e.args) == 2
conjuncts(e::Node) = isand(e) ? [conjuncts(e.args[1]); conjuncts(e.args[2])] : Node[e]

function split_filters(steps, log)
    out = Step[]
    for s in steps
        if s isa FilterStep && isand(s.pred)
            cs = conjuncts(s.pred)
            push!(log, "split $(s) into $(length(cs)) conjuncts")
            append!(out, FilterStep.(cs))
        else
            push!(out, s)
        end
    end
    out
end

defines(s::MutateStep) = Set(first.(s.kw))
# can a row-wise filter move in front of `prev`?
commutes(prev::MutateStep, f) = streamable(prev) && isempty(intersect(refs(f.pred), defines(prev)))
commutes(prev::SelectStep, f) = refs(f.pred) ⊆ Set(prev.cols)   # else eager errors on the dropped column
commutes(::Union{GroupStep,UngroupStep,ArrangeStep}, f) = true
commutes(::Step, f) = false

function push_filters(steps, log)
    steps = copy(steps)
    preds = Node[]
    i = 1
    while i <= length(steps)
        s = steps[i]
        if s isa FilterStep && rowwise(s.pred)
            j = i
            while j > 1 && commutes(steps[j-1], s)
                steps[j-1], steps[j] = steps[j], steps[j-1]
                j -= 1
            end
            j < i && push!(log, "pushed $(s) past $(i - j) step(s)")
            if j == 1
                push!(preds, s.pred)
                push!(log, "pushed $(s) into the scan")
                deleteat!(steps, 1)
                continue          # the step now at i was already visited
            end
        end
        i += 1
    end
    preds, steps
end

function groups_before(groups, steps)
    out = Vector{Vector{Symbol}}(undef, length(steps))
    for (i, s) in enumerate(steps)
        out[i] = groups
        groups = groups_after(groups, Step[s])
    end
    out
end

# Backward liveness: which columns does each step need from its input?
# `nothing` means "all of them".
function prune_columns(src, preds, steps, log)
    gb = groups_before(source_groups(src), steps)
    need = nothing
    kept = Step[]
    for i in reverse(eachindex(steps))
        s = steps[i]
        if s isa SelectStep
            need = Set(s.cols)
        elseif s isa SummariseStep
            need = union(Set(gb[i]), (refs(e) for (_, e) in s.kw)...)
        elseif s isa MutateStep
            if need !== nothing
                live = Pair{Symbol,Node}[]
                for (n, e) in reverse(s.kw)
                    n in need || (push!(log, "dropped dead column `$n`"); continue)
                    pushfirst!(live, n => e)
                    need = union(setdiff(need, [n]), refs(e))
                end
                isempty(live) && continue
                s = MutateStep(live)
            end
        elseif s isa FilterStep
            need = need === nothing ? nothing : union(need, refs(s.pred))
        elseif s isa GroupStep
            need = need === nothing ? nothing : union(need, s.keys)
        elseif s isa ArrangeStep
            need = need === nothing ? nothing : union(need, (refs(k) for k in s.keys)...)
        elseif s isa Union{NestStep,UnnestStep}
            need = nothing
        end
        pushfirst!(kept, s)
    end
    all = schemanames(src)
    need = need === nothing ? Set(all) : union(need, (refs(p) for p in preds)..., source_groups(src))
    cols = [n for n in all if n in need]
    length(cols) < length(all) && push!(log, "projection pushdown: read $(length(cols)) of $(length(all)) columns")
    cols, kept
end

function optimize(l::LazyTbl)
    log = String[]
    steps = split_filters(l.steps, log)
    preds, steps = push_filters(steps, log)
    cols, steps = prune_columns(l.src, preds, steps, log)
    Optimized(Scan(l.src, cols, preds), steps, log)
end

# ════════════════════════════════════════════════════════════════════════════
# Physical plan: which partitions to read, one fused per-partition pipeline,
# a sink (monoid hash-aggregate or materialize), then in-memory steps.
# ════════════════════════════════════════════════════════════════════════════
struct PhysicalPlan
    scan::Scan
    parts::Vector{Any}        # partitions that survived min/max pruning
    nparts::Int               # before pruning
    stream::Vector{Step}      # fused, run per partition
    sequential::Bool          # a head() needs one shared row counter
    agg::Any                  # monoid plan for a summarise sink, or nothing
    groups::Vector{Symbol}    # grouping at the sink
    rest::Vector{Step}        # after the pipeline breaker, in memory
    morsel::Int
end

const CMP = Dict{Any,Function}(
    (>)  => (lo, hi, v) -> hi > v,  (>=) => (lo, hi, v) -> hi >= v,
    (<)  => (lo, hi, v) -> lo < v,  (<=) => (lo, hi, v) -> lo <= v,
    (==) => (lo, hi, v) -> lo <= v <= hi)
const FLIP = Dict{Any,Any}((>) => (<), (>=) => (<=), (<) => (>), (<=) => (>=), (==) => (==))

# `col op literal` conjuncts, usable against per-partition (min, max)
function prunable(e::Node)
    e isa Call && !e.whole && length(e.args) == 2 && haskey(CMP, e.f) || return nothing
    a, b = e.args
    a isa Col && b isa Lit && !(b.value isa Base.RefValue) && return (a.name, e.f, b.value)
    b isa Col && a isa Lit && !(a.value isa Base.RefValue) && return (b.name, FLIP[e.f], a.value)
    nothing
end

function may_match(src, p, checks)
    for (col, op, v) in checks
        st = stats(src, p, col)
        st === nothing && continue
        any(x -> x isa AbstractFloat && isnan(x), st) && continue   # NaN stats prove nothing
        ok = try CMP[op](st[1], st[2], v) catch; true end
        ok || return false
    end
    true
end

function physical(o::Optimized; morsel = 65_536)
    s = o.scan
    parts = partitions(s.src, morsel)
    checks = filter(!isnothing, prunable.(s.preds))
    kept = isempty(checks) ? parts : filter(p -> may_match(s.src, p, checks), parts)
    k = something(findfirst(!streamable, o.steps), length(o.steps) + 1)
    stream, rest = o.steps[1:k-1], o.steps[k:end]
    agg = !isempty(rest) && first(rest) isa SummariseStep ? decompose(first(rest)) : nothing
    groups = groups_after(source_groups(s.src), stream)
    PhysicalPlan(s, collect(Any, kept), length(parts), stream, any(x -> x isa HeadStep, stream),
                 agg, groups, rest, morsel)
end
physical(l::LazyTbl; morsel = 65_536) = physical(optimize(l); morsel)

# ════════════════════════════════════════════════════════════════════════════
# Execution: fold the fused transducer over partitions; parallel unless a
# head() needs a shared counter; monoid partials merge without materializing.
# ════════════════════════════════════════════════════════════════════════════

# Like Take, but counts rows inside morsels and truncates the last one
struct TakeRows <: Transducer; n::Int end
function (x::TakeRows)(rf)
    seen = Ref(0)
    function (acc, t)
        left = x.n - seen[]
        left <= 0 && return Reduced(acc)
        t = nrow(t) > left ? take(t, 1:left) : t
        seen[] += nrow(t)
        acc = rf(acc, t)
        acc isa Reduced || seen[] < x.n ? acc : Reduced(acc)
    end
end

transducer(s::FilterStep) = Map(t -> apply(t, s)) ⨟ Filter(t -> nrow(t) > 0)
transducer(s::HeadStep) = TakeRows(s.n)
transducer(s::Step) = Map(t -> apply(t, s))

fused(preds) = isempty(preds) ? nothing : reduce((a, b) -> a .& b, preds)

# Rewrite each aggregate in a summarise into a Slot; nothing if any is not a monoid.
lift_slots!(slots, e::Lit) = e
lift_slots!(slots, e::Union{Col,Desc,Slot}) = nothing
function lift_slots!(slots, e::Call)
    if e.whole
        (e.agg === nothing || !all(rowwise, e.args)) && return nothing
        push!(slots, (e.agg, e.args))
        return Slot(length(slots))
    end
    args = map(a -> lift_slots!(slots, a), e.args)
    any(isnothing, args) && return nothing
    Call(e.f, Node[args...], false, e.label, nothing)
end

function decompose(s::SummariseStep)
    slots = Tuple{Monoid,Vector{Node}}[]
    finals = Pair{Symbol,Node}[]
    for (name, e) in s.kw
        e2 = lift_slots!(slots, e)
        e2 === nothing && return nothing
        push!(finals, name => e2)
    end
    (; slots, finals)
end

function partial_rf(plan, groups)
    function (acc, t)
        for (k, idx) in groupindices(Tbl(t.cols, groups))
            cols = viewcols(t, idx)
            parts = Any[partial(m, map(a -> ev(a, cols, length(idx)), args)...) for (m, args) in plan.slots]
            acc[k] = haskey(acc, k) ? merge_parts(plan, acc[k], parts) : parts
        end
        acc
    end
end
merge_parts(plan, a, b) = Any[combine(m, x, y) for ((m, _), x, y) in zip(plan.slots, a, b)]

function finish(plan, acc, groups)
    ks = sort!(collect(keys(acc)))
    keycols = [g => [k[i] for k in ks] for (i, g) in enumerate(groups)]
    env(k) = Any[final(m, a) for ((m, _), a) in zip(plan.slots, acc[k])]
    envs = map(env, ks)
    aggcols = [name => [ev(e, en, 1) for en in envs] for (name, e) in plan.finals]
    Tbl((; keycols..., aggcols...))
end

groups_after(groups, steps) = foldl((g, s) -> s isa GroupStep ? s.keys : s isa UngroupStep ? Symbol[] :
                                              s isa SelectStep ? filter(in(s.cols), g) :
                                              s isa UnnestStep ? filter(!=(s.col), g) : g, steps; init = groups)

function vcat_tbls(chunks)
    names = keys(first(chunks).cols)
    Tbl(NamedTuple{names}(Tuple(reduce(vcat, [ch.cols[n] for ch in chunks]) for n in names)), first(chunks).groups)
end

function empty_scan(s::Scan)
    types = Dict(schema(s.src))
    Tbl(NamedTuple{Tuple(s.cols)}(Tuple(Vector{types[n]}() for n in s.cols)), filter(in(s.cols), source_groups(s.src)))
end

function execute(pp::PhysicalPlan)
    s = pp.scan
    g0 = filter(in(s.cols), source_groups(s.src))
    lk = ReentrantLock()
    read(p) = threadsafe(s.src) ? read_partition(s.src, p, s.cols) : lock(() -> read_partition(s.src, p, s.cols), lk)
    pred = fused(s.preds)
    scanxf = pred === nothing ? (Map(p -> Tbl(read(p).cols, g0)),) :
                                (Map(p -> Tbl(read(p).cols, g0)), xfs(transducer(FilterStep(pred)))...)
    xf = Composed((scanxf..., (x for st in pp.stream for x in xfs(transducer(st)))...))
    fold(rf, init, comb) = pp.sequential ? foldxl(rf, xf, pp.parts; init = init()) :
                                           foldxt(rf, xf, pp.parts; init, combine = comb)
    emptycase() = Pipeline(pp.stream)(pred === nothing ? empty_scan(s) : filter(empty_scan(s), pred))
    rest = pp.rest
    if pp.agg !== nothing
        acc = fold(partial_rf(pp.agg, pp.groups), () -> Dict{Any,Vector{Any}}(),
                   (a, b) -> mergewith!((x, y) -> merge_parts(pp.agg, x, y), a, b))
        t = isempty(acc) ? first(rest)(emptycase()) : finish(pp.agg, acc, pp.groups)
        rest = rest[2:end]
    else
        chunks = fold((acc, t) -> push!(acc, t), () -> Tbl[], append!)
        t = isempty(chunks) ? emptycase() : vcat_tbls(chunks)
    end
    foldl((t, s) -> s(t), rest; init = t)
end

Base.collect(l::LazyTbl; morsel = 65_536) = execute(physical(l; morsel))

# ════════════════════════════════════════════════════════════════════════════
# Plan printing: Spark-style operator trees (root first, data flows up) and a
# @code_lowered-style SSA listing of the fused kernel each partition runs.
# ════════════════════════════════════════════════════════════════════════════
hdr(io, s) = (printstyled(io, "== ", s, " ==", bold = true); println(io))
brackets(xs) = "[" * join(xs, ", ") * "]"

# A tree is a root-first chain of (operator, detail) nodes; detail lines after
# the first are hung under the operator.
function tree(io, nodes)
    for (d, (op, detail)) in enumerate(nodes)
        pad = d == 1 ? "" : "   "^(d - 2) * "+- "
        lines = split(detail, '\n')
        print(io, pad)
        printstyled(io, op, bold = true, color = :cyan)
        println(io, isempty(lines[1]) ? "" : " " * lines[1])
        hang = " "^(length(pad) + 3)
        foreach(x -> (printstyled(io, hang, x, color = :light_black); println(io)), lines[2:end])
    end
end

lnode(s::FilterStep, g) = ("Filter", repr(s.pred))
lnode(s::MutateStep, g) = ("Mutate", kwstr(s.kw))
lnode(s::SelectStep, g) = ("Select", brackets(s.cols))
lnode(s::GroupStep, g) = ("GroupBy", brackets(s.keys))
lnode(::UngroupStep, g) = ("Ungroup", "")
lnode(s::SummariseStep, g) = ("Aggregate", brackets(g) * ", " * brackets(["$k = $v" for (k, v) in s.kw]))
lnode(s::ArrangeStep, g) = ("Sort", brackets(repr.(s.keys)))
lnode(s::HeadStep, g) = ("Limit", string(s.n))
lnode(s::NestStep, g) = ("Nest", "by " * brackets(s.by) * " as $(s.name)")
lnode(s::UnnestStep, g) = ("Unnest", string(s.col))

function step_nodes(steps, groups; tag = "")
    gb = groups_before(groups, steps)
    [(tag * first(lnode(s, gb[i])), last(lnode(s, gb[i]))) for (i, s) in enumerate(steps)]
end

function logical_nodes(src, steps)
    nodes = reverse(step_nodes(steps, source_groups(src)))
    push!(nodes, ("Scan", describe(src) * " " * brackets(schemanames(src))))
end

function optimized_nodes(o::Optimized)
    s = o.scan
    nodes = reverse(step_nodes(o.steps, source_groups(s.src)))
    pushed = isempty(s.preds) ? "" : "\nPushedFilters: " * brackets(repr.(s.preds))
    push!(nodes, ("Scan", describe(s.src) * " " * brackets(s.cols) * pushed))
end

aggfns(plan) = [string(m, "(", join(repr.(args), ", "), ")") for (m, args) in plan.slots]
ntasks(pp) = pp.sequential ? 1 : min(Threads.nthreads(), max(1, length(pp.parts)))

function physical_nodes(pp::PhysicalPlan)
    s = pp.scan
    nodes = Tuple{String,String}[]
    rest = pp.agg === nothing ? pp.rest : pp.rest[2:end]
    gafter = pp.agg === nothing ? pp.groups : Symbol[]
    append!(nodes, reverse([(op, d * "   ⟨in memory⟩") for (op, d) in step_nodes(rest, gafter)]))
    if pp.agg !== nothing
        fns = aggfns(pp.agg)
        push!(nodes, ("HashAggregate", "keys=$(brackets(pp.groups)), functions=$(brackets(["final " * f for f in fns]))"))
        push!(nodes, ("Exchange", "merge partials in partition order ⟨$(ntasks(pp)) task(s) → 1⟩"))
        push!(nodes, ("*(1) HashAggregate", "keys=$(brackets(pp.groups)), functions=$(brackets(["partial " * f for f in fns]))"))
    else
        push!(nodes, ("Materialize", "concat partition results"))
    end
    stream = [(op, op == "*(1) Limit" ? d * "   ⟨shared row counter; stops the scan early⟩" : d)
              for (op, d) in step_nodes(pp.stream, source_groups(s.src); tag = "*(1) ")]
    append!(nodes, reverse(stream))
    pred = fused(s.preds)
    pred === nothing || push!(nodes, ("*(1) Filter", repr(pred) * "   ⟨pushed down, fused⟩"))
    pruned = pp.nparts - length(pp.parts)
    mode = pp.sequential ? "sequential" : "parallel, $(ntasks(pp)) task(s) on $(Threads.nthreads()) thread(s)"
    push!(nodes, ("*(1) Scan", describe(s.src) *
        "\nReadSchema: " * brackets(["$n::$(Dict(schema(s.src))[n])" for n in s.cols]) *
        "\nPartitions: $(length(pp.parts))/$(pp.nparts)" * (pruned > 0 ? " (pruned $pruned by min/max statistics)" : "") *
        "\nExecution: $mode"))
    nodes
end

# ── @code_lowered-style listing ──
mutable struct SSA
    lines::Vector{Tuple{String,String,String}}   # (lhs, rhs, comment)
    slots::Vector{String}
end
SSA() = SSA(Tuple{String,String,String}[], String[])
emit!(L::SSA, rhs, comment = "") = (push!(L.lines, ("%$(length(L.lines) + 1)", rhs, comment)); "%$(length(L.lines))")

low!(L, e::Col, t) = "$t.$(e.name)"
low!(L, e::Lit, t) = repr(e.value isa Base.RefValue ? e.value[] : e.value)
low!(L, e::Desc, t) = low!(L, e.inner, t)
low!(L, e::Slot, t) = L.slots[e.i]
function low!(L, e::Call, t)
    e.whole && return emit!(L, e.label)
    a = [low!(L, x, t) for x in e.args]
    name = fname(e.f)
    emit!(L, length(a) == 2 && isop(name) ? "$(a[1]) .$name $(a[2])" : "$name.($(join(a, ", ")))")
end

lowstep!(L, s::FilterStep, t) = (m = low!(L, s.pred, t); emit!(L, "$t[$m, :]", "filter"))
function lowstep!(L, s::MutateStep, t)
    for (n, e) in s.kw
        v = low!(L, e, t)
        t = emit!(L, "(; $t..., $n = $v)", "mutate")
    end
    t
end
lowstep!(L, s::SelectStep, t) = emit!(L, "$t[:, $(brackets(s.cols))]", "select")
lowstep!(L, s::GroupStep, t) = emit!(L, "setgroups($t, $(brackets(s.keys)))", "metadata only")
lowstep!(L, ::UngroupStep, t) = emit!(L, "setgroups($t, [])", "metadata only")
lowstep!(L, s::HeadStep, t) = emit!(L, "first($t, $(s.n) - seen[])", "returns Reduced once $(s.n) rows are seen")
lowstep!(L, s::UnnestStep, t) = emit!(L, "unnest($t, :$(s.col))", "MapCat")

function print_codeinfo(io, title, L::SSA, ret)
    printstyled(io, "CodeInfo(", bold = true)
    printstyled(io, "   # ", title, color = :light_black)
    println(io)
    w = maximum((length(l[1]) for l in L.lines); init = 2)
    for (i, (lhs, rhs, comment)) in enumerate(L.lines)
        print(io, i == 1 ? "1 ─ " : "│   ")
        printstyled(io, lpad(lhs, w), color = :light_blue)
        print(io, " = ", rhs)
        isempty(comment) || printstyled(io, "   # ", comment, color = :light_black)
        println(io)
    end
    println(io, "└── ", " "^(w + 3), ret)
    println(io, ")")
end

function print_lowered(io, pp::PhysicalPlan)
    s = pp.scan
    L = SSA()
    t = emit!(L, "read_partition(src, p, $(brackets(":" .* string.(s.cols))))", describe(s.src))
    pred = fused(s.preds)
    if pred !== nothing
        m = low!(L, pred, t)
        t = emit!(L, "$t[$m, :]", "pushed-down filter")
    end
    for st in pp.stream
        t = lowstep!(L, st, t)
    end
    where = "runs once per partition: $(length(pp.parts)) partition(s), $(ntasks(pp)) task(s)"
    if pp.agg === nothing
        print_codeinfo(io, "kernel(p), " * where, L, "return $t")
    else
        g = emit!(L, "groupindices($t, $(brackets(pp.groups)))", "hash on group keys")
        outs = String[]
        for (m, args) in pp.agg.slots
            a = [low!(L, x, "$t[$g[k]]") for x in args]
            push!(outs, emit!(L, "partial($m, $(join(a, ", ")))", "for each group k"))
        end
        print_codeinfo(io, "kernel(p), " * where, L, "return Dict(k => $(brackets(outs)) for k in keys($g))")
        println(io)
        F = SSA()
        acc = emit!(F, "foldl(mergewith!(combine), partials)", "in partition order")
        for (i, (m, _)) in enumerate(pp.agg.slots)
            push!(F.slots, emit!(F, "final($m, $acc[k][$i])"))
        end
        vals = [low!(F, e, "") for (_, e) in pp.agg.finals]
        ret = "(; " * join([string(g, " = k[", i, "]") for (i, g) in enumerate(pp.groups)], ", ") *
              (isempty(pp.groups) ? "" : ", ") * join(["$n = $v" for ((n, _), v) in zip(pp.agg.finals, vals)], ", ") * ")"
        print_codeinfo(io, "finalize, once per group key", F, "return " * ret)
    end
    rest = pp.agg === nothing ? pp.rest : pp.rest[2:end]
    isempty(rest) || (println(io); printstyled(io, "# then in memory: ", join(repr.(rest), " ⨟ "), color = :light_black); println(io))
end

struct Lowered; pp::PhysicalPlan end
Base.show(io::IO, x::Lowered) = print_lowered(io, x.pp)
Base.code_lowered(l::LazyTbl; morsel = 65_536) = Lowered(physical(l; morsel))

# explain(q) prints every stage, like Spark's explain(extended = true);
# explain(q; mode = :physical) and `show` print only the physical plan.
function explain(io::IO, l::LazyTbl; morsel = 65_536, mode = :extended)
    o = optimize(l)
    pp = physical(o; morsel)
    if mode === :extended
        hdr(io, "Parsed Logical Plan")
        tree(io, logical_nodes(l.src, l.steps))
        println(io)
        hdr(io, "Optimized Logical Plan")
        tree(io, optimized_nodes(o))
        isempty(o.log) || printstyled(io, join(["  · " * r for r in o.log], "\n"), color = :light_black)
        println(io, "\n")
    end
    hdr(io, "Physical Plan")
    tree(io, physical_nodes(pp))
    if mode === :extended
        println(io)
        hdr(io, "Lowered Kernel")
        print_lowered(io, pp)
    end
end
explain(l::LazyTbl; kw...) = (explain(stdout, l; kw...); nothing)
Base.show(io::IO, l::LazyTbl) = explain(io, l; mode = :physical)
# ════════════════════════════════════════════════════════════════════════════
# Display
# ════════════════════════════════════════════════════════════════════════════
kwstr(kw) = join(["$k = $v" for (k, v) in kw], ", ")
Base.show(io::IO, s::FilterStep) = print(io, "filter(", s.pred, ")")
Base.show(io::IO, s::MutateStep) = print(io, "mutate(", kwstr(s.kw), ")")
Base.show(io::IO, s::SelectStep) = print(io, "select(", join(s.cols, ", "), ")")
Base.show(io::IO, s::GroupStep) = print(io, "group_by(", join(s.keys, ", "), ")")
Base.show(io::IO, ::UngroupStep) = print(io, "ungroup")
Base.show(io::IO, s::SummariseStep) = print(io, "summarise(", kwstr(s.kw), ")")
Base.show(io::IO, s::ArrangeStep) = print(io, "arrange(", join(repr.(s.keys), ", "), ")")
Base.show(io::IO, s::HeadStep) = print(io, "head(", s.n, ")")
Base.show(io::IO, s::NestStep) = print(io, "nest(", join(s.by, ", "), "; name = ", s.name, ")")
Base.show(io::IO, s::UnnestStep) = print(io, "unnest(", s.col, ")")
Base.show(io::IO, p::Pipeline) = join(io, repr.(p.steps), " ⨟ ")

Base.show(io::IO, t::Tbl) = print(io, "Tbl(", nrow(t), "×", length(t.cols), ")")
function Base.show(io::IO, ::MIME"text/plain", t::Tbl)
    names = collect(keys(t.cols))
    grp = isempty(t.groups) ? "" : "   groups: " * join(t.groups, ", ")
    println(io, "Tbl ", nrow(t), " × ", length(names), grp)
    rows = [string.(names), [[string(t.cols[s][i]) for s in names] for i in 1:min(nrow(t), 10)]...]
    widths = [maximum(textwidth(r[j]) for r in rows) for j in eachindex(names)]
    foreach(r -> println(io, "  ", join(lpad.(r, widths), "  ")), rows)
    nrow(t) > 10 && println(io, "  … ", nrow(t) - 10, " more rows")
end

end # module
