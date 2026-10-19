include(joinpath(@__DIR__, "..", "Tidy.jl"))
using .Tidy, Statistics, Test
t = Tbl(x = [typemax(Int), typemax(Int)])
@test summarise(t; m = mean(c.x))[:m] == collect(lazy(t) |> summarise(m = mean(c.x)))[:m]
@test foldxt(+, Take(3), 1:100; init = () -> 0) == 6
@test arrange(Tbl(x = [1, 3, 2]), desc(:x))[:x] == [3, 2, 1]
@test collect(lazy(Tbl(x = [1, 3, 2])) |> arrange(desc(:x)))[:x] == [3, 2, 1]
@test_throws Exception collect(lazy(Tbl(x = [1, 2, 3])) |> summarise(n = count(c.x)))
b = Tbl(x = [true, false, true, true])
@test collect(lazy(b) |> summarise(n = count(c.x)); morsel = 1)[:n] == summarise(b; n = count(c.x))[:n] == [3]
@test collect(lazy(b) |> summarise(n = count(!, c.x)); morsel = 1)[:n] == [1]
@test isempty(Test.detect_ambiguities(Tidy))
println("all fix checks passed")
