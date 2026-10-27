# Factory 0.4.0 hook tests (D1, D2 and the "smaller items" of the 2026-10-27 spec): guards fail
# closed on any exit, the dispatch watchdog, bare `cd`, heredoc terminators, quiet stops, the
# ledger lock and verdict reports. Included from test_hooks.jl (whose helpers hook, bash, blocked,
# TEST_HOOKS, hooks_with_roots and REF_ROOTS it uses): split out because test_hooks.jl and
# test_hooks_lifecycle.jl are at the 400-line `scripts/*.jl` budget of ratchets.toml.
@testset "hooks: 0.4.0" begin
    root = realpath(mktempdir())

    @testset "guards fail CLOSED on any non-zero exit (0.4.0)" begin
        settings = joinpath(ROOT, ".claude/settings.json")
        cmds = readlines(pipeline(`jq -r '.hooks.PreToolUse[].hooks[].command' $settings`))
        shells = filter(s -> Sys.which(s) !== nothing, ["sh", "bash", "zsh", "fish"])
        # wrapper_exit(name, code): the settings.json command for guard `name`, run by `shell`, with a
        # stub guard that exits `code`; 143 is a guard killed by SIGTERM mid-run (a real signal here)
        function wrapper_exit(name, code; shell = "sh")
            proj = realpath(mktempdir())
            mkpath(joinpath(proj, ".claude/hooks"))
            write(joinpath(proj, ".claude/hooks", name), code == 143 ? "kill -TERM \$\$\n" : "exit $code\n")
            c = only(filter(contains(name), cmds))
            return run(pipeline(ignorestatus(addenv(`$shell -c $c`, "CLAUDE_PROJECT_DIR" => proj)); stdin = IOBuffer("{}"), stdout = devnull, stderr = devnull)).exitcode
        end
        for g in ("bash_guard.sh", "write_guard.sh", "dispatch_limit.sh"), s in shells
            @test wrapper_exit(g, 0; shell = s) == 0 || (println("$s $g: exit 0 -> blocked"); false)
            for code in (1, 3, 143)                 # 0.3.0 and before: only a MISSING guard was exit 2; 1 and 143 passed
                @test wrapper_exit(g, code; shell = s) == 2 || (println("$s $g: exit $code passed"); false)
            end
        end
        # 0.3.0's tdd_boundary.sh (two matchers) sits behind the same wrapper: 0.3.0 wired it with `exec sh`, so a crash passed
        tdd_cmds = filter(contains("tdd_boundary.sh"), cmds)
        @test length(tdd_cmds) == 2
        for c in tdd_cmds, code in (0, 1, 143)
            proj = realpath(mktempdir()); mkpath(joinpath(proj, ".claude/hooks"))
            write(joinpath(proj, ".claude/hooks/tdd_boundary.sh"), code == 143 ? "kill -TERM \$\$\n" : "exit $code\n")
            rc = run(pipeline(ignorestatus(addenv(`sh -c $c`, "CLAUDE_PROJECT_DIR" => proj)); stdin = IOBuffer("{}"), stdout = devnull, stderr = devnull)).exitcode
            @test rc == (code == 0 ? 0 : 2) || (println("tdd_boundary exit $code -> $rc"); false)
        end
        # the splitter fails: an awk that crashes, or no awk at all (jq and the other tools still found).
        # Before 0.4.0 the empty segment list was "nothing to check" and the command passed.
        shim = mktempdir()
        write(joinpath(shim, "awk"), "#!/bin/sh\nexit 1\n")
        chmod(joinpath(shim, "awk"), 0o755)
        rc, _, err = hook("bash_guard.sh", bash("ls"), root; env = Dict("PATH" => shim * ":" * ENV["PATH"]))
        @test rc == 2 && occursin("splitter", err) || (println("crashing awk: rc=$rc $err"); false)
        noawk = mktempdir()
        for t in ("sh", "cat", "dirname", "grep", "jq", "sed", "tr", "date")
            symlink(Sys.which(t), joinpath(noawk, t))
        end
        rc, _, err = hook("bash_guard.sh", bash("ls"), root; env = Dict("PATH" => noawk))
        @test rc == 2 && occursin("splitter", err) || (println("no awk: rc=$rc $err"); false)
        @test !blocked("bash_guard.sh", bash("ls"), root; env = Dict("PATH" => noawk * ":" * ENV["PATH"]))
        # (critic) an awk that exits 0 with NO output: the empty segment list must not pass a denied command
        quiet = mktempdir()
        write(joinpath(quiet, "awk"), "#!/bin/sh\nexit 0\n")
        chmod(joinpath(quiet, "awk"), 0o755)
        rc, _, err = hook("bash_guard.sh", bash("git reset --hard"), root; env = Dict("PATH" => quiet * ":" * ENV["PATH"]))
        @test rc == 2 && occursin("splitter", err) || (println("quiet awk: rc=$rc $err"); false)
        for c in ("# a comment only", "   ", "\n\n# two\n# comments")           # nothing to split is not a failure
            @test !blocked("bash_guard.sh", bash(c), root) || (println("blank command blocked: $(repr(c))"); false)
        end
        # the watchdog: a count that would take 5 s with FACTORY_WATCHDOG_SECS=1 is denied within 3 s,
        # logged as guard-timeout, and the lock is released. The slow path exists only under FACTORY_TEST=1.
        r = realpath(mktempdir())
        mkpath(joinpath(r, ".lanes"))
        open(joinpath(r, ".lanes/ledger.jsonl"), "w") do io
            for i in 1:20_000
                println(io, "{\"ts\":\"2026-10-26T03:40:00Z\",\"ev\":\"stop\",\"session\":\"s1\",\"agent_id\":\"ac$i\",\"agent_type\":\"-\"}")
            end
        end
        agent_payload = "{\"session_id\":\"s1\",\"tool_input\":{\"name\":\"wd1\",\"description\":\"d\"}}"
        slow = Dict("FACTORY_WATCHDOG_SECS" => "1", "FACTORY_SLOW_JQ" => "5", "FACTORY_TEST" => "1")
        t = @elapsed (res = hook("dispatch_limit.sh", agent_payload, r; env = slow))
        @test res[1] == 2 && occursin("dispatch_limit.sh exceeded 1 s", res[3]) || (println("watchdog: ", res); false)
        @test t < 3 || (println("watchdog took $t s"); false)
        @test any(l -> occursin("\"guard-timeout\"", l) && occursin("dispatch_limit.sh", l), readlines(joinpath(r, ".lanes/ledger.jsonl")))
        @test !isdir(joinpath(r, ".lanes/.dispatch.lock"))
        @test !any(l -> occursin("\"ev\":\"dispatch\"", l), readlines(joinpath(r, ".lanes/ledger.jsonl")))
        delete!(slow, "FACTORY_TEST")                                      # not a test run: the slow path is ignored
        t = @elapsed (res = hook("dispatch_limit.sh", agent_payload, r; env = slow))
        @test res[1] == 0 && t < 3 || (println("no FACTORY_TEST: ", res, " in $t s"); false)
        t = @elapsed hook("dispatch_limit.sh", replace(agent_payload, "wd1" => "wd2"), r; env = Dict("FACTORY_WATCHDOG_SECS" => "8"))
        @test t < 3                                                        # no sleeper holds the hook's stdout open
        @test !blocked("dispatch_limit.sh", replace(agent_payload, "wd1" => "wd3"), r; env = Dict("FACTORY_WATCHDOG_SECS" => "0"))
        # (critic; review round 1 m1) the watchdog runs from the hook's start: a held lock (its own wait is 5 s)
        # is denied at 1 s and answered within 2 s (the guard-timeout append must not wait on that lock too:
        # FACTORY_LEDGER_LOCKED); the lock, which is not ours, is left in place. FACTORY_WATCHDOG_PIDFILE
        # (under FACTORY_TEST=1) records the sleeper's pid: no sleeper of the hook survives a denial.
        function sleeper_gone(pidf)
            isfile(pidf) || return false
            pid = parse(Int, strip(read(pidf, String)))
            for _ in 1:40
                ccall(:kill, Cint, (Cint, Cint), pid, 0) == 0 || return true
                sleep(0.05)
            end
            return false
        end
        r = realpath(mktempdir())
        mkpath(joinpath(r, ".lanes/.dispatch.lock"))
        pidf = joinpath(r, "wd.pid")
        wd(secs) = Dict("FACTORY_WATCHDOG_SECS" => secs, "FACTORY_TEST" => "1", "FACTORY_WATCHDOG_PIDFILE" => pidf)
        t = @elapsed (res = hook("dispatch_limit.sh", agent_payload, r; env = wd("1")))
        @test res[1] == 2 && occursin("exceeded 1 s", res[3]) || (println("watchdog in lock wait: ", res); false)
        @test t < 2 || (println("watchdog in lock wait answered in $t s"); false)
        @test isdir(joinpath(r, ".lanes/.dispatch.lock"))
        @test any(contains("\"guard-timeout\""), readlines(joinpath(r, ".lanes/ledger.jsonl")))
        @test sleeper_gone(pidf)
        # (review round 1 m2) a denial during the lock wait (a stale lock that is not an empty directory) exits
        # before the lock is ours: the EXIT trap set with the watchdog kills the sleeper; the lock stays
        r = realpath(mktempdir())
        lk = joinpath(r, ".lanes/.dispatch.lock")
        mkpath(lk); touch(joinpath(lk, "junk")); run(`touch -t 202601010000 $lk`)       # older than a minute
        rc, _, err = hook("dispatch_limit.sh", agent_payload, r; env = wd("8"))
        @test rc == 2 && occursin("not an empty directory", err) || (println("stale non-empty lock: $rc $err"); false)
        @test isdir(lk) && isfile(joinpath(lk, "junk"))
        @test sleeper_gone(pidf) || (println("sleeper alive after a lock-wait denial"); false)
        r = realpath(mktempdir())                                          # a denial after the lock: an unreadable ledger
        mkpath(joinpath(r, ".lanes")); write(joinpath(r, ".lanes/ledger.jsonl"), "{}\n"); chmod(joinpath(r, ".lanes/ledger.jsonl"), 0o000)
        rc, _, err = hook("dispatch_limit.sh", agent_payload, r; env = wd("8"))
        @test rc == 2 && occursin("cannot read the lane ledger", err) || (println("unreadable ledger: $rc $err"); false)
        @test sleeper_gone(pidf) && !isdir(joinpath(r, ".lanes/.dispatch.lock"))
        h = joinpath(mktempdir(), "hooks"); cp(TEST_HOOKS, h); rm(joinpath(h, "_watchdog.sh"))
        rc, _, err = hook("dispatch_limit.sh", agent_payload, realpath(mktempdir()); hooks = h)
        @test rc == 2 && occursin("_watchdog.sh is missing", err)
    end

    @testset "bash_guard: bare cd, heredoc terminators, cd back (0.4.0)" begin
        # a bare `cd` moves the tracked cwd to $HOME (before: it stayed, so `cd; touch x` wrote "inside the root")
        home = "/opt/factory-test-home"                 # outside every allowed location (a mktempdir is scratch)
        for c in ("cd; touch x", "cd && touch x", "cd -P; echo x > f", "cd\ntouch x")
            rc, _, err = hook("bash_guard.sh", bash(c; cwd = root), root; env = Dict("HOME" => home))
            @test rc == 2 && occursin("$home/", err) && !occursin("blocked: $root", err) || (println("bare cd: $c -> $rc $err"); false)
        end
        @test !blocked("bash_guard.sh", bash("cd; touch x"; cwd = "/opt"), root; env = Dict("HOME" => root))   # HOME inside the root
        @test !blocked("bash_guard.sh", bash("cd; ls"; cwd = root), root; env = Dict("HOME" => home))
        # heredoc terminators are EXACT (review round 1, B1; round 2, B2): a body ends only at a line equal to
        # WORD (leading tabs stripped for <<-), never at WORD + `)`. 93306c1 also ended a body at ` EOF`, `EOF `,
        # `EOF\r` and `EOF)`, where a shell does not: the lines it then scanned as commands could open a second
        # heredoc (`cat <<ZZZ`) that swallowed the lines the shell really runs. Such a body is never terminated,
        # so the fallback checks it as commands (fails closed, as before 0.4.0).
        body = "cat <<'EOF'\nPKILL=1\npkill -f x\n"
        @test !blocked("bash_guard.sh", bash(body * "EOF"; cwd = root), root)                   # exact: a body, not a command
        @test !blocked("bash_guard.sh", bash("cat <<-'EOF'\n\tpkill -f x\n\tEOF"; cwd = root), root)   # <<-: leading tabs
        @test blocked("bash_guard.sh", bash(body * "EOF\npkill -f y"; cwd = root), root)        # after the terminator: checked
        for term in ("EOF ", "EOF)", "EOF )", "  EOF", "\tEOF", "EOF\r", "EOF \r")
            @test blocked("bash_guard.sh", bash(body * term; cwd = root), root) || (println("lenient terminator $(repr(term)) ended the body"); false)
        end
        for term in (" EOF", "EOF ", "EOF)")                   # the reproducer: bash runs `rm -rf ~` (its body ends at line 4)
            c = "cat <<EOF\n$term\ncat <<ZZZ\nEOF\nrm -rf ~\nZZZ\n"
            @test blocked("bash_guard.sh", bash(c; cwd = root), root) || (println("bypass with terminator $(repr(term))"); false)
        end
        # (review round 2, B2) WORD + `)` NEVER ends a body: inside "$(...)" bash ends it there but zsh (the Bash
        # tool's shell here) reads on to the bare EOF line and runs what follows, so an awk that ended the body
        # dropped lines zsh executes. Such a line inside a "$(...)" body is denied; the closing `)` on its own
        # line after the EOF line is read the same by bash and zsh, and stays allowed.
        for c in ("echo \"\$(cat <<EOF\nEOF)\"\ncat <<ZZZ\nEOF\n)\"\nrm -rf ~\nZZZ", "echo \"\$(cat <<EOF\nEOF )\"\ncat <<ZZZ\nEOF\n)\"\nrm -rf ~\nZZZ",
                "echo \"\$(cat <<'EOF'\npkill -f x\nEOF)\"", "echo \"\$(cat <<'EOF'\npkill -f x\nEOF)\"; git reset --hard")
            rc, _, err = hook("bash_guard.sh", bash(c; cwd = root), root)
            @test rc == 2 && occursin("closing ) on its own line", err) || (println("EOF) inside \$(...) not denied: $(repr(c)) -> $rc $err"); false)
        end
        @test !blocked("bash_guard.sh", bash("echo \"\$(cat <<'EOF'\npkill -f x\nEOF\n)\""; cwd = root), root) || (println("own-line ) blocked"); false)
        @test blocked("bash_guard.sh", bash("echo \"\$(cat <<'EOF'\npkill -f x\nEOF\n)\"; git reset --hard"; cwd = root), root)
        @test blocked("bash_guard.sh", bash("echo \"\$(cat <<'EOF'\npkill -f x\nEOF\n)\"\npkill -f y"; cwd = root), root)
        @test blocked("bash_guard.sh", bash("(cat <<'EOF'\npkill -f x\nEOF)"; cwd = root), root)   # a subshell: bash reads to end-of-file
        @test blocked("bash_guard.sh", bash("cat <<NEVER\npkill -f x\n"; cwd = root), root)      # unterminated: still the fallback
        @test blocked("bash_guard.sh", bash("cat <<'EOF'\nx\nEOFX\npkill -f x\n"; cwd = root), root)
        # (reviewer) a nested heredoc inside a never-closed outer body: the fallback scans every body line as a
        # command, and the nested `<<ZZZ` it meets there must not swallow the lines after it
        @test blocked("bash_guard.sh", bash("cat <<EOF\nx\ncat <<ZZZ\nrm -rf ~\n"; cwd = root), root)
        @test blocked("bash_guard.sh", bash("cat <<EOF\ncat <<ZZZ\nrm -rf ~\nZZZ\n"; cwd = root), root)
        # the "$(...)" closes on the line of the `<<EOF` itself: bash 5.3 reads the body from the NEXT lines (up to
        # the exact EOF), bash 3.2 and zsh run those lines as commands ("unterminated here-document"). Neither
        # model is safe for the other (a `cat <<ZZZ` among those lines swallows what follows in one of them), so
        # the construct is denied outright, whatever follows it.
        for c in ("echo \"\$(cat <<EOF)\"\nrm -rf ~\nEOF", "echo \"\$(cat <<EOF)\"\nEOF)\ncat <<ZZZ\nEOF\nrm -rf ~\nZZZ",
                "echo \"\$(cat <<EOF)\"\nls\nEOF", "cat <<EOF \"\$(echo\nhi\nEOF)\"\nrm -rf ~\nEOF")
            rc, _, err = hook("bash_guard.sh", bash(c; cwd = root), root)
            @test rc == 2 && occursin("closing ) on its own line", err) || (println("same-line \$( close not denied: $(repr(c)) -> $rc $err"); false)
        end
        # a denial inside a read-only root says how to get out
        h = hooks_with_roots(REF_ROOTS)
        rc, _, err = hook("bash_guard.sh", bash("cd ~/ro-fixture/ref-a && touch notes"; cwd = root), root; hooks = h)
        @test rc == 2 && occursin("cd back to the repo root", err)
    end

    @testset "quiet stops and once-per-key idle (0.4.0, D2)" begin
        led(r) = joinpath(r, ".lanes/ledger.jsonl")
        lines(r) = isfile(led(r)) ? readlines(led(r)) : String[]
        substop(id) = "{\"session_id\":\"s2\",\"hook_event_name\":\"SubagentStop\",\"agent_id\":\"$id\",\"agent_type\":\"\"}"
        post(name, resp) = "{\"session_id\":\"s2\",\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Agent\",\"tool_use_id\":\"tu_$name\",\"tool_input\":{\"name\":\"$name\",\"description\":\"d\"},\"tool_response\":$resp}"
        # the coordinator ledger held 1,043 `stop` lines from teammate turns, none of them a lane: a stop is
        # written only for an agent_id that a `spawned` record names (a background subagent's)
        r = realpath(mktempdir())
        @test hook("lane_ledger.sh", substop("turn-1"), r)[1] == 0
        @test hook("lane_ledger.sh", substop(""), r)[1] == 0
        @test !any(contains("\"stop\""), lines(r)) || (println("stop written: ", lines(r)); false)
        hook("lane_ledger.sh", post("bgl", "{\"status\":\"async_launched\",\"agentId\":\"a1fe55\"}"), r)
        hook("lane_ledger.sh", substop("a1fe55"), r)
        hook("lane_ledger.sh", substop("a1fe56"), r)
        @test count(l -> occursin("\"ev\":\"stop\"", l), lines(r)) == 1
        @test any(l -> occursin("\"ev\":\"stop\"", l) && occursin("\"agent_id\":\"a1fe55\"", l), lines(r))
        # (sibling review) an `unknown-result` record names an agent_id too, and OPEN_LANES_JQ closes that lane on
        # its stop: the stop must be written for it as well; a stop for an agent_id no record names writes nothing
        hook("lane_ledger.sh", post("odd", "{\"status\":\"weird\",\"agentId\":\"u1\"}"), r)
        @test any(l -> occursin("\"ev\":\"unknown-result\"", l) && occursin("\"agent_id\":\"u1\"", l), lines(r))
        hook("lane_ledger.sh", substop("u1"), r)
        hook("lane_ledger.sh", substop("u2"), r)
        @test any(l -> occursin("\"ev\":\"stop\"", l) && occursin("\"agent_id\":\"u1\"", l), lines(r)) || (println("no stop for the unknown-result agent u1"); false)
        @test !any(l -> occursin("\"ev\":\"stop\"", l) && occursin("\"agent_id\":\"u2\"", l), lines(r))
        @test count(l -> occursin("\"ev\":\"stop\"", l), lines(r)) == 2
        # three idles of one teammate without a report: one idle-blocked, then ONE idle-unreported
        r = realpath(mktempdir())
        idle = "{\"session_id\":\"s1\",\"team_name\":\"t\",\"teammate_name\":\"quiet\"}"
        @test hook("teammate_idle.sh", idle, r)[1] == 2
        @test hook("teammate_idle.sh", idle, r)[1] == 0
        @test hook("teammate_idle.sh", idle, r)[1] == 0
        @test hook("teammate_idle.sh", idle, r)[1] == 0
        @test count(contains("\"idle-unreported\""), lines(r)) == 1 || (println(lines(r)); false)
        @test count(contains("\"idle-blocked\""), lines(r)) == 1
        @test hook("teammate_idle.sh", replace(idle, "quiet" => "other"), r)[1] == 2   # another key: its own cycle
        @test hook("teammate_idle.sh", replace(idle, "quiet" => "other"), r)[1] == 0
        @test count(contains("\"idle-unreported\""), lines(r)) == 2
    end

    @testset "ledger appends take the dispatch lock; a denial names a big ledger (0.4.0 critic)" begin
        # `scripts/lane compact` rewrites the ledger under .lanes/.dispatch.lock: an append that ignored the
        # lock could land between its read and its rename and be lost. ledger() waits for the lock briefly
        # (about 1 s), then appends to ledger.pending.jsonl (final review M1); a lock it did not take is left alone.
        start = "{\"session_id\":\"s2\",\"hook_event_name\":\"SubagentStart\",\"agent_id\":\"b1\"}"
        r = realpath(mktempdir())
        lk = joinpath(r, ".lanes/.dispatch.lock")
        mkpath(lk)
        t = @elapsed (rc = hook("lane_ledger.sh", start, r)[1])
        @test rc == 0 && 0.5 < t < 5 || (println("held lock: rc=$rc in $t s"); false)
        @test any(contains("\"start\""), readlines(joinpath(r, ".lanes/ledger.pending.jsonl"))) && !isfile(joinpath(r, ".lanes/ledger.jsonl"))
        @test isdir(lk)
        t = @elapsed hook("lane_ledger.sh", start, r; env = Dict("FACTORY_LEDGER_LOCKED" => "1"))   # the caller holds it
        @test t < 0.5
        rm(lk)
        hook("lane_ledger.sh", start, r)
        @test !isdir(lk) && count(contains("\"start\""), readlines(joinpath(r, ".lanes/ledger.jsonl"))) == 3 && !isfile(joinpath(r, ".lanes/ledger.pending.jsonl"))   # folded first (round 1 B1)
        # a denial on a ledger over 2,000 lines says so and names `scripts/lane compact`
        big(n) = "{\"ts\":\"2026-10-26T03:40:00Z\",\"ev\":\"stop\",\"session\":\"s1\",\"agent_id\":\"a\"}\n"^n
        pre = "{\"session_id\":\"s1\",\"tool_input\":{\"name\":\"n1\",\"description\":\"d\"}}"
        r = realpath(mktempdir())
        mkpath(joinpath(r, ".lanes"))
        write(joinpath(r, ".lanes/ledger.jsonl"), big(2001))
        rc, _, err = hook("dispatch_limit.sh", pre, r; env = Dict("FACTORY_MAX_OPEN_LANES" => "0"))
        @test rc == 2 && occursin("2001 lines", err) && occursin("run scripts/lane compact", err) || (println(err); false)
        r = realpath(mktempdir())
        mkpath(joinpath(r, ".lanes"))
        write(joinpath(r, ".lanes/ledger.jsonl"), big(5))
        rc, _, err = hook("dispatch_limit.sh", pre, r; env = Dict("FACTORY_MAX_OPEN_LANES" => "0"))
        @test rc == 2 && !occursin("lane compact", err)
    end

    @testset "review round 4: idle takes Status or Verdict, not PENDING/PARTIAL; the main checkout's reports; FACTORY_LEDGER_LINES" begin
        # A2c, A6: a write agent's final report starts `Status: DONE | BLOCKED`; `Status: PARTIAL` and `Verdict: PENDING` (the
        # line while writing) are not reports; the hook cannot know the agent's type, so the demand names both forms
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes/reports"))
        idle(name; s = "s1") = "{\"session_id\":\"$s\",\"team_name\":\"t\",\"teammate_name\":\"$name\"}"
        for (n, ln) in (("done", "Status: DONE"), ("blocked", "Status: BLOCKED"), ("fix", "Verdict: FIX FIRST"))
            write(joinpath(r, ".lanes/reports/$n.md"), ln * "\nHead: abc\n")
            @test hook("teammate_idle.sh", idle(n), r)[1] == 0 || (println("$ln not counted"); false)
        end
        for (n, ln) in (("partial", "Status: PARTIAL"), ("pending", "Verdict: PENDING"), ("lower", "status: done"), ("bold", "**Status: DONE**"), ("trail", "Status: DONE "))
            write(joinpath(r, ".lanes/reports/$n.md"), ln * "\n")
            rc, _, err = hook("teammate_idle.sh", idle(n), r)
            @test rc == 2 && occursin("partial report", err) && occursin("Status: DONE | BLOCKED", err) && occursin("Verdict: MAY MERGE", err) || (println("$ln: $rc $err"); false)
        end
        rc, _, err = hook("teammate_idle.sh", idle("none"), r)
        @test rc == 2 && occursin("Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST", err) && occursin("Status: DONE | PARTIAL | BLOCKED", err) &&
            occursin("reviewer/critic/verifier", err) && occursin("main checkout", err) || (println(err); false)
        # A7: a session rooted in a lane worktree: the MAIN checkout's .lanes/reports/ (where write_guard's in_main lets the lane
        # write) is searched too; MAIN is trusted only when the main repo's worktree record points back (a crafted .git file is not)
        main = tmp_repo(Dict("a" => "x\n")); sh(`git -C $main worktree add -q $main/.worktrees/l1 -b l1`); lane = joinpath(main, ".worktrees/l1")
        @test hook("teammate_idle.sh", idle("mainrep"), lane)[1] == 2
        mkpath(joinpath(main, ".lanes/reports")); write(joinpath(main, ".lanes/reports/mainrep--r2.md"), "Verdict: MAY MERGE\nHead: abc\n")
        @test hook("teammate_idle.sh", idle("mainrep"; s = "s2"), lane)[1] == 0 || (println("the main checkout's report was not counted"); false)
        write(joinpath(main, ".lanes/reports/mainrep--r3.md"), "Verdict: PENDING\n")                     # a later partial round does not undo it
        @test hook("teammate_idle.sh", idle("mainrep"; s = "s3"), lane)[1] == 0
        @test hook("teammate_idle.sh", idle("mainrepx"; s = "s4"), lane)[1] == 2                      # another name's report does not count
        fake = realpath(mktempdir()); mkpath(joinpath(fake, ".worktrees/l1"))
        write(joinpath(fake, ".worktrees/l1/.git"), "gitdir: $main/.git/worktrees/l1\n")
        @test hook("teammate_idle.sh", idle("mainrep"; s = "s5"), joinpath(fake, ".worktrees/l1"))[1] == 2
        # A8: FACTORY_LEDGER_LINES (default 2000) is the line budget dispatch_limit's hint and precompact's compaction read
        big(n) = "{\"ts\":\"2026-10-26T03:40:00Z\",\"ev\":\"stop\",\"session\":\"s1\",\"agent_id\":\"a\"}\n"^n
        pre = "{\"session_id\":\"s1\",\"tool_input\":{\"name\":\"n1\",\"description\":\"d\"}}"
        r = realpath(mktempdir()); mkpath(joinpath(r, ".lanes")); write(joinpath(r, ".lanes/ledger.jsonl"), big(6))
        rc, _, err = hook("dispatch_limit.sh", pre, r; env = Dict("FACTORY_MAX_OPEN_LANES" => "0", "FACTORY_LEDGER_LINES" => "5"))
        @test rc == 2 && occursin("6 lines", err) && occursin("run scripts/lane compact", err) && occursin("above 5 lines", err) &&
            occursin("raise FACTORY_LEDGER_LINES", err) && occursin("precompact.sh", err) || (println(err); false)
        write(joinpath(r, ".lanes/ledger.jsonl"), big(6))                                            # the denial above appended a line
        rc, _, err = hook("dispatch_limit.sh", pre, r; env = Dict("FACTORY_MAX_OPEN_LANES" => "0", "FACTORY_LEDGER_LINES" => "6"))
        @test rc == 2 && !occursin("lane compact", err)
        write(joinpath(r, ".lanes/ledger.jsonl"), big(2001))
        rc, _, err = hook("dispatch_limit.sh", pre, r; env = Dict("FACTORY_MAX_OPEN_LANES" => "0", "FACTORY_LEDGER_LINES" => "3000"))
        @test rc == 2 && !occursin("lane compact", err)
        rc, _, err = hook("dispatch_limit.sh", pre, r; env = Dict("FACTORY_MAX_OPEN_LANES" => "0"))
        @test rc == 2 && occursin("above 2000 lines", err) && occursin("default 2000", err)
        stub = mktempdir(); argf = joinpath(stub, "args.txt")                                        # precompact: a julia stub records the call
        write(joinpath(stub, "julia"), "#!/bin/sh\nprintf '%s\\n' \"\$@\" >\"$argf\"\n"); chmod(joinpath(stub, "julia"), 0o755)
        repo = tmp_repo(Dict("scripts/lane.jl" => "# stub\n")); mkpath(joinpath(repo, ".lanes")); write(joinpath(repo, ".lanes/ledger.jsonl"), big(11))
        pc = "{\"session_id\":\"s3\",\"trigger\":\"manual\"}"; path = Dict("PATH" => stub * ":" * ENV["PATH"])
        @test hook("precompact.sh", pc, repo; env = path)[1] == 0                                     # 11 lines, default budget: no call
        sleep(0.5); @test !isfile(argf)
        @test hook("precompact.sh", pc, repo; env = merge(path, Dict("FACTORY_LEDGER_LINES" => "10")))[1] == 0
        waitfile(f) = (for _ in 1:100; isfile(f) && return true; sleep(0.05); end; false)
        @test waitfile(argf) && "compact" in readlines(argf) || (println("julia not called for 11 lines with FACTORY_LEDGER_LINES=10"); false)
    end
end
