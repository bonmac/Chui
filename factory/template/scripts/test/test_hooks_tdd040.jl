# Factory 0.3.0 x 0.4.0 interactions (the merge of main into feat/f040). Uses the helpers of
# test_hooks.jl and test_hooks_agents.jl (blocked, bash_as) and test_hooks_tdd.jl (tb_topo, tb_ok,
# tb_no, tb_bash, tb_write, tb_read, tb_pay), so it runs after them (TEST_FILES order; `hooks` selects all).
# Split out because test_hooks_tdd.jl and test_hooks_agents.jl are at the 400-line budget.
@testset "0.3.0 x 0.4.0 interactions" begin
    @testset "a reviewer runs tdd.jl audit (its test-first check), never another tdd.jl subcommand" begin
        r = realpath(mktempdir())
        for c in ("julia scripts/tdd.jl audit --base main --ledger .lanes/ledger.jsonl", "julia --startup-file=no scripts/tdd.jl audit")
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        for c in (
                "julia scripts/tdd.jl red", "julia scripts/tdd.jl green --base main", "julia scripts/tdd.jl brief --role implementer",
                "julia scripts/tdd.jl mutate --item i --src a:1 --from a --to b", "julia scripts/tdd.jl gaps", "julia scripts/tdd.jl api",
                "julia scripts/tdd.jl audit --root /x", "julia scripts/tdd.jl",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
    end

    t = tb_topo()
    L, S = t.lane, t.S
    twb(c; agent = "test-writer") = tb_bash(c; agent, cwd = L)
    @testset "a test-side role runs the _preflight git reads, and no other git read" begin
        for a in ("test-writer", "law-tester"), c in ("pwd", "git rev-parse --show-toplevel", "git -C $L branch --show-current", "git worktree list")
            @test tb_ok(t, twb(c; agent = a))
        end
        for c in (
                "git rev-parse HEAD:src/P.jl", "git rev-parse --show-toplevel HEAD", "git branch -f x", "git branch", "git worktree add x",
                "git worktree list --porcelain", "git branch --show-current x",
            )
            @test tb_no(t, twb(c))
        end
    end
    @testset "a test-side role writes its own report in the session root's .lanes/reports/, and reads none" begin
        for a in ("test-writer", "law-tester", "property-tester", "differential-tester")
            @test tb_ok(t, tb_write("$S/.lanes/reports/tw-lane1-1.md"; agent = a))
        end
        @test tb_ok(t, tb_write("$S/.lanes/reports/tw-lane1-1--r2.md"; tool = "Edit"))
        for p in (
                "$S/.lanes/reports/sub/x.md", "$S/.lanes/reports/x.txt", "$S/.lanes/reports/", "$L/.lanes/reports/x.md",
                "$S/.lanes/scratch/x.md", "$S/.lanes/reports/../ledger.jsonl",
            )
            @test tb_no(t, tb_write(p))
        end
        mkpath("$S/.lanes"); symlink("$(t.pkg)/src", "$S/.lanes/reports")   # a reports link into src/ is not the reports
        @test tb_no(t, tb_write("$S/.lanes/reports/x.md"))
        rm("$S/.lanes/reports")
        @test tb_no(t, tb_read("$S/.lanes/reports/tw-lane1-1.md"))
        @test tb_ok(t, tb_write("$S/.lanes/reports/x.md"; agent = "implementer"))   # unchanged: no test/** only
    end
    @testset "rg --hostname-bin is denied to a test-side role (it runs a program)" begin
        @test tb_ok(t, twb("rg -n f test/t.jl"))
        @test tb_no(t, twb("rg --hostname-bin=/bin/cat f test/t.jl"))
        @test tb_no(t, twb("rg --hostname-bin /bin/cat f test/t.jl"))
    end
    @testset "Monitor runs through tdd_boundary like Bash (0.4.0 D9)" begin
        mon(c; agent = "test-writer") = tb_pay("Monitor", Dict{String, Any}("command" => c, "description" => "d", "timeout_ms" => 1000); agent, cwd = L)
        @test tb_ok(t, mon("tail -f test/t.jl"))
        @test tb_no(t, mon("cat src/P.jl"))
        @test tb_no(t, mon("git log"; agent = "law-tester"))
        @test tb_ok(t, mon("cat src/P.jl"; agent = nothing))   # the lead: commit guard only
    end
    @testset "fix7 m1: a slow git in the TDD dispatch check is killed by the watchdog; both hooks deny in time" begin
        stub = realpath(mktempdir()); write(joinpath(stub, "git"), "#!/bin/sh\nexec sleep 20\n"); chmod(joinpath(stub, "git"), 0o755)
        b = "<!-- tdd-brief role=test-writer lane=lane1 checkout=$L head=$(tb_head(L)) -->\n## Task\nm1\n"
        p = tb_pay("Agent", Dict{String, Any}("subagent_type" => "test-writer", "prompt" => b, "description" => "d"))
        @test tb_ok(t, p)                                     # control: the real git allows this dispatch
        for h in ("dispatch_limit.sh", "tdd_boundary.sh")
            cmd = Cmd(addenv(`sh $(joinpath(TB_HOOKS, h))`, tb_env(t)..., "PATH" => stub * ":" * ENV["PATH"], "FACTORY_WATCHDOG_SECS" => "2"); dir = S)
            err = IOBuffer(); t0 = time()
            rc = run(pipeline(ignorestatus(cmd); stdin = IOBuffer(p), stdout = devnull, stderr = err)).exitcode
            el = time() - t0
            @test rc == 2 && el < 3.0 || (println("m1 $h: rc $rc after $(round(el; digits = 1)) s: ", String(take!(err))); false)
        end
    end
end
