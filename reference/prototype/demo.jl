include(joinpath(@__DIR__, "Tidy.jl"))
using .Tidy, Statistics, Random

df = Tbl(
    species = ["a", "a", "b", "b", "b", "c"],
    mass    = [3.1, 2.9, 5.0, 5.4, 4.8, 7.2],
    len     = [10, 11, 15, 16, 14, 20],
)

# 1. Verbs are values; ⨟ composes them into a reusable, printable pipeline
by_species = group_by(:species) ⨟
             summarise(n = length(c.species), mean_ratio = mean(c.mass ./ c.len), max_len = maximum(c.len)) ⨟
             arrange(desc(c.mean_ratio))
println(by_species)
df |> filter(c.mass .> 3) |> by_species |> display

# 2. Scans: running totals per group
df |> group_by(:species) |> mutate(run_mass = cumsum(c.mass), run_max = accumulate(max, c.len)) |> display

# 3. purrr list-columns: nest, map a function over each sub-table, unnest
slope(d) = cov(d[:len], d[:mass]) / var(d[:len])
nested = df |> nest(:species) |> mutate(n = nrow.(c.data), slope = map(d -> nrow(d) > 1 ? slope(d) : NaN, c.data))
display(nested)
nested |> unnest(:data) |> display

# 4. Transducers on any iterable, including table rows
xf = Filter(r -> r.mass > 3) ⨟ Map(r -> r.len) ⨟ Take(3)
println("first 3 lens with mass > 3, summed: ", foldxl(+, xf, rows(df); init = 0))
println("sum of squares of evens: ", foldxt(+, Filter(iseven) ⨟ Map(abs2), 1:1_000_000; init = () -> 0))
println("MapCat: ", foldxl(push!, MapCat(n -> 1:n), 1:3; init = Int[]))

# 5. Lazy plans: fused streaming over morsels, monoid aggregation, early stop
Random.seed!(1)
N = 2_000_000
big = Tbl(g = rand(["x", "y", "z"], N), a = randn(N), b = rand(1:100, N))

q = lazy(big) |>
    filter(c.b .> 10) |>
    mutate(ab = c.a .* c.b) |>
    group_by(:g) |>
    summarise(n = length(c.a), mean_ab = mean(c.ab), sd_a = std(c.a), hi = maximum(c.b),
              rng = maximum(c.a) .- minimum(c.a), sq = mapreduce(abs2, +, c.a)) |>
    arrange(:g)
print(q)

eager_steps = filter(c.b .> 10) ⨟ mutate(ab = c.a .* c.b) ⨟ group_by(:g) ⨟
              summarise(n = length(c.a), mean_ab = mean(c.ab), sd_a = std(c.a), hi = maximum(c.b),
                        rng = maximum(c.a) .- minimum(c.a), sq = mapreduce(abs2, +, c.a)) ⨟ arrange(:g)
collect(q); eager_steps(big)                       # warm up (compilation)
tl = @elapsed lr = collect(q)
te = @elapsed er = eager_steps(big)
display(lr)
same = all(n -> all(isapprox.(lr[n], er[n])), (:n, :mean_ab, :sd_a, :hi, :rng, :sq)) && lr[:g] == er[:g]
println("lazy == eager: ", same, "   lazy ", round(tl, digits = 3), "s vs eager ", round(te, digits = 3), "s")

# Head stops reading morsels once it has enough rows
h = lazy(big) |> filter(c.a .> 2) |> head(5)
print(h)
display(collect(h))

# Non-monoid aggregate (median) falls back to materialize-then-summarise
print(lazy(big) |> group_by(:g) |> summarise(med = median(c.a)))
display(collect(lazy(big) |> group_by(:g) |> summarise(med = median(c.a))))
