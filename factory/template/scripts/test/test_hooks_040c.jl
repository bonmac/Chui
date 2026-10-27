# Factory 0.4.0 critic round 3 hook tests (f040-fix7). B1 (a) a read-only agent's `lane audit` takes only a lane name,
# --base, --owns and --reported (a file in a trusted checkout): never --repo, which ran git -C in a scratch gitdir whose
# core.fsmonitor ran; (b) a `.git` path component matches case-insensitively (`.GIT`, `.Git`: APFS is case-insensitive,
# git finds them as `.git`), as a directory or a final file, for the lead and for a read-only agent's scratch.
# M1: every lock holder appends through the pending file, so the ledger's order is arrival order; n1: a guard-timeout
# lands in pending, never in the ledger directly. Included from test_hooks.jl (hook, bash, json, blocked, write_payload)
# after test_hooks_agents.jl (bash_as, write_as).
@testset "hooks: 0.4.0 critic round 3 (fix7)" begin
    @testset "B1a: a read-only agent's lane audit takes no --repo and no option but --base, --owns, --reported" begin
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes/scratch/critic/r")); mkpath(joinpath(r, "docs"))
        for c in (
                "scripts/lane audit x --repo .lanes/scratch/critic/r", "scripts/lane audit x --repo=.lanes/scratch/critic/r",
                "julia scripts/lane.jl audit x --repo /tmp/x", "./scripts/lane audit x --base main --repo .", "scripts/lane audit x --keep 3",
                "scripts/lane audit x --allow-ignored", "scripts/lane audit x -h", "scripts/lane audit x y", "scripts/lane audit",
                "scripts/lane audit x --reported /opt/elsewhere/r.md", "scripts/lane audit x --reported \$HOME/r.md", "scripts/lane audit x --base",
            )
            rc, _, err = hook("bash_guard.sh", bash_as("critic", c), r)
            @test rc == 2 || (println("allowed for a critic: $c"); false)
        end
        for c in (
                "scripts/lane audit x", "scripts/lane audit x --base main --owns src", "julia scripts/lane.jl audit x --reported docs/r.md",
                "scripts/lane audit x --reported .lanes/reports/x.md --base origin/main",
            )
            rc, _, err = hook("bash_guard.sh", bash_as("critic", c), r)
            @test rc == 0 || (println("blocked for a critic: $c\n  $err"); false)
        end
        @test !blocked("bash_guard.sh", bash("scripts/lane audit x --repo ChuiCore.jl"), r)   # the lead is unchanged
    end

    @testset "B1b: a .git component matches case-insensitively (a directory, or a final gitfile)" begin
        r = realpath(mktempdir()); s = joinpath(r, ".lanes/scratch/critic/r"); mkpath(s)
        for p in ("$s/.GIT/config", "$s/.Git/HEAD", "$s/.gIt", "$s/.worktrees/x/.Git", "$s/.git/config")
            @test blocked("write_guard.sh", write_as("critic", p), r) || (println("critic wrote $p"); false)
            @test blocked("write_guard.sh", write_as("critic", p), r; env = Dict("FACTORY_ALLOW_T3" => "1")) || (println("critic wrote $p with T3"); false)
        end
        for c in (
                "mkdir -p .lanes/scratch/critic/r/.GIT/refs", "mkdir .lanes/scratch/critic/r/.Git", "cp -R .git/objects .lanes/scratch/critic/r/.Git/objects",
                "cp .git/index .lanes/scratch/critic/r/.GIT/index", "cp a .lanes/scratch/critic/r/w/.GIT", "cp -R .git .lanes/scratch/critic/r",
                "cp -R w/.Git .lanes/scratch/critic/r/w2", "cp x/.GIT .lanes/scratch/critic/r/",
            )
            @test blocked("bash_guard.sh", bash_as("critic", c), r) || (println("allowed for a critic: $c"); false)
        end
        for c in ("mkdir -p .lanes/scratch/critic/r/.GIT/refs", "cp -R .git .lanes/scratch/critic/r/w3")   # the T3 override is the lead's, not a read-only agent's
            @test blocked("bash_guard.sh", bash_as("critic", c), r; env = Dict("FACTORY_ALLOW_T3" => "1")) || (println("allowed for a critic with T3: $c"); false)
        end
        @test !blocked("bash_guard.sh", bash_as("critic", "mkdir -p .lanes/scratch/critic/r/gitx/.github"), r)
        # the lead: Write, mkdir and cp below `.GIT` are blocked too; `.gitignore`, `.github/`, `x.git` are not
        for p in ("$r/x/.GIT/config", "$r/x/.Git", "$r/.GIT/hooks/pre-commit")
            @test blocked("write_guard.sh", write_payload(p), r) || (println("the lead wrote $p"); false)
        end
        for c in ("mkdir -p x/.GIT/refs", "cp a x/.Git/config", "touch .GIT/hooks/post-checkout")
            @test blocked("bash_guard.sh", bash(c), r) || (println("allowed for the lead: $c"); false)
        end
        for p in ("$r/.gitignore", "$r/x/.github/workflows/ci.yml", "$r/x/r.git/a", "$r/.gitattributes")
            @test !blocked("write_guard.sh", write_payload(p), r) || (println("the lead blocked on $p"); false)
        end
    end

    led(r) = joinpath(r, ".lanes/ledger.jsonl")
    pend(r) = joinpath(r, ".lanes/ledger.pending.jsonl")
    @testset "M1: dispatch_limit's own append goes through pending, so an older close lands before it" begin
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes")); lk = joinpath(r, ".lanes/.dispatch.lock")
        write(led(r), "{\"ts\":\"2026-10-27T15:00:00Z\",\"ev\":\"dispatch\",\"session\":\"s1\",\"key\":\"tu:1\",\"name\":\"-\",\"desc\":\"review\",\"subagent_type\":\"reviewer\"}\n")
        d2 = "{\"session_id\":\"s1\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Agent\",\"tool_use_id\":\"2\",\"tool_input\":{\"description\":\"review\",\"subagent_type\":\"reviewer\",\"prompt\":\"p\"}}"
        ts = "{\"session_id\":\"s1\",\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"TaskStop\",\"tool_input\":{\"task_id\":\"T9\"},\"tool_response\":{\"command\":\"review\"}}"
        env = Dict("FACTORY_TEST" => "1", "FACTORY_SLOW_JQ" => "3", "FACTORY_WATCHDOG_SECS" => "9")
        t = @async hook("dispatch_limit.sh", d2, r; env)
        t0 = time(); while !isdir(lk) && time() - t0 < 10
            sleep(0.02)
        end
        @test isdir(lk)
        hook("lane_ledger.sh", ts, r)                       # TaskStop of tu:1 while the lock is held: its close times out into pending
        @test fetch(t)[1] == 0
        hook("lane_ledger.sh", "{\"session_id\":\"s1\",\"hook_event_name\":\"SubagentStart\",\"agent_id\":\"z\",\"agent_type\":\"x\"}", r)
        ls = readlines(led(r)); ic = findfirst(contains("\"close\""), ls); i2 = findfirst(contains("\"tu:2\""), ls)
        @test ic !== nothing && i2 !== nothing && ic < i2 || (println(ls); false)
        rc, _, err = hook(
            "dispatch_limit.sh", "{\"session_id\":\"s1\",\"tool_name\":\"Agent\",\"tool_use_id\":\"3\",\"tool_input\":{\"description\":\"x\",\"subagent_type\":\"reviewer\"}}", r;
            env = Dict("FACTORY_MAX_OPEN_LANES" => "1")
        )
        @test rc == 2 && occursin("tu:2", err) || (println("tu:2 not open (open: 0, expected 1): $err"); false)
    end

    @testset "n1: a guard-timeout during the lock wait goes to pending, never to the ledger" begin
        r = realpath(mktempdir()); lk = joinpath(r, ".lanes/.dispatch.lock"); mkpath(lk)          # a live lock (not stale)
        write(led(r), "{\"ts\":\"2026-10-27T15:00:00Z\",\"ev\":\"dispatch\",\"session\":\"s1\",\"key\":\"a\",\"name\":\"a\",\"desc\":\"d\"}\n")
        rc, _, err = hook(
            "dispatch_limit.sh", "{\"session_id\":\"s1\",\"tool_name\":\"Agent\",\"tool_use_id\":\"w\",\"tool_input\":{\"description\":\"w\",\"subagent_type\":\"x\"}}", r;
            env = Dict("FACTORY_WATCHDOG_SECS" => "1")
        )
        @test rc == 2 && occursin("exceeded", err)
        @test !any(contains("guard-timeout"), readlines(led(r))) || (println("guard-timeout written to the ledger without the lock"); false)
        @test isfile(pend(r)) && any(contains("guard-timeout"), readlines(pend(r)))
        @test isdir(lk)                                     # the lock it never took stays
    end
end

# moved from test_hooks_agents.jl (its 400-line budget once Runic-formatted)
@testset "runtests.jl: NAME... selects test files; --hooks-dir DIR overrides HOOKS (0.4.0)" begin
    @test runtests_args(String[]) == (String[], "")
    @test runtests_args(["hooks", "gen"]) == (["hooks", "gen"], "")
    @test runtests_args(["hooks", "--hooks-dir", "x/hooks"]) == (["hooks"], abspath("x/hooks"))
    @test runtests_args(["--hooks-dir=x/hooks"]) == (String[], abspath("x/hooks"))
    @test_throws ErrorException runtests_args(["--hooks-dir"])
    @test_throws ErrorException runtests_args(["--root", "x"])
    @test selected_files(["hooks"]) == ["test_hooks.jl", "test_hooks_lifecycle.jl", "test_hooks_tdd.jl", "test_hooks_tdd040.jl"]
    @test selected_files(["gen", "lane"]) == ["test_gen.jl", "test_lane.jl", "test_lane_040.jl", "test_lane_040b.jl"]
    @test selected_files(String[]) == TEST_FILES
    @test_throws ErrorException selected_files(["nosuch"])
end
