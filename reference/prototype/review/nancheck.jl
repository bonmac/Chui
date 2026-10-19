include(joinpath(@__DIR__, "..", "Tidy.jl")); include(joinpath(@__DIR__, "..", "TidyIO.jl"))
using .Tidy, .TidyIO, Parquet2, Tables, Test
p = joinpath(mktempdir(), "nan.parquet")
Parquet2.writefile(p, Tables.partitioner([(a = [NaN, 5.0], i = [1, 2]), (a = [1.0, 2.0], i = [3, 4])]); compute_statistics = true)
q = scan_parquet(p) |> filter(c.a .> 3.0)
@test collect(q)[:i] == [2]
t = Tbl(i = [1, 2, 3, 4], f = [0.1, 0.2, 0.3, 0.4])
@test_throws Exception collect(lazy(t) |> select(:i) |> filter(c.f .> 0.25))
@test collect(lazy(t) |> select(:i, :f) |> filter(c.f .> 0.25))[:i] == [3, 4]
println("nan + select checks passed")
