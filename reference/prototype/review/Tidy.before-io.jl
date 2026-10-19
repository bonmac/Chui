module Tidy

using Statistics

export Tbl, c, nrow, desc, lazy, explain, rows,
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
# Lazy execution: the plan is data. The longest streamable prefix runs as one
# fused transducer over morsels, in parallel; a following summarise whose
# aggregates are monoids merges per-thread partials instead of materializing.
# ════════════════════════════════════════════════════════════════════════════
struct LazyTbl <: AbstractTbl
    src::Tbl
    steps::Vector{Step}
end
lazy(t::Tbl) = LazyTbl(t, Step[])
(s::Step)(l::LazyTbl) = LazyTbl(l.src, [l.steps; s])
(p::Pipeline)(l::LazyTbl) = LazyTbl(l.src, [l.steps; p.steps])

streamable(s::FilterStep) = rowwise(s.pred)
streamable(s::MutateStep) = all(rowwise ∘ last, s.kw)
streamable(::Union{SelectStep,GroupStep,UngroupStep,HeadStep,UnnestStep}) = true
streamable(::Step) = false

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

morsels(t::Tbl, size) = (Tbl(viewcols(t, r), t.groups) for r in Iterators.partition(1:nrow(t), size))

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

groups_after(src, pre) = foldl((g, s) -> s isa GroupStep ? s.keys : s isa UngroupStep ? Symbol[] :
                                          s isa SelectStep ? filter(in(s.cols), g) :
                                          s isa UnnestStep ? filter(!=(s.col), g) : g, pre; init = src.groups)

function vcat_tbls(chunks)
    names = keys(first(chunks).cols)
    Tbl(NamedTuple{names}(Tuple(reduce(vcat, [ch.cols[n] for ch in chunks]) for n in names)), first(chunks).groups)
end

function split_plan(l::LazyTbl)
    k = something(findfirst(!streamable, l.steps), length(l.steps) + 1)
    pre, rest = l.steps[1:k-1], l.steps[k:end]
    plan = !isempty(rest) && first(rest) isa SummariseStep ? decompose(first(rest)) : nothing
    (; pre, rest, plan, sequential = any(s -> s isa HeadStep, pre))
end

function Base.collect(l::LazyTbl; morsel = 65_536)
    (; pre, rest, plan, sequential) = split_plan(l)
    xf = Composed(Tuple(transducer.(pre)))
    src = morsels(l.src, morsel)
    fold(rf, init, comb) = sequential ? foldxl(rf, xf, src; init = init()) :
                                        foldxt(rf, xf, src; init, combine = comb)
    emptycase() = Pipeline(pre)(take(l.src, 1:0))
    if plan !== nothing
        groups = groups_after(l.src, pre)
        acc = fold(partial_rf(plan, groups), () -> Dict{Any,Vector{Any}}(),
                   (a, b) -> mergewith!((x, y) -> merge_parts(plan, x, y), a, b))
        t = isempty(acc) ? first(rest)(emptycase()) : finish(plan, acc, groups)
        rest = rest[2:end]
    else
        chunks = fold((acc, t) -> push!(acc, t), () -> Tbl[], append!)
        t = isempty(chunks) ? emptycase() : vcat_tbls(chunks)
    end
    foldl((t, s) -> s(t), rest; init = t)
end

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

function explain(l::LazyTbl; morsel = 65_536)
    (; pre, rest, plan, sequential) = split_plan(l)
    n = cld(nrow(l.src), morsel)
    io = IOBuffer()
    println(io, "LazyTbl over Tbl ", nrow(l.src), " × ", length(l.src.cols))
    mode = sequential ? "sequential, stops early" : "parallel on $(Threads.nthreads()) threads"
    println(io, "  stream $n morsel(s), $mode: ", isempty(pre) ? "(scan)" : join(repr.(pre), " ⨟ "))
    if plan !== nothing
        println(io, "  ⇒ ", first(rest), " via monoids [", join([repr(m) for (m, _) in plan.slots], ", "), "]")
        rest = rest[2:end]
    end
    isempty(rest) || println(io, "  then in memory: ", join(repr.(rest), " ⨟ "))
    String(take!(io))
end
Base.show(io::IO, l::LazyTbl) = print(io, explain(l))

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
