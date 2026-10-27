# lane.jl and _lib.sh's ledger(), factory 0.4.0 final review (f040-fix6). M1: an append made while the lock is held
# (a `compact` running) goes to .lanes/ledger.pending.jsonl, never to the ledger; compact folds that file, and the bytes
# appended to the ledger past its read, into the new ledger; the readers count pending lines. n1: a lock is removed only
# by its owner. M2: a report is `<dispatch name>.md` or `<dispatch name>--r<digits>.md`, the exact base name first.
# Split from test_lane.jl and test_lane_040.jl (the 400-line budget); uses ledger_ev, open_count, capture, tmp_repo, commit!.
@testset "ledger: pending appends, compact folds them and late bytes, lock owner (0.4.0 final review M1, n1)" begin
    withenv("FACTORY_LANE_TTL_HOURS" => "0") do
        h = joinpath(mktempdir(), "hooks"); cp(HOOKS, h); lsh = joinpath(h, "_lanes.sh")
        write(joinpath(h, "t.sh"), ". \"\$(dirname -- \"\$0\")/_lib.sh\"\nledger \"\$@\"\n")          # the hooks' own appender
        d = tmp_repo(Dict(".gitignore" => "/.lanes/\n")); led =joinpath(d, ".lanes/ledger.jsonl"); pend = joinpath(d, ".lanes/ledger.pending.jsonl")
        lk = joinpath(d, ".lanes/.dispatch.lock"); mkpath(dirname(led))
        app(args...) = run(pipeline(addenv(`sh $(joinpath(h, "t.sh")) $args`, "CLAUDE_PROJECT_DIR" => d); stdin = IOBuffer("{\"session_id\":\"s1\"}")))
        disp(k) = ledger_ev("2026-10-27T10:00:00Z", "dispatch"; key = k, name = k, desc = "d $k")
        write(led, disp("a") * "\n" * disp("b") * "\n")
        @test open_count(led, "s1") == 2
        # (a) the lock is held: after its wait the append goes to the pending file, the ledger is untouched
        mkdir(lk); was = read(led, String)
        app("close", "key", "a")
        @test read(led, String) == was && isfile(pend) && occursin("\"ev\":\"close\"", read(pend, String))
        @test isdir(lk); rm(lk)
        # (c) lane.jl's readers count the pending line (dispatch_limit's count: test_hooks_040b.jl)
        @test Lane.open_lanes(led, lsh) == Dict("s1" => ["b"])
        @test count(r -> r.ev == "close", Lane.ledger_rows(led)) == 1
        # (b) compact folds the pending file into the ledger and empties it; the open set is the same before and after
        rc, out = capture(() -> Lane.main(["compact", "--repo", d]))
        @test rc == 0 && occursin("\"ev\":\"close\"", read(led, String)) && (!isfile(pend) || filesize(pend) == 0) || (print(out); false)
        @test open_count(led, "s1") == 1 && !isdir(lk)
        # (b) bytes appended to the ledger between compact's read and its mv (a writer whose lock was broken as stale) are kept,
        # and an append the hooks made to the pending file meanwhile (the lock held throughout) is folded too
        late = ledger_ev("2026-10-27T10:05:00Z", "close"; session = "*", ref = "b", why = "released")
        mkdir(lk)
        rc = Lane.compact!(led, lsh, 200; io = devnull, before_mv = () -> (open(io -> println(io, late), led, "a"); app("dispatch", "key", "c", "name", "c")))
        rm(lk)
        @test rc == 0 && occursin(late, read(led, String)) && occursin("\"key\":\"c\"", read(led, String)) || (print(read(led, String)); false)
        @test open_count(led, "s1") == 1 && Lane.open_lanes(led, lsh) == Dict("s1" => ["c"]) && (!isfile(pend) || filesize(pend) == 0)
        @test count(l -> occursin(late, l), readlines(led)) == 1                                       # folded once, not twice
    end
    # n1: with_lock removes the lock only while it is still its own: a hook that broke it as stale (dispatch_limit, after
    # a minute) and took a new lock keeps that one; its own lock carries an `owner` token and is removed
    lk = joinpath(mktempdir(), ".dispatch.lock")
    @test Lane.with_lock(() -> (rm(lk; recursive = true); mkdir(lk); 1), lk) == 1
    @test isdir(lk) && !isfile(joinpath(lk, "owner"))
    rm(lk)
    @test Lane.with_lock(() -> isfile(joinpath(lk, "owner")), lk) === true && !ispath(lk)
end

@testset "report names: `<dispatch name>.md` or `<dispatch name>--r<digits>.md`, exact first (0.4.0 final review M2)" begin
    @test Lane.report_name("/x/tw-030.md") == "tw-030" && Lane.report_name("f040-review--r2.md") == "f040-review" &&
        Lane.report_name("reviewer-2.md") == "reviewer-2" && Lane.report_name("a--rx.md") == "a--rx" && Lane.report_name("a--r.md") == "a--r"
    d = tmp_repo(Dict(".gitignore" => "/.worktrees/\n/.lanes/\n", "src/A.jl" => "a\n"))
    lane(args...) = capture(() -> Lane.main([args..., "--repo", d]))
    @test lane("new", "tw", "--owns", "src/*")[1] == 0
    wt = joinpath(d, ".worktrees/tw"); commit!(wt, Dict("src/A.jl" => "b\n"), "x")
    led = joinpath(d, ".lanes/ledger.jsonl"); head = readchomp(`git -C $wt rev-parse HEAD`)
    for n in ("tw-030", "f040-review", "reviewer", "x--r2")
        open(io -> println(io, ledger_ev("2026-10-27T10:00:00Z", "dispatch"; key = n, name = n, desc = "d", subagent_type = "reviewer")), led, "a")
    end
    reports = mktempdir(); rep(n) = (p = joinpath(reports, n); write(p, "Verdict: MAY MERGE\nHead: $head\n"); p)
    for ok in ("tw-030.md", "f040-review--r2.md", "f040-review.md", "x--r2.md", "reviewer--r10.md")   # round 1 of a name ending in digits passes
        rc, out = lane("audit", "tw", "--report", rep(ok))
        @test rc == 0 && occursin("lane audit: OK", out) || (println(ok, ": ", out); false)
    end
    for (bad, n) in (("reviewer-2.md", "reviewer-2"), ("tw.md", "tw"), ("f040-review-2.md", "f040-review-2"), ("reviewer--r2x.md", "reviewer--r2x"))
        rc, out = lane("audit", "tw", "--report", rep(bad))                                           # an implementer `reviewer-2` is not `reviewer`
        @test rc == 1 && occursin("report $n is not from a read-only reviewer dispatch", out) || (println(bad, ": ", out); false)
    end
    # the pending file is read too: a dispatch the hooks wrote there while the lock was held names a reviewer
    open(io -> println(io, ledger_ev("2026-10-27T10:00:00Z", "dispatch"; key = "late", name = "late", desc = "d", subagent_type = "critic")), joinpath(d, ".lanes/ledger.pending.jsonl"), "w")
    @test lane("audit", "tw", "--report", rep("late--r1.md"))[1] == 0
end
