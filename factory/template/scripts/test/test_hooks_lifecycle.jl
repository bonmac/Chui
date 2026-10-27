# Lane-lifecycle hooks (teammate_idle, lane_ledger, dispatch_limit, precompact, session_start) and
# the settings.json wiring. Split from test_hooks.jl in 0.2.5 to keep both under the 400-line
# `scripts/*.jl` budget once Runic-formatted; uses its helpers (hook, TEST_HOOKS, bash, ...).
@testset "hooks: lifecycle and settings.json" begin
    root = realpath(mktempdir())

    @testset "teammate_idle: first unreported idle blocked, report demanded" begin
        idle(name) = "{\"session_id\":\"s1\",\"team_name\":\"t\",\"teammate_name\":\"$name\"}"
        rc, _, err = hook("teammate_idle.sh", idle("alpha"), root)
        @test rc == 2 && occursin("report", err) && occursin("FAILED", err)
        @test hook("teammate_idle.sh", idle("alpha"), root)[1] == 0          # second idle: no loop
        @test occursin("idle-unreported", read(joinpath(root, ".lanes/ledger.jsonl"), String))
        @test hook("teammate_idle.sh", idle("beta"), root)[1] == 2
        mkpath(joinpath(root, ".lanes/reports"))
        write(joinpath(root, ".lanes/reports/gamma.md"), "Verdict: MAY MERGE\nreport\n")
        @test hook("teammate_idle.sh", idle("gamma"), root)[1] == 0          # report on disk
        @test hook("teammate_idle.sh", "{}", root)[1] == 0
        # 0.4.0 (critic): a report counts only with a verdict first line (D5), by name `<name>.md` or
        # `<name>--r<digits>.md` (final review M2); anything else is partial and the idle is blocked once, as with no report
        write(joinpath(root, ".lanes/reports/partial.md"), "Findings so far\n- one\n")
        rc, _, err = hook("teammate_idle.sh", idle("partial"), root)
        @test rc == 2 && occursin("partial", err) && occursin("Verdict:", err) || (println("partial: $rc $err"); false)
        @test hook("teammate_idle.sh", idle("partial"), root)[1] == 0         # second idle: no loop
        write(joinpath(root, ".lanes/reports/wrongcase.md"), "verdict: may merge\n")
        @test hook("teammate_idle.sh", idle("wrongcase"), root)[1] == 2
        write(joinpath(root, ".lanes/reports/other-verdict.md"), "Verdict: APPROVE\n")
        @test hook("teammate_idle.sh", idle("other"), root)[1] == 2
        for (n, v) in (("fixes", "MERGE WITH FIXES"), ("fixfirst", "FIX FIRST"))
            write(joinpath(root, ".lanes/reports/$n--r2.md"), "Verdict: $v\n\n- x\n")   # <name>--r<round>.md
            @test hook("teammate_idle.sh", idle(n), root)[1] == 0 || (println("$n--r2.md not counted"); false)
        end
        # (review round 1 m3) `<name>--r<digits>.md` only: `f040-hooks.md` is the f040-hooks lane's, not f040's
        write(joinpath(root, ".lanes/reports/f040-hooks.md"), "Verdict: MAY MERGE\n")
        @test hook("teammate_idle.sh", idle("f040"), root)[1] == 2 || (println("f040 claimed f040-hooks.md"); false)
        write(joinpath(root, ".lanes/reports/rev-1a.md"), "Verdict: MAY MERGE\n")
        @test hook("teammate_idle.sh", idle("rev"), root)[1] == 2 || (println("rev claimed rev-1a.md"); false)
        write(joinpath(root, ".lanes/reports/reviewer--r2.md"), "Verdict: MAY MERGE\n")
        @test hook("teammate_idle.sh", idle("reviewer"), root)[1] == 0 || (println("reviewer--r2.md not counted"); false)
        @test occursin("\"idle-reported\"", read(joinpath(root, ".lanes/ledger.jsonl"), String))
        # 0.2.6 (factory-026 item 5): a lane's session (root = its worktree) writes the report there; it counts
        for wt in (".worktrees/delta", ".claude/worktrees/epsilon")
            n = basename(wt)
            @test hook("teammate_idle.sh", idle(n), root)[1] == 2
            mkpath(joinpath(root, wt, ".lanes/reports")); write(joinpath(root, wt, ".lanes/reports/$n.md"), "Verdict: MAY MERGE\nreport\n")
            @test hook("teammate_idle.sh", idle(n * "x"), root)[1] == 2      # another teammate's report does not count
            rc, _, _ = hook("teammate_idle.sh", replace(idle(n), "s1" => "s9"), root)
            @test rc == 0 || (println("teammate_idle ignored $wt/.lanes/reports/$n.md"); false)
        end
        # write_guard letting a lane's session write <main>/.lanes/reports/ is tested in test_bash_guard.jl (outside /tmp)
    end

    # 0.2.8: a lane is an Agent dispatch (PreToolUse), closed by its PostToolUse result, a TaskStop or a
    # background agent's SubagentStop. 0.2.7 counted SubagentStart - SubagentStop, which in-process
    # teammates never balance: the coordinator ledger had 0 starts and 77 stops in one lead session.
    @testset "dispatch_limit counts dispatches (0.2.8)" begin
        cap(n) = Dict("FACTORY_MAX_OPEN_LANES" => string(n))
        ti(name, desc) = "\"tool_input\":{" * (name == "" ? "" : "\"name\":\"$name\",") * "\"description\":\"$desc\",\"subagent_type\":\"critic\"}"
        pre(name; s = "s2", desc = "d $name", tu = "tu_$name") = "{\"session_id\":\"$s\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Agent\",\"tool_use_id\":\"$tu\",$(ti(name, desc))}"
        post(name, resp; s = "s2", desc = "d $name", tu = "tu_$name", ev = "PostToolUse") = "{\"session_id\":\"$s\",\"hook_event_name\":\"$ev\",\"tool_name\":\"Agent\",\"tool_use_id\":\"$tu\",$(ti(name, desc)),\"tool_response\":$resp}"
        team(name) = "{\"status\":\"teammate_spawned\",\"agent_id\":\"$name@session-s2\",\"name\":\"$name\"}"
        bg(id) = "{\"status\":\"async_launched\",\"agentId\":\"$id\",\"isAsync\":true}"
        stopcall(task; cmd = "", s = "s2", ev = "PostToolUse") = "{\"session_id\":\"$s\",\"hook_event_name\":\"$ev\",\"tool_name\":\"TaskStop\",\"tool_input\":{\"task_id\":\"$task\"},\"tool_response\":{\"task_id\":\"tq1\",\"task_type\":\"in_process_teammate\",\"command\":\"$cmd\"}}"
        substop(id; s = "s2") = "{\"session_id\":\"$s\",\"hook_event_name\":\"SubagentStop\",\"agent_id\":\"$id\",\"agent_type\":\"\"}"
        allow(p, r, n) = hook("dispatch_limit.sh", p, r; env = cap(n))[1] == 0
        denied(p, r, n) = hook("dispatch_limit.sh", p, r; env = cap(n))[1] == 2
        led(r) = joinpath(r, ".lanes/ledger.jsonl")

        # the 2026-10-26 regression: stops with no starts (teammate turns) must not hide named dispatches
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes"))
        write(led(r), join(("{\"ts\":\"2026-10-26T03:4$i:00Z\",\"ev\":\"stop\",\"session\":\"s2\",\"agent_id\":\"ac$i\",\"agent_type\":\"-\"}" for i in 0:9), "\n") * "\n")
        for n in ("t1", "t2")
            @test allow(pre(n), r, 2)
            hook("lane_ledger.sh", post(n, team(n)), r)
        end
        rc, _, err = hook("dispatch_limit.sh", pre("t3"), r; env = cap(2))
        @test rc == 2 && occursin("cap 2", err) && occursin("t1", err) && occursin("t2", err)
        @test any(l -> occursin("\"dispatch-denied\"", l), readlines(led(r)))
        hook("lane_ledger.sh", substop("ac99"), r)                 # a teammate turn's stop closes nothing
        @test denied(pre("t3"), r, 2)
        hook("lane_ledger.sh", stopcall("t1"; cmd = "d t1"), r)    # TaskStop by name
        @test allow(pre("t3"), r, 2)
        @test denied(pre("t4"), r, 2)
        @test all(l -> success(pipeline(`jq -e .ts`; stdin = IOBuffer(l), stdout = devnull)), readlines(led(r)))

        # TaskStop by the internal task id closes by the dispatch description; a failed TaskStop closes too
        r = realpath(mktempdir())
        for n in ("u1", "u2")
            @test allow(pre(n; desc = "Critic: spec $n"), r, 5)
            hook("lane_ledger.sh", post(n, team(n); desc = "Critic: spec $n"), r)
        end
        hook("lane_ledger.sh", stopcall("tyfqc3reh"; cmd = "Critic: spec u1"), r)
        hook("lane_ledger.sh", stopcall("u2"; ev = "PostToolUseFailure"), r)
        @test allow(pre("u3"), r, 1)

        # background subagent: open after async_launched, closed by its own SubagentStop only
        r = realpath(mktempdir())
        @test allow(pre(""; tu = "tuA"), r, 1)
        hook("lane_ledger.sh", post("", bg("a1fe55"); tu = "tuA"), r)
        hook("lane_ledger.sh", substop("a0ther"), r)
        @test denied(pre("v1"), r, 1)
        hook("lane_ledger.sh", substop("a1fe55"), r)
        @test allow(pre("v1"), r, 1)

        # foreground call: its PostToolUse result closes it; a failed dispatch closes it
        r = realpath(mktempdir())
        @test allow(pre("w1"), r, 1)
        @test denied(pre("w2"), r, 1)                              # in flight counts
        hook("lane_ledger.sh", post("w1", "{\"status\":\"completed\",\"content\":[]}"), r)
        @test allow(pre("w2"), r, 1)
        hook("lane_ledger.sh", post("w2", "\"error\""; ev = "PostToolUseFailure"), r)
        @test allow(pre("w3"), r, 1)

        # re-dispatching an open name counts once; another session's lanes do not count
        r = realpath(mktempdir())
        @test allow(pre("x1"), r, 2)
        @test allow(pre("x1"; tu = "tu_again"), r, 2)
        @test allow(pre("o1"; s = "other"), r, 5)
        @test allow(pre("o2"; s = "other"), r, 5)
        @test allow(pre("x2"), r, 2)
        @test denied(pre("x3"), r, 2)

        # TTL: an old dispatch no longer counts; a ts that does not parse counts (toward the cap)
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes"))
        write(led(r), "{\"ts\":\"2026-01-01T00:00:00Z\",\"ev\":\"dispatch\",\"session\":\"s2\",\"key\":\"old\",\"name\":\"old\"}\n")
        @test allow(pre("y1"), r, 1)
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes"))
        write(led(r), "{\"ts\":\"t\",\"ev\":\"dispatch\",\"session\":\"s2\",\"key\":\"bad\",\"name\":\"bad\"}\n")
        @test denied(pre("y1"), r, 1)
        @test hook("dispatch_limit.sh", pre("y1"), r; env = merge(cap(1), Dict("FACTORY_LANE_TTL_HOURS" => "x")))[1] == 2

        # legacy SubagentStart lines no longer count (they are not dispatches)
        r = realpath(mktempdir())
        hook("lane_ledger.sh", "{\"session_id\":\"s2\",\"hook_event_name\":\"SubagentStart\",\"agent_id\":\"b1\"}", r)
        @test allow(pre("z1"), r, 1)
        # a missing session_id is stored and queried as the same value
        r = realpath(mktempdir())
        @test allow("{\"tool_input\":{\"name\":\"n1\"}}", r, 1)
        @test denied("{\"tool_input\":{\"name\":\"n2\"}}", r, 1)
        # 0.2.3 (m4): a malformed or truncated ledger line is skipped, not fatal
        r = realpath(mktempdir())
        @test allow(pre("m1"), r, 2)
        open(io -> print(io, "garbage{\n{\"ts\":\"t\",\"ev\":\"dis"), led(r), "a")
        @test allow(pre("m2"), r, 2)
        @test denied(pre("m3"), r, 2)
        # default cap comes from limits.env (generated from the registry)
        @test occursin("MAX_OPEN_LANES=", read(joinpath(HOOKS, "limits.env"), String))

        # --- the factory028 critic's findings (each was RED on 7c61229) ---
        # B1: a GONE agent's lane (TaskStop fails validation, no hook fires) is released by `scripts/lane release`
        r = tmp_repo()
        @test allow(pre("g1"), r, 1)
        hook("lane_ledger.sh", post("g1", team("g1")), r)
        rc, _, err = hook("dispatch_limit.sh", pre("g2"), r; env = cap(1))
        @test rc == 2 && occursin("scripts/lane release g1", err)
        rel = capture(() -> Lane.main(["release", "g1", "--repo", r]))
        @test rel[1] == 0 && occursin("released g1", rel[2])
        @test occursin("\"session\":\"*\"", last(readlines(led(r))))
        @test allow(pre("g2"), r, 1)
        @test capture(() -> Lane.main(["release", "--repo", r]))[1] == 2          # a key is required
        # reviewer M1: a release after a truncated last line takes effect; a failed write is not "released"
        r = tmp_repo()
        @test allow(pre("h1"), r, 1)
        open(io -> print(io, "{\"ts\":\"2026"), led(r), "a")
        @test capture(() -> Lane.main(["release", "h1", "--repo", r]))[1] == 0
        @test allow(pre("h2"), r, 1)
        r = tmp_repo(); write(joinpath(r, ".lanes"), "a file, so .lanes/ledger.jsonl cannot be written\n")
        rel = capture(() -> Lane.main(["release", "h1", "--repo", r]))
        @test rel[1] == 1 && !occursin("released", rel[2])
        # reviewer m2: release writes the ledger the hooks read ([lanes] ledger, rendered into limits.env as LEDGER)
        r = tmp_repo(Dict(".agents/agent-registry.toml" => "[lanes]\nmax_open = 4\nledger = \"var/lanes.jsonl\"\n"))
        @test capture(() -> Lane.main(["release", "h3", "--repo", r]))[1] == 0
        @test occursin("\"ref\":\"h3\"", read(joinpath(r, "var/lanes.jsonl"), String)) && !isfile(led(r))
        # re-review n4: a registry that does not parse is a one-line error, not a stacktrace, and nothing is released
        r = tmp_repo(Dict(".agents/agent-registry.toml" => "[lanes\nledger = 5\n"))
        errf = tempname()
        rel = open(errf, "w") do io
            redirect_stderr(() -> capture(() -> Lane.main(["release", "h4", "--repo", r])), io)
        end
        @test rel[1] == 1 && !occursin("released", rel[2])
        @test occursin("agent-registry.toml", read(errf, String)) && !occursin("Stacktrace", read(errf, String))
        # M1: concurrent dispatches are serialised by a lock (6 at once, cap 2: exactly 2 pass)
        for trial in 1:3
            r = realpath(mktempdir())
            procs = map(1:6) do i
                cmd = addenv(`sh $(joinpath(TEST_HOOKS, "dispatch_limit.sh"))`, "CLAUDE_PROJECT_DIR" => r, cap(2)...)
                run(pipeline(ignorestatus(cmd); stdin = IOBuffer(pre("p$i")), stdout = devnull, stderr = devnull); wait = false)
            end
            foreach(wait, procs)
            @test count(p -> p.exitcode == 0, procs) == 2 || (println("race trial $trial: ", [p.exitcode for p in procs]); false)
            @test count(l -> occursin("\"ev\":\"dispatch\"", l), readlines(led(r))) == 2
            @test !isdir(joinpath(r, ".lanes/.dispatch.lock"))
        end
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes/.dispatch.lock"))                # a held lock: deny, fail closed
        rc, _, err = hook("dispatch_limit.sh", pre("q1"), r; env = cap(5))
        @test rc == 2 && occursin("lock", err)
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes/.dispatch.lock"))                # a stale lock is broken
        run(`touch -t 202601010000 $(joinpath(r, ".lanes/.dispatch.lock"))`)
        @test allow(pre("q1"), r, 5)
        @test !any(startswith(".dispatch.lock.stale"), readdir(joinpath(r, ".lanes")))          # moved aside, then removed
        # reviewer B1: a stale lock that is a FILE or a non-empty directory denies at once (it spun to the hook timeout)
        for kind in (:file, :nonempty)
            r = realpath(mktempdir()); lk = joinpath(r, ".lanes/.dispatch.lock"); mkpath(dirname(lk))
            kind == :file ? write(lk, "x") : (mkpath(lk); write(joinpath(lk, "f"), "x"))
            run(`touch -t 202601010000 $lk`)
            out, err = IOBuffer(), IOBuffer()
            cmd = addenv(`sh $(joinpath(TEST_HOOKS, "dispatch_limit.sh"))`, "CLAUDE_PROJECT_DIR" => r, cap(5)...)
            p = run(pipeline(ignorestatus(cmd); stdin = IOBuffer(pre("q2")), stdout = out, stderr = err); wait = false)
            done = timedwait(() -> process_exited(p), 8.0) == :ok
            done || kill(p, Base.SIGKILL)
            @test (done && p.exitcode == 2 && occursin("stale lock", String(take!(err)))) || (println("stale $kind lock: done=$done"); false)
            @test ispath(lk)                                                                   # left for a human, not deleted
        end
        # re-review m1′: when the lock changed hands mid-break (B saw it stale; by B's mv, A held a fresh one),
        # B puts A's live lock back and denies; it never removes it. A `find` shim makes the race deterministic.
        shim = mktempdir()
        write(joinpath(shim, "find"), "#!/bin/sh\ncase \"\$1\" in *.dispatch.lock) echo \"\$1\"; exit 0;; esac\nexec /usr/bin/find \"\$@\"\n")
        chmod(joinpath(shim, "find"), 0o755)
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes/.dispatch.lock"))                # A's fresh lock
        rc, _, err = hook("dispatch_limit.sh", pre("b"), r; env = merge(cap(5), Dict("PATH" => shim * ":" * ENV["PATH"])))
        @test rc == 2 && occursin("changed hands", err)
        @test isdir(joinpath(r, ".lanes/.dispatch.lock"))                                      # A's lock intact
        @test !any(startswith(".dispatch.lock.stale"), readdir(joinpath(r, ".lanes")))
        # reviewer B2: a payload that is not a JSON object is denied (0.2.7 recorded `desc:` and let all of them pass)
        r = realpath(mktempdir())
        @test all(_ -> denied("not json", r, 2), 1:4)
        @test denied("[1,2]", r, 2)
        @test !isfile(led(r)) || !any(l -> occursin("\"ev\":\"dispatch\"", l), readlines(led(r)))
        # M2: the description fallback applies only to a ref that names no lane of the session
        r = realpath(mktempdir())
        for n in ("ra", "rb")
            @test allow(pre(n; desc = "Review"), r, 5)
            hook("lane_ledger.sh", post(n, team(n); desc = "Review"), r)
        end
        hook("lane_ledger.sh", stopcall("ra"; cmd = "Review"), r)
        @test denied(pre("rc"), r, 1)                                                          # rb still open
        # M3: an unknown result status keeps the lane open (fail toward counting) and is logged
        r = realpath(mktempdir())
        @test allow(pre("k1"), r, 1)
        hook("lane_ledger.sh", post("k1", "{\"status\":\"teammate_started_v2\"}"), r)
        @test denied(pre("k2"), r, 1)
        @test any(l -> occursin("\"unknown-result\"", l) && occursin("teammate_started_v2", l), readlines(led(r)))
        hook("lane_ledger.sh", post("k1", "\"plain text\""), r)                               # not an object: still open
        @test denied(pre("k2"), r, 1)
        # M5 (docs): remote_launched is a spawn (open, its taskId closes it); auto mode's PermissionDenied closes
        r = realpath(mktempdir())
        @test allow(pre(""; tu = "tuR"), r, 1)
        hook("lane_ledger.sh", post("", "{\"status\":\"remote_launched\",\"taskId\":\"rt9\"}"; tu = "tuR"), r)
        @test denied(pre("j1"), r, 1)
        hook("lane_ledger.sh", stopcall("rt9"), r)
        @test allow(pre("j1"), r, 1)
        hook("lane_ledger.sh", post("j1", "{}"; ev = "PermissionDenied"), r)
        @test allow(pre("j2"), r, 1)
        # M4: the TTL drops only dispatches that never ran; a spawned long-running lane stays counted
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes"))
        write(led(r), "{\"ts\":\"2026-01-01T00:00:00Z\",\"ev\":\"dispatch\",\"session\":\"s2\",\"key\":\"sub\",\"name\":\"sub\"}\n" *
            "{\"ts\":\"2026-01-01T00:00:05Z\",\"ev\":\"spawned\",\"session\":\"s2\",\"key\":\"sub\",\"agent_id\":\"sub@session-s2\"}\n")
        @test denied(pre("y2"), r, 1)
        # m1: a close BEFORE a re-dispatch does not close it; an empty TaskStop ref closes no unnamed lane
        r = realpath(mktempdir())
        @test allow(pre("c1"), r, 1)
        hook("lane_ledger.sh", post("c1", team("c1")), r)
        hook("lane_ledger.sh", stopcall("c1"), r)
        @test allow(pre("c1"; tu = "tu_c1b"), r, 1)
        @test denied(pre("c2"), r, 1)
        r = realpath(mktempdir())
        @test allow(pre(""; tu = "tuB"), r, 1)
        hook("lane_ledger.sh", post("", bg("abg"); tu = "tuB"), r)
        hook("lane_ledger.sh", stopcall(""), r)
        @test denied(pre("e1"), r, 1)
    end

    # 0.4.0 testsets (quiet stops, once-per-key idle, the ledger lock, the big-ledger denial): test_hooks_040.jl

    @testset "precompact writes a snapshot; session_start re-injects it" begin
        repo = tmp_repo()
        @test hook("dispatch_limit.sh", "{\"session_id\":\"s3\",\"tool_input\":{\"name\":\"lane-pc\"}}", repo)[1] == 0
        rc, _, _ = hook("precompact.sh", "{\"session_id\":\"s3\",\"trigger\":\"auto\"}", repo)
        snap = joinpath(repo, ".lanes/precompact.md")
        @test rc == 0 && isfile(snap)
        @test occursin("    lane-pc", read(snap, String)) && occursin("(count: 1)", read(snap, String))   # 0.2.8
        @test occursin("branch: main", read(snap, String)) && occursin("Preserve:", read(snap, String))
        rc, out, _ = hook("session_start.sh", "{\"source\":\"compact\"}", repo)
        @test rc == 0 && occursin("Pre-compaction snapshot", out)
        @test hook("session_start.sh", "{}", root)[1] == 0     # no snapshot: silent
        # 0.4.0 (D2): a ledger over 2,000 lines is compacted by `scripts/lane compact` (a sibling lane's
        # work): the call is checked with a `julia` stub on PATH that records its arguments. The compaction
        # runs DETACHED (review round 1 m4): the hook returns at once (here: before the stub's 1.5 s), so the
        # host's hook timeout never kills a compaction half-way and leaves its .dispatch.lock behind.
        stub = mktempdir()
        argf = joinpath(stub, "args.txt")
        startf = joinpath(stub, "started")
        write(joinpath(stub, "julia"), "#!/bin/sh\n: >\"$startf\"\nsleep 1.5\nprintf '%s\\n' \"\$@\" >\"$argf\"\n")
        chmod(joinpath(stub, "julia"), 0o755)
        env = Dict("PATH" => stub * ":" * ENV["PATH"])
        waitfile(f) = (for _ in 1:100; isfile(f) && return true; sleep(0.05); end; false)
        repo = tmp_repo(Dict("scripts/lane.jl" => "# stub\n"))
        mkpath(joinpath(repo, ".lanes"))
        pc = "{\"session_id\":\"s3\",\"trigger\":\"manual\"}"
        write(joinpath(repo, ".lanes/ledger.jsonl"), "{\"ts\":\"t\",\"ev\":\"stop\",\"session\":\"s3\",\"agent_id\":\"a\"}\n"^2000)
        @test hook("precompact.sh", pc, repo; env)[1] == 0
        sleep(0.3)
        @test !isfile(startf)                                                 # 2,000 lines: not over the limit
        write(joinpath(repo, ".lanes/ledger.jsonl"), "{\"ts\":\"t\",\"ev\":\"stop\",\"session\":\"s3\",\"agent_id\":\"a\"}\n"^2001)
        t = @elapsed (rc = hook("precompact.sh", pc, repo; env)[1])
        @test rc == 0
        @test t < 1 || (println("precompact waited for the compaction: $t s"); false)
        @test waitfile(argf) || (println("julia not called for 2,001 lines"); false)
        args = isfile(argf) ? readlines(argf) : String[]
        @test any(a -> endswith(a, "scripts/lane.jl"), args) && "compact" in args || (println("args: $args"); false)
        @test isfile(joinpath(repo, ".lanes/precompact.md"))                 # the snapshot is written first
        rm(argf); rm(startf)
        rm(joinpath(repo, "scripts/lane.jl"))                                # no lane.jl (a seeded repo without it): no call
        @test hook("precompact.sh", pc, repo; env)[1] == 0
        sleep(0.3)
        @test !isfile(startf)
    end

    @testset "a denial from a factory/template session root says so" begin
        fac = realpath(mktempdir())
        write(joinpath(fac, "MANIFEST.toml"), "version = 1\n")
        tpl = joinpath(fac, "template")
        mkpath(tpl)
        rc, _, err = hook("write_guard.sh", write_payload("$OUT/x"), tpl)
        @test rc == 2 && occursin("factory template", err) && occursin("repo root", err)
        rc, _, err = hook("write_guard.sh", write_payload("$OUT/x"), root)
        @test rc == 2 && !occursin("factory template", err)
    end

    @testset "settings.json: guards fail CLOSED when their script is missing" begin
        settings = joinpath(ROOT, ".claude/settings.json")
        cmds = readlines(pipeline(`jq -r '.hooks.PreToolUse[].hooks[].command' $settings`))
        @test length(cmds) == 5                                  # 0.3.0: tdd_boundary.sh on two matchers
        guards = ("bash_guard.sh", "write_guard.sh", "dispatch_limit.sh", "tdd_boundary.sh")
        @test all(g -> any(contains(g), cmds), guards)
        @test count(contains("tdd_boundary.sh"), cmds) == 2
        tdd_m = readlines(pipeline(`jq -r '.hooks.PreToolUse[] | select(.hooks[].command | contains("tdd_boundary.sh")) | .matcher' $settings`))
        @test sort(tdd_m) == sort(["Read|Grep|Glob|Edit|Write|NotebookEdit|Bash|Monitor", "Agent|Task"])
        empty_root = realpath(mktempdir())                       # no .claude/hooks/ at all
        shells = filter(s -> Sys.which(s) !== nothing, ["sh", "bash", "zsh", "fish"])
        for c in cmds, s in shells                               # the command must not depend on the user's shell
            out, err = IOBuffer(), IOBuffer()
            p = run(pipeline(ignorestatus(addenv(`$s -c $c`, "CLAUDE_PROJECT_DIR" => empty_root)); stdin = IOBuffer("{}"), stdout = out, stderr = err))
            @test (p.exitcode == 2 && occursin("missing", String(take!(err)))) || (println("$s: $c -> $(p.exitcode)"); false)
        end
        # with the scripts present (a hermetic copy, 0.2.5) the same command runs the guard: allow, then deny
        proj = realpath(mktempdir())
        cp(dirname(TEST_HOOKS), joinpath(proj, ".claude"))
        bg = only(filter(contains("bash_guard.sh"), cmds))
        run1(payload) = run(pipeline(ignorestatus(addenv(`sh -c $bg`, "CLAUDE_PROJECT_DIR" => proj)); stdin = IOBuffer(payload), stdout = devnull, stderr = devnull)).exitcode
        @test run1(bash("ls")) == 0
        @test run1(bash("git reset --hard")) == 2
        # 0.4.0 (D9): Monitor runs commands outside the Bash matcher, so bash_guard sees it too; MultiEdit
        # names a tool that no longer exists. Probe 2026-10-27 (the Monitor tool's schema): its input is
        # `command` (a string, as for Bash) or `ws` (a WebSocket, no command), so a command Monitor is
        # checked like Bash and a ws Monitor is denied by the no-command rule (fails closed).
        matchers = readlines(pipeline(`jq -r '.hooks.PreToolUse[].matcher' $settings`))
        @test matchers == ["Bash|Monitor", "Edit|Write|NotebookEdit", "Agent|Task",
            "Read|Grep|Glob|Edit|Write|NotebookEdit|Bash|Monitor", "Agent|Task"] || (println("PreToolUse matchers: $matchers"); false)
        mon(ti) = "{\"session_id\":\"s1\",\"tool_name\":\"Monitor\",\"cwd\":\"$(json(proj))\",\"tool_input\":$ti}"
        @test run1(mon("{\"command\":\"tail -f app.log\",\"description\":\"d\",\"timeout_ms\":1000}")) == 0
        @test run1(mon("{\"command\":\"git reset --hard\",\"description\":\"d\",\"timeout_ms\":1000}")) == 2
        @test run1(mon("{\"ws\":{\"url\":\"wss://x\"},\"description\":\"d\",\"timeout_ms\":1000}")) == 2
        # 0.2.8: lane_ledger.sh also sees Agent/Task/TaskStop results and failures
        for ev in ("PostToolUse", "PostToolUseFailure")
            m = readlines(pipeline(`jq -r ".hooks.$ev[]? | select(.hooks[].command | contains(\"lane_ledger.sh\")) | .matcher" $settings`))
            @test m == ["Agent|Task|TaskStop"] || (println("$ev matchers: $m"); false)
        end
        @test readlines(pipeline(`jq -r '.hooks.PermissionDenied[]? | select(.hooks[].command | contains("lane_ledger.sh")) | .matcher' $settings`)) == ["Agent|Task"]
        # advisory hooks stay fail-open
        adv = readlines(pipeline(`jq -r '.hooks | to_entries[] | select(.key != "PreToolUse") | .value[].hooks[].command' $settings`))
        @test !isempty(adv) && all(c -> !occursin("exit 2", c), adv)
    end
end
