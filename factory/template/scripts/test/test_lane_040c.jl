# lane.jl and the hooks' ledger, factory 0.4.0 critic round 3 (f040-fix7). M1: every lock holder appends its own line
# through the pending file and then folds it, so the ledger's order is arrival order: a hook's line that timed out into
# pending while lane.jl held the lock (older than lane.jl's) lands before lane.jl's. n1: the watchdog's guard-timeout,
# written during the lock wait, goes to pending and survives a compact. Included from test_lane_040b.jl (ledger_ev,
# open_count, capture, tmp_repo; HOOKS of runtests.jl).
@testset "ledger: lock holders append through pending; a guard-timeout survives a compact (fix7 M1, n1)" begin
    withenv("FACTORY_LANE_TTL_HOURS" => "0") do
        d = tmp_repo(Dict(".gitignore" => "/.lanes/\n")); led = joinpath(d, ".lanes/ledger.jsonl"); pend = joinpath(d, ".lanes/ledger.pending.jsonl")
        mkpath(dirname(led)); write(led, ledger_ev("2026-10-27T10:00:00Z", "dispatch"; key = "a", name = "a", desc = "d") * "\n")
        # a hook's close of `a`, timed out into pending after with_lock's fold and before ledger_line's own append
        late = ledger_ev("2026-10-27T10:00:01Z", "close"; key = "a", why = "returned")
        Lane.BEFORE_LEDGER_APPEND[] = () -> open(io -> println(io, late), pend, "a")
        ok = try
            Lane.ledger_line(d, "dispatch"; session = "s1", key = "b", name = "b", desc = "d")
        finally
            Lane.BEFORE_LEDGER_APPEND[] = () -> nothing
        end
        ls = readlines(led); ic = findfirst(contains("\"close\""), ls); ib = findfirst(contains("\"key\":\"b\""), ls)
        @test ok && ic !== nothing && ib !== nothing && ic < ib || (println(ls); false)
        @test !isfile(pend) && open_count(led, "s1") == 1
        # n1: dispatch_limit's watchdog fires during the lock wait (a live lock): guard-timeout in pending, kept by compact
        lk = joinpath(d, ".lanes/.dispatch.lock"); mkdir(lk)
        p = "{\"session_id\":\"s1\",\"tool_name\":\"Agent\",\"tool_use_id\":\"w\",\"tool_input\":{\"description\":\"w\",\"subagent_type\":\"x\"}}"
        cmd = addenv(`sh $(joinpath(HOOKS, "dispatch_limit.sh"))`, "CLAUDE_PROJECT_DIR" => d, "FACTORY_WATCHDOG_SECS" => "1")
        pr = run(pipeline(ignorestatus(cmd); stdin = IOBuffer(p), stdout = devnull, stderr = devnull))
        @test pr.exitcode == 2
        @test !any(contains("guard-timeout"), readlines(led)) && isfile(pend) && any(contains("guard-timeout"), readlines(pend))
        rm(lk)
        rc, out = capture(() -> Lane.main(["compact", "--repo", d]))
        @test rc == 0 && any(contains("guard-timeout"), readlines(led)) && !isfile(pend) || (print(out); false)
    end
end
