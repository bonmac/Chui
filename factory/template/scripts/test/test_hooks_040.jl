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
        # (critic) the watchdog runs from the hook's start: a held lock (its own wait is 5 s) is denied at 1 s,
        # and that lock, which is not ours, is left in place
        r = realpath(mktempdir())
        mkpath(joinpath(r, ".lanes/.dispatch.lock"))
        t = @elapsed (res = hook("dispatch_limit.sh", agent_payload, r; env = Dict("FACTORY_WATCHDOG_SECS" => "1")))
        @test res[1] == 2 && occursin("exceeded 1 s", res[3]) && t < 3 || (println("watchdog in lock wait: ", res, " in $t s"); false)
        @test isdir(joinpath(r, ".lanes/.dispatch.lock"))
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
        # heredoc terminators bash would not accept (it reads to end-of-file: nothing after them runs) end the
        # body here too: trailing blank, `)`, leading blanks, CRLF. Before, the body fell back to being
        # checked as commands and `pkill` in it was denied. What follows the terminator is checked.
        body = "cat <<'EOF'\nPKILL=1\npkill -f x\n"
        for term in ("EOF ", "EOF)", "EOF )", "  EOF", "\tEOF", "EOF\r", "EOF \r")
            @test !blocked("bash_guard.sh", bash(body * term; cwd = root), root) || (println("heredoc terminator $(repr(term)) not accepted"); false)
            @test blocked("bash_guard.sh", bash(body * term * "\npkill -f y"; cwd = root), root) || (println("after terminator $(repr(term)) unchecked"); false)
        end
        @test blocked("bash_guard.sh", bash("echo \"\$(cat <<'EOF'\npkill -f x\nEOF)\"; git reset --hard"; cwd = root), root)
        @test !blocked("bash_guard.sh", bash("echo \"\$(cat <<'EOF'\npkill -f x\nEOF)\""; cwd = root), root)
        @test blocked("bash_guard.sh", bash("cat <<NEVER\npkill -f x\n"; cwd = root), root)      # unterminated: still the fallback
        @test blocked("bash_guard.sh", bash("cat <<'EOF'\nx\nEOFX\npkill -f x\n"; cwd = root), root)
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
        # (about 1 s), then appends anyway; a lock it did not take is left alone.
        start = "{\"session_id\":\"s2\",\"hook_event_name\":\"SubagentStart\",\"agent_id\":\"b1\"}"
        r = realpath(mktempdir())
        lk = joinpath(r, ".lanes/.dispatch.lock")
        mkpath(lk)
        t = @elapsed (rc = hook("lane_ledger.sh", start, r)[1])
        @test rc == 0 && 0.5 < t < 5 || (println("held lock: rc=$rc in $t s"); false)
        @test any(contains("\"start\""), readlines(joinpath(r, ".lanes/ledger.jsonl")))
        @test isdir(lk)
        t = @elapsed hook("lane_ledger.sh", start, r; env = Dict("FACTORY_LEDGER_LOCKED" => "1"))   # the caller holds it
        @test t < 0.5
        rm(lk)
        hook("lane_ledger.sh", start, r)
        @test !isdir(lk) && count(contains("\"start\""), readlines(joinpath(r, ".lanes/ledger.jsonl"))) == 3
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
end
