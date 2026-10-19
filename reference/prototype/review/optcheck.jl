include(joinpath(@__DIR__, "..", "Tidy.jl"))
using .Tidy, Statistics, Test, Random
Random.seed!(2)
N = 50_000
t = Tbl(g = rand(["x","y","z"], N), a = randn(N), b = rand(1:100, N), ts = collect(1:N))
eq(x, y) = keys(x.cols) == keys(y.cols) && all(n -> isequal(x[n], y[n]) || all(isapprox.(x[n], y[n])), keys(x.cols))
pipes = [
  mutate(ab = c.a .* c.b, junk = c.a .^ 3) ⨟ filter((c.ts .>= 30_000) .& (c.b .> 10)) ⨟ group_by(:g) ⨟
     summarise(n = length(c.a), m = mean(c.ab), s = std(c.a)) ⨟ arrange(desc(c.m)),
  mutate(b = c.b .* 2) ⨟ filter(c.b .> 100) ⨟ select(:g, :b),            # filter must NOT pass mutate redefining b
  group_by(:g) ⨟ mutate(z = c.a .- mean(c.a)) ⨟ filter(c.a .> 0) ⨟ select(:g, :z),   # must NOT pass window mutate
  arrange(:b, desc(:ts)) ⨟ filter(c.g .== "x") ⨟ head(7),
  filter(c.b .> 1000) ⨟ group_by(:g) ⨟ summarise(n = length(c.a)),       # empty result
  select(:a, :b) ⨟ mutate(k = c.a .+ c.b, k2 = c.k .* 2) ⨟ filter(c.k2 .> 50) ⨟ summarise(t = sum(c.k)),
]
for (i, p) in enumerate(pipes)
    @test eq(collect(p(lazy(t)); morsel = 4096), p(t))
end
o = optimize(mutate(ab = c.a .* c.b, junk = c.a .^ 3) ⨟ filter((c.ts .>= 30_000) .& (c.b .> 10)) ⨟ group_by(:g) ⨟ summarise(m = mean(c.ab)) |> p -> p(lazy(t)))
println(o.scan.cols, "  ", o.scan.preds); foreach(println, o.log)
pp = physical(filter(c.ts .>= 45_000)(lazy(t)); morsel = 4096)
println("parts after pruning: ", length(pp.parts), "/", pp.nparts, " (TblSource has no stats, so expect no pruning)")
println("optimizer checks done")
