# Factory 0.4.0 critic round 3, M2 (f040-fix7): tdd.jl's ledger readers (`ledger_records`, `default_ledger`, used by
# E5 of `tdd.jl audit`) read the ledger, then a crash's leftover `ledger.pending.jsonl.*` files, then the live
# `ledger.pending.jsonl` as its tail, like the hooks' and lane.jl's readers: a `tdd-commit` record that the hooks
# appended to pending while the lock was held is seen, so E5 does not fail spuriously. Included from test_tdd_c4.jl
# (th, th_testset, th_has, th_lane, th_lane_recs, th_ledger!, th_red_ev!, th_green_ev! of test_tdd_history*.jl).
@testset "fix7 M2: tdd.jl audit's E5 reads the pending ledger files too" begin
    th_testset("a tdd-commit record only in pending (or a leftover) is seen by E5", :lane_commits, :evidence_rules, :default_ledger) do
        d, c = th_lane()
        th_red_ev!(d, c.red); th_green_ev!(d, c.green)
        stub, red, green = th_lane_recs(d, c)
        dir = mktempdir()
        led = th_ledger!(joinpath(dir, "ledger.jsonl"), [stub])
        th_ledger!(joinpath(dir, "ledger.pending.jsonl.0000000001.7"), [red])   # a crash's leftover
        th_ledger!(joinpath(dir, "ledger.pending.jsonl"), [green])                # the live pending file
        v = th(:evidence_rules)(d, th(:lane_commits)(d, "main"); ledger = led)
        @test !th_has(v, "E5") || (println("M2: ", filter(s -> startswith(s, "E5"), v)); false)
        # control: without the pending files the two records are missing
        rm(joinpath(dir, "ledger.pending.jsonl")); rm(joinpath(dir, "ledger.pending.jsonl.0000000001.7"))
        @test th_has(th(:evidence_rules)(d, th(:lane_commits)(d, "main"); ledger = led), "E5")
        # default_ledger finds a .lanes/ that holds only a pending file (the ledger itself not yet written)
        root = realpath(mktempdir()); mkpath(joinpath(root, ".lanes")); write(joinpath(root, ".lanes/ledger.pending.jsonl"), green * "\n")
        @test th(:default_ledger)(root) == joinpath(root, ".lanes", "ledger.jsonl")
    end
end
