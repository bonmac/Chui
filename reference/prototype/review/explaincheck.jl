include(joinpath(@__DIR__, "..", "Tidy.jl"))
using .Tidy, Statistics, Random
Random.seed!(2); N = 50_000
t = Tbl(g = rand(["x","y","z"], N), a = randn(N), b = rand(1:100, N), ts = collect(1:N))
q = lazy(t) |> mutate(ab = c.a .* c.b, junk = c.a .^ 3) |> filter((c.ts .>= 30_000) .& (c.b .> 10)) |>
    group_by(:g) |> summarise(n = length(c.a), mean_ab = mean(c.ab), cv = std(c.a) ./ abs.(mean(c.a))) |> arrange(desc(c.mean_ab))
explain(q; morsel = 8192)
println("\n---- show ----"); show(stdout, q; ); println()
println("---- code_lowered head ----"); display(code_lowered(lazy(t) |> filter(c.a .> 2) |> select(:g, :a) |> head(5)))
