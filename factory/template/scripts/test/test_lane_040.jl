# lane.jl, factory 0.4.0 review round 4 (A2): a Verdict report passes `lane audit --report` only when it
# comes from a read-only reviewer dispatch (ledger `dispatch` of the report's base name with subagent_type
# reviewer, critic or verifier), its Head is on line 2, and the lane worktree is clean. Split from
# test_lane.jl (the 400-line budget of ratchets.toml); uses its helpers (ledger_ev, lane, commit!).
@testset "lane audit --report: read-only dispatch, Head on line 2, clean tree (0.4.0 round 4)" begin
    d = tmp_repo(Dict(".gitignore" => "/.worktrees/\n/.lanes/\n", "src/A.jl" => "a\n"))
    lane(args...) = capture(() -> Lane.main([args..., "--repo", d]))
    @test lane("new", "rv", "--owns", "src/*")[1] == 0
    wt = joinpath(d, ".worktrees/rv"); commit!(wt, Dict("src/A.jl" => "b\n", "changelog.d/rv.md" => "- A\n"), "x")
    led = joinpath(d, ".lanes/ledger.jsonl"); head = readchomp(`git -C $wt rev-parse HEAD`)
    reports = mktempdir(); rep(n) = joinpath(reports, n)
    ok = "Verdict: MAY MERGE\nHead: $head\n"
    ev(name, type) = ledger_ev("2026-10-27T10:00:00Z", "dispatch"; key = name, name, desc = "d", subagent_type = type)
    @test Lane.report_name("/x/rv-review-12.md") == "rv-review" && Lane.report_name("rv-review.md") == "rv-review" &&
        Lane.report_name("rv-review-x.md") == "rv-review-x" && Lane.report_name("f040-hooks-3.md") == "f040-hooks"
    # no dispatch of that name: rejected. A dispatch of another type (the real case: an implementer's own report,
    # .lanes/reports/f040-commands.md, said MAY MERGE for a HEAD the reviewer graded FIX FIRST): rejected too
    write(rep("rv-review-1.md"), ok)
    rc, out = lane("audit", "rv", "--report", rep("rv-review-1.md"))
    @test rc == 1 && occursin("[FAIL] report rv-review is not from a read-only reviewer dispatch", out) || (print(out); false)
    open(io -> (println(io, ev("rv-review", "general-purpose")); println(io, ev("rv-review", "implementer"))), led, "a")
    rc, out = lane("audit", "rv", "--report", rep("rv-review-1.md"))
    @test rc == 1 && occursin("report rv-review is not from a read-only reviewer dispatch", out) || (print(out); false)
    n = length(readlines(led))
    for t in ("reviewer", "critic", "verifier")                               # each read-only type, `<name>-<round>.md` and `<name>.md`
        open(io -> println(io, ev("rv-$t", t)), led, "a")
        write(rep("rv-$t-2.md"), ok)
        rc, out = lane("audit", "rv", "--report", rep("rv-$t-2.md"))
        @test rc == 0 && occursin("lane audit: OK", out) || (print(out); false)
        write(rep("rv-$t.md"), ok)
        @test lane("audit", "rv", "--report", rep("rv-$t.md"))[1] == 0
    end
    @test count(l -> occursin("\"ev\":\"verdict\"", l), readlines(led)) == 6
    write(rep("rv-reviewer-x.md"), ok)                                        # `-x` is not a round: the name is rv-reviewer-x
    rc, out = lane("audit", "rv", "--report", rep("rv-reviewer-x.md"))
    @test rc == 1 && occursin("report rv-reviewer-x is not from", out)
    # Head on line 3 (after a blank or another line), or no line 2: rejected, and the message names line 2
    for bad in ("Verdict: MAY MERGE\n\nHead: $head\n", "Verdict: MAY MERGE\nScope: x\nHead: $head\n", "Verdict: MAY MERGE\n")
        write(rep("rv-reviewer-3.md"), bad)
        rc, out = lane("audit", "rv", "--report", rep("rv-reviewer-3.md"))
        @test rc == 1 && occursin("no line 2 'Head: <sha>'", out) || (print(repr(bad), " => ", out); false)
    end
    # a dirty lane worktree (a modified or an untracked file): rejected with the message; clean again: passes
    write(rep("rv-reviewer-4.md"), ok); write(joinpath(wt, "src/A.jl"), "dirty\n")
    rc, out = lane("audit", "rv", "--report", rep("rv-reviewer-4.md"))
    @test rc == 1 && occursin("[FAIL] lane worktree is dirty; commit or drop before the audit", out) || (print(out); false)
    write(joinpath(wt, "src/A.jl"), "b\n")
    @test lane("audit", "rv", "--report", rep("rv-reviewer-4.md"))[1] == 0
    write(joinpath(wt, "src/untracked.jl"), "u\n")
    rc, out = lane("audit", "rv", "--report", rep("rv-reviewer-4.md"))
    @test rc == 1 && occursin("lane worktree is dirty", out)
    rm(joinpath(wt, "src/untracked.jl"))
    @test lane("audit", "rv")[1] == 0                                         # without --report neither rule applies
    # round-4 review m1: the read-only set is READ_ONLY_AGENTS of the repo's limits.env (a repo's own read_only agent, `auditor`,
    # passes), the template's three when the file or the line is absent
    @test Lane.reporters(d) == ["reviewer", "critic", "verifier"]
    write(rep("rv-auditor.md"), ok); open(io -> println(io, ev("rv-auditor", "auditor")), led, "a")
    @test lane("audit", "rv", "--report", rep("rv-auditor.md"))[1] == 1
    mkpath(joinpath(d, ".claude/hooks")); write(joinpath(d, ".claude/hooks/limits.env"), "MAX_OPEN_LANES=4\nREAD_ONLY_AGENTS=\" auditor critic reviewer verifier \"\n")
    @test Lane.reporters(d) == ["auditor", "critic", "reviewer", "verifier"]
    @test lane("audit", "rv", "--report", rep("rv-auditor.md"))[1] == 0
    write(joinpath(d, ".claude/hooks/limits.env"), "MAX_OPEN_LANES=4\n")             # no line: the fallback, auditor fails again
    rc, out = lane("audit", "rv", "--report", rep("rv-auditor.md"))
    @test rc == 1 && occursin("reviewer | critic | verifier", out)
    rm(led)                                                                   # no ledger: no dispatch to match
    rc, out = lane("audit", "rv", "--report", rep("rv-reviewer-4.md"))
    @test rc == 1 && occursin("is not from a read-only reviewer dispatch", out)
end
