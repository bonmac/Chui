# Seeded by the ecosystem factory. Test items (TestItemRunner, ADR-0007) are selected by tag:
#   julia scripts/ci.jl test                 -> everything except the tags in EXCLUDE
#   julia scripts/ci.jl test -- laws unit    -> only items tagged :laws or :unit
#   julia scripts/ci.jl test -- all          -> every item except :contract
# :contract items run in their own environment (test/contracts/), via `julia scripts/ci.jl contracts`.
#
# Supposition properties and laws (ADR-0007 §2, amended 2026-10-20) take this form, on every Julia version:
#   @testitem "addition commutes" tags = [:property] begin
#       using Supposition
#       ints = Data.Integers{Int8}()
#       sr = @check record = false db = false (a = ints, b = ints) -> a + b == b + a
#       @test Supposition.results(sr).ispass      # `results` is not exported
#   end
# - record=false + an explicit @test: on Julia 1.10 a failing `@check` that records itself in the enclosing
#   testset is silently dropped (summary "None", exit 0); 1.13 reports it. The explicit @test fails on both.
# - db=false: Supposition's counterexample DB (test/SuppositionDB/, gitignored) written by 1.13 crashes 1.10
#   ("Cannot read stream serialized with a newer version"). Keep a counterexample as a plain unit test.
# A manifest resolved on 1.13 may not load on 1.10 (PrecompileTools 1.3.x needs Julia >= 1.12): give the LTS
# its own gitignored Manifest-v1.10.toml, which Julia 1.10 reads in preference to Manifest.toml.
using TestItemRunner

# :doctest and :snapshot output depends on the Julia version: CI runs them on stable only
# (CI.yml sets CI_STABLE=false on the lts and pre jobs). JET is not here: see test/jet/.
const EXCLUDE = get(ENV, "CI_STABLE", "true") == "false" ?
    (:slow, :quality, :contract, :differential, :doctest, :snapshot) :
    (:slow, :quality, :contract, :differential)
const SELECT = Symbol.(ARGS)
:contract in SELECT && @info "contract items run in test/contracts/'s own environment: julia scripts/ci.jl contracts"

@run_package_tests filter = ti -> begin
    :contract in ti.tags && return false
    :all in SELECT && return true
    isempty(SELECT) && return !any(in(EXCLUDE), ti.tags)
    return any(in(SELECT), ti.tags)
end
