using Arrow, Parquet2, Tables, Random
Random.seed!(1)
const D = @__DIR__
N = 200_000
tbl = (g = rand(["x","y","z"], N), a = randn(N), b = rand(1:100, N), ts = collect(1:N))
chunk(t, r) = map(c -> c[r], t)
ranges = [((i-1)*25_000+1):(i*25_000) for i in 1:8]
chunks = [chunk(tbl, r) for r in ranges]

println("== WRITE")
Arrow.write(joinpath(D,"data.arrow"), Tables.partitioner(chunks))
Parquet2.writefile(joinpath(D,"data.parquet"), Tables.partitioner(chunks); compute_statistics=true)

println("== ARROW Table")
at = Arrow.Table(joinpath(D,"data.arrow"))
for n in Tables.columnnames(at); c = Tables.getcolumn(at, n); println(n, " => ", typeof(c), " eltype=", eltype(c)); end
println("schema: ", Tables.schema(at))
println("== ARROW Stream")
for (i, b) in enumerate(Arrow.Stream(joinpath(D,"data.arrow")))
    println("batch $i nrows=", length(b.ts), " typeof(b)=", typeof(b), " ts typeof=", typeof(b.ts), " first/last ts=", first(b.ts), "/", last(b.ts))
end
s1 = first(Arrow.Stream(joinpath(D,"data.arrow")))
println("stream schema: ", Tables.schema(s1))

println("== PARQUET")
ds = Parquet2.Dataset(joinpath(D,"data.parquet"))
println("nrowgroups=", length(ds), " rows/rg=", [Parquet2.nrow(rg) for rg in ds])
k = 3
rg = ds[k]
a3 = Parquet2.load(rg, "a"); ts3 = Parquet2.load(rg, "ts"); g3 = Parquet2.load(rg, "g")
println("load a: ", typeof(a3)); println("load ts: ", typeof(ts3)); println("load g: ", typeof(g3), " eltype=", eltype(g3))
println("collect g: ", typeof(collect(g3)), "  Vector{String}(g): ", typeof(Vector{String}(g3)))
println("Tables.getcolumn(rg,:ts): ", typeof(Tables.getcolumn(rg, :ts)))
println("whole-ds load ts: ", typeof(Parquet2.load(ds, "ts")))
println("ds schema: ", Tables.schema(ds))
println("rg schema: ", Tables.schema(rg))
for (i, r) in enumerate(ds)
    st = Parquet2.ColumnStatistics(r["ts"])
    println("rg $i ts min=", minimum(st), " max=", maximum(st), " n_null=", count(ismissing, st))
end
stg = Parquet2.ColumnStatistics(ds[1]["g"]); println("g stats rg1: ", minimum(stg), " / ", maximum(stg))

println("== CONCURRENCY parquet")
ks = [1, 3, 5, 8]
nbad = 0
seq = [(Vector(Parquet2.load(ds[k], "a")), Vector(Parquet2.load(ds[k], "ts")), Vector{String}(Parquet2.load(ds[k], "g"))) for k in ks]
for trial in 1:20
    tasks = [Threads.@spawn (Vector(Parquet2.load(ds[k], "a")), Vector(Parquet2.load(ds[k], "ts")), Vector{String}(Parquet2.load(ds[k], "g"))) for k in ks]
    par = fetch.(tasks)
    par == seq || (global nbad += 1)
end
println("parquet mismatches over 20 trials: ", nbad)
println("== CONCURRENCY arrow")
abad = 0
cols = [:a, :ts, :g, :b]
aseq = [collect(Tables.getcolumn(at, c)) for c in cols]
batches = collect(Arrow.Stream(joinpath(D,"data.arrow")))
bseq = [(collect(b.a), collect(b.g)) for b in batches[ks]]
for trial in 1:20
    p1 = fetch.([Threads.@spawn collect(Tables.getcolumn(at, c)) for c in cols])
    p2 = fetch.([Threads.@spawn (collect(b.a), collect(b.g)) for b in batches[ks]])
    (p1 == aseq && p2 == bseq) || (global abad += 1)
end
println("arrow mismatches over 20 trials: ", abad, " nthreads=", Threads.nthreads())
