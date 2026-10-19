# julia --project=io/env -t 4 io_demo.jl
include(joinpath(@__DIR__, "Tidy.jl"))
include(joinpath(@__DIR__, "TidyIO.jl"))
using .Tidy, .TidyIO, Statistics, Random, Arrow, Parquet2, Tables

# ── test data: 2M rows, ts sorted, 16 row groups / record batches ──
Random.seed!(7)
N = 2_000_000
cols = (ts = collect(1:N), g = rand(["x", "y", "z"], N), a = randn(N), b = rand(1:100, N),
        d = rand(N), note = rand(["ok", "late", "retry"], N))
chunks = [map(v -> v[r], cols) for r in Iterators.partition(1:N, N ÷ 16)]
pq, arw = joinpath(@__DIR__, "io", "events.parquet"), joinpath(@__DIR__, "io", "events.arrow")
isfile(pq) || Parquet2.writefile(pq, Tables.partitioner(chunks); compute_statistics = true)
isfile(arw) || Arrow.write(arw, Tables.partitioner(chunks))
mem = Tbl(cols)

# ── 1. A complex lazy scan over Parquet ──
query = mutate(ab = c.a .* c.b, cube = c.a .^ 3, late = c.note .== "late") ⨟
        filter((c.ts .>= 1_400_000) .& (c.b .> 10) .& in.(c.g, Ref(["x", "y"]))) ⨟
        group_by(:g) ⨟
        summarise(n = length(c.a), late_share = mean(c.late), mean_ab = mean(c.ab),
                  cv = std(c.a) ./ abs.(mean(c.a)), b_range = maximum(c.b) .- minimum(c.b)) ⨟
        arrange(desc(c.mean_ab))

q = query(scan_parquet(pq))
explain(q)                                   # parsed → optimized → physical → lowered

collect(q); query(mem)                       # warm up compilation
tq = @elapsed rq = collect(q)
te = @elapsed re = query(mem)
println()
display(rq)
same = rq[:g] == re[:g] && all(n -> all(isapprox.(rq[n], re[n])), (:n, :late_share, :mean_ab, :cv, :b_range))
println("parquet lazy == in-memory eager: ", same, "   lazy from parquet ", round(tq, digits = 3),
        "s, eager in memory ", round(te, digits = 3), "s")

# ── 2. Arrow: mmapped scan with an early-stopping limit ──
h = scan_arrow(arw) |> filter(c.a .> 3.5) |> select(:ts, :g, :a) |> head(5)
println()
explain(h; mode = :physical)
display(collect(h))
println("arrow head == eager head: ", collect(h)[:ts] == head(select(filter(mem, c.a .> 3.5), :ts, :g, :a), 5)[:ts])

# ── 3. Just the lowered kernel, like @code_lowered ──
println()
display(code_lowered(scan_arrow(arw) |> mutate(z = (c.a .- 1) .* 2) |> filter(c.z .> 0) |>
                     summarise(total = sum(c.z), hi = maximum(c.b))))
