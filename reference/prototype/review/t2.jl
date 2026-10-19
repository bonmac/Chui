include(joinpath(@__DIR__, "..", "Tidy.jl"))
using .Tidy, Statistics
T(f) = try f() catch e; "ERR: " * sprint(showerror, e)[1:min(150,end)] end
struct Foo end; Base.broadcastable(x::Foo) = x
println("unknown style: ", T(()-> c.x .+ Foo()))
t = Tbl(g=[1,1,2,missing,2], x=[1.0,2,3,4,5])
f(l, ms) = collect(l; morsel=ms)
q = group_by(:g) ⨟ summarise(k=1, n=length(c.x), s=sum(c.x) ./ length(c.x), a=any(c.x .> 4))
println(q(t).cols); println(f(q(lazy(t)),2).cols)
# head after filter
q2 = filter(c.x .> 1) ⨟ head(2)
println(q2(t).cols.x, f(q2(lazy(t)),1).cols.x)
# nest/unnest + summarise
nt = nest(Tbl(g=[1,1,2], x=[1,2,3]), :g)
q3 = group_by(:g) ⨟ unnest(:data) ⨟ summarise(n=length(c.x))
println(q3(nt).cols, " ", f(q3(lazy(nt)),1).cols)
# empty grouped unnest
q4 = filter(c.g .> 5) ⨟ group_by(:g) ⨟ unnest(:data) ⨟ summarise(n=length(c.g))
println(T(()->q4(nt).cols), " ", T(()->f(q4(lazy(nt)),1).cols))
# select drops group, then summarise
q5 = group_by(:g) ⨟ select(:x) ⨟ summarise(n=length(c.x))
println(q5(t).cols, f(q5(lazy(t)),2).cols)
# type divergence mutate across morsels
t6 = Tbl(x=[1,2,-1,-2])
q6 = mutate(y = ifelse.(c.x .> 0, 1, 2.5))
println(eltype(q6(t6)[:y]), " ", q6(t6)[:y], " lazy ", eltype(f(q6(lazy(t6)),2)[:y]), f(q6(lazy(t6)),2)[:y])
# summarise reduce with Vector Lit row arg in grouped
println(T(()->collect(lazy(Tbl(x=[1,2,3])) |> select(:x); morsel=10)[:x] |> typeof))
# Take(0), MapCat Reduced
println(foldxl(push!, MapCat(n->1:n) ⨟ Take(4), 1:5; init=Int[]), foldxl(push!, Take(2) ⨟ MapCat(n->1:n), 1:5; init=Int[]))
println(foldxl(+, Take(0), 1:5; init=0))
