include(joinpath(@__DIR__, "..", "Tidy.jl"))
using .Tidy, Statistics, Test
T(f) = try f() catch e; "ERR: " * sprint(showerror, e)[1:min(120,end)] end
# 1 mean Int overflow
t = Tbl(x = [typemax(Int), typemax(Int)])
println("mean eager ", T(()->summarise(t; m = mean(c.x))[:m]), " lazy ", T(()->collect(lazy(t) |> summarise(m = mean(c.x)))[:m]))
# 2 foldxt + Take
println("foldxl Take ", foldxl(+, Take(3), 1:100; init=0), " foldxt Take ", foldxt(+, Take(3), 1:100; init=()->0))
# 3 desc(:sym)
t2 = Tbl(x=[1,3,2])
println("arrange desc(:x) ", arrange(t2, desc(:x))[:x], " desc(c.x) ", arrange(t2, desc(c.x))[:x])
# 4 count on Int column
t3 = Tbl(x=[1,2,3])
println("count eager ", T(()->summarise(t3; n=count(c.x))[:n]), " lazy ", T(()->collect(lazy(t3)|>summarise(n=count(c.x)))[:n]))
t4 = Tbl(x=[true, missing, true])
println("count missing eager ", T(()->summarise(t4; n=count(c.x))[:n]), " lazy ", T(()->collect(lazy(t4)|>summarise(n=count(c.x)))[:n]))
# 5 first/last across morsels
t5 = Tbl(g=repeat([1,2], 50), x=collect(1:100))
for ms in (1,3,7)
  l = collect(lazy(t5) |> group_by(:g) |> summarise(f=first(c.x), l=last(c.x), s=std(c.x), v=var(c.x)); morsel=ms)
  e = t5 |> group_by(:g) |> summarise(f=first(c.x), l=last(c.x), s=std(c.x), v=var(c.x))
  println("ms=$ms first/last ", l[:f]==e[:f], l[:l]==e[:l], isapprox(l[:s],e[:s]), isapprox(l[:v], e[:v]))
end
# 6 literal pow
println("pow ", T(()->mutate(t3; y = c.x .^ 2)[:y]), " lazy ", T(()->collect(lazy(t3) |> mutate(y = c.x .^ 2))[:y]))
# 7 ambiguities
println("ambig: ", length(Test.detect_ambiguities(Tidy)))
for a in Test.detect_ambiguities(Tidy); println(a); end
