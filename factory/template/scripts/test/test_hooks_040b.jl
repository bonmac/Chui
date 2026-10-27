# Factory 0.4.0 final-review hook tests (f040-fix6): M1 (dispatch_limit and lane_ledger read the pending file the
# hooks append to while the lock is held), M2 (teammate_idle: `<name>.md` or `<name>--r<digits>.md` only), m3 (a
# read-only agent may not run `lane audit --report`), m4 (format_check is silent for a read-only agent) and n1 (the
# lock's `owner` token: dispatch_limit breaks a stale lock that holds one, and removes only its own). Included from
# test_hooks.jl (helpers hook, bash, json, blocked, write_payload, TEST_HOOKS); test_hooks_agents.jl defines bash_as.
@testset "hooks: 0.4.0 final review" begin
    pre(name; s = "s1") = "{\"session_id\":\"$s\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Agent\",\"tool_use_id\":\"tu_$name\",\"tool_input\":{\"name\":\"$name\",\"description\":\"d $name\",\"subagent_type\":\"critic\"}}"
    ev(e; kw...) = "{\"ts\":\"2026-10-27T10:00:00Z\",\"ev\":\"$e\",\"session\":\"s1\"" * join(",\"$k\":\"$v\"" for (k, v) in kw) * "}\n"
    cap(n) = Dict("FACTORY_MAX_OPEN_LANES" => string(n), "FACTORY_LANE_TTL_HOURS" => "0")

    @testset "M1: the pending file counts (dispatch_limit, lane_ledger)" begin
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes"))
        write(joinpath(r, ".lanes/ledger.jsonl"), ev("dispatch"; key = "a", name = "a", desc = "d a"))
        @test hook("dispatch_limit.sh", pre("b"), r; env = cap(1))[1] == 2                         # a is open: cap 1 reached
        write(joinpath(r, ".lanes/ledger.pending.jsonl"), ev("close"; key = "a"))                     # its close waits in pending
        rc, _, err = hook("dispatch_limit.sh", pre("b"), r; env = cap(1))
        @test rc == 0 || (println("pending close not counted: $err"); false)
        @test hook("dispatch_limit.sh", pre("c"), r; env = cap(1))[1] == 2                         # b counts (ledger) once a is closed (pending)
        rm(joinpath(r, ".lanes/ledger.jsonl"))                                                        # a pending file alone is read too
        write(joinpath(r, ".lanes/ledger.pending.jsonl"), ev("dispatch"; key = "p", name = "p", desc = "d p"))
        @test hook("dispatch_limit.sh", pre("q"), r; env = cap(1))[1] == 2
        # lane_ledger: a SubagentStop whose `spawned` record waits in pending is written (it closes that lane)
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes"))
        write(joinpath(r, ".lanes/ledger.pending.jsonl"), ev("spawned"; key = "a", agent_id = "ag1"))
        hook("lane_ledger.sh", "{\"session_id\":\"s1\",\"hook_event_name\":\"SubagentStop\",\"agent_id\":\"ag1\",\"agent_type\":\"x\"}", r)
        @test any(contains("\"ev\":\"stop\""), readlines(joinpath(r, ".lanes/ledger.jsonl")))
    end

    @testset "M2: teammate_idle reads `<name>.md` and `<name>--r<digits>.md` only" begin
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes/reports"))
        idle(name) = "{\"session_id\":\"s1\",\"team_name\":\"t\",\"teammate_name\":\"$name\"}"
        write(joinpath(r, ".lanes/reports/tw-030.md"), "Verdict: MAY MERGE\n")
        @test hook("teammate_idle.sh", idle("tw-030"), r)[1] == 0
        write(joinpath(r, ".lanes/reports/f040-review--r3.md"), "Verdict: FIX FIRST\n")
        @test hook("teammate_idle.sh", idle("f040-review"), r)[1] == 0
        write(joinpath(r, ".lanes/reports/reviewer-2.md"), "Verdict: MAY MERGE\n")                   # another teammate's (auto-named reviewer-2)
        @test hook("teammate_idle.sh", idle("reviewer"), r)[1] == 2 || (println("reviewer claimed reviewer-2.md"); false)
        write(joinpath(r, ".lanes/reports/tw--r2x.md"), "Verdict: MAY MERGE\n")                      # `--r` takes digits only
        @test hook("teammate_idle.sh", idle("tw"), r)[1] == 2
        mkpath(joinpath(r, ".worktrees/w/.lanes/reports")); write(joinpath(r, ".worktrees/w/.lanes/reports/wt--r12.md"), "Status: DONE\n")
        @test hook("teammate_idle.sh", idle("wt"), r)[1] == 0                                         # a lane worktree's report
    end

    @testset "m3: a read-only agent runs `lane audit` but not `--report`" begin
        r = realpath(mktempdir())
        for c in ("scripts/lane audit x --report .lanes/reports/r.md", "scripts/lane audit x --report=.lanes/reports/r.md",
                "julia scripts/lane.jl audit x --report .lanes/reports/r.md", "./scripts/lane audit x --base main --report r.md")
            rc, _, err = hook("bash_guard.sh", bash_as("reviewer", c), r)
            @test rc == 2 && occursin("--report", err) || (println("allowed: $c"); false)
        end
        @test !blocked("bash_guard.sh", bash_as("reviewer", "scripts/lane audit x --base main"), r)
        @test !blocked("bash_guard.sh", bash_as("reviewer", "julia scripts/lane.jl audit x"), r)
        @test !blocked("bash_guard.sh", bash("scripts/lane audit x --report .lanes/reports/r.md"), r)   # the lead runs it
    end

    @testset "m4: format_check is silent for a read-only agent" begin
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes/scratch/critic")); f = joinpath(r, ".lanes/scratch/critic/a.jl"); write(f, "f(x)=x\n")
        stub = realpath(mktempdir()); write(joinpath(stub, "runic"), "#!/bin/sh\necho diff\nexit 1\n"); chmod(joinpath(stub, "runic"), 0o755)
        env = Dict("PATH" => stub * ":" * ENV["PATH"])
        as(t) = "{\"session_id\":\"s1\",\"agent_type\":\"$t\",\"tool_input\":{\"file_path\":\"$(json(f))\"}}"
        rc, _, err = hook("format_check.sh", as("critic"), r; env)
        @test rc == 0 && isempty(err) || (println("read-only agent told to run runic: $err"); false)
        @test hook("format_check.sh", as("implementer"), r; env)[1] == 2 && hook("format_check.sh", as(""), r; env)[1] == 2
    end

    @testset "n1: the lock's owner token" begin
        r = realpath(mktempdir()); lk = joinpath(r, ".lanes/.dispatch.lock"); mkpath(lk)               # a stale lock compact left (owner token)
        write(joinpath(lk, "owner"), "123-456"); run(`touch -t 202601010000 $lk`)
        rc, _, err = hook("dispatch_limit.sh", pre("s"), r; env = cap(5))
        @test rc == 0 || (println("stale lock with an owner token not broken: $err"); false)
        @test !ispath(lk) && !any(startswith(".dispatch.lock"), readdir(joinpath(r, ".lanes")))
        # dispatch_limit's lock carries its token while held (a `jq` shim records it at each jq run) and is removed at exit
        shim = mktempdir(); seen = joinpath(shim, "seen")
        write(joinpath(shim, "jq"), "#!/bin/sh\ncat \"$lk/owner\" >>\"$seen\" 2>/dev/null\nexec $(Sys.which("jq")) \"\$@\"\n"); chmod(joinpath(shim, "jq"), 0o755)
        write(joinpath(r, ".lanes/ledger.jsonl"), ev("dispatch"; key = "a", name = "a", desc = "d a"))
        @test hook("dispatch_limit.sh", pre("t"), r; env = merge(cap(5), Dict("PATH" => shim * ":" * ENV["PATH"])))[1] == 0
        @test isfile(seen) && !isempty(read(seen, String)) && !ispath(lk)
    end
end
