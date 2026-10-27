@testset "lane.jl" begin
    d = tmp_repo(Dict(".gitignore" => "/.worktrees/\nManifest.toml\n", ".agents/agent-registry.toml" => "[lanes]\nmax_open = 2\n"))
    lane(args...) = capture(() -> Lane.main([args..., "--repo", d]))
    @test lane("new", "a")[1] == 0
    @test isdir(joinpath(d, ".worktrees/a"))
    @test readchomp(`git -C $d config branch.feat/a.lane-base`) == "main"
    @test lane("new", "b", "--prefix", "fix")[1] == 0
    rc, _ = lane("new", "c")
    @test rc == 1                                                 # cap of 2 reached
    rc, out = lane("list")
    @test rc == 0 && occursin("2/2", out) && occursin("fix/b", out)
    write(joinpath(d, ".worktrees/a/new.txt"), "x")
    @test lane("remove", "a")[1] == 1                             # dirty
    sh(`git -C $(joinpath(d, ".worktrees/a")) add new.txt`)
    sh(`git -C $(joinpath(d, ".worktrees/a")) commit -q -m lane-work`)
    @test lane("remove", "a")[1] == 1                             # not merged
    sh(`git -C $d merge -q --ff-only feat/a`)
    write(joinpath(d, ".worktrees/a/Manifest.toml"), "ignored\n")
    rc, _ = lane("remove", "a")
    @test rc == 1                                                 # ignored files would be lost
    @test lane("remove", "a", "--allow-ignored")[1] == 0
    @test !isdir(joinpath(d, ".worktrees/a"))
    @test lane("new", "Bad_Name")[1] == 2
    @test lane("remove", "nope")[1] == 1
    # from inside a lane, lanes are still managed in the main checkout
    rc, out = capture(() -> Lane.main(["list", "--repo", joinpath(d, ".worktrees/b")]))
    @test rc == 0 && occursin("lanes in $d", out)
    e = tmp_repo()                                                # .worktrees/ not ignored
    @test capture(() -> Lane.main(["new", "a", "--repo", e]))[1] == 1
end

@testset "lane audit (0.2.4)" begin
    @test Lane.audit(["src/A.jl"], ["src/*"]) == String[]
    @test Lane.audit(["src/A.jl", "docs/x.md"], ["src/*"]) == ["outside owns: docs/x.md"]
    @test Lane.audit(["src/A.jl"], String[]) == ["no owned globs recorded (create the lane with --owns, or pass --owns to audit)"]
    @test Lane.audit(["src/A.jl", "src/B.jl"], ["src/*"], ["src/A.jl", "src/C.jl"]) ==
        ["changed but not reported: src/B.jl", "reported but not changed: src/C.jl"]
    d = tmp_repo(Dict(".gitignore" => "/.worktrees/\n/.lanes/\n", "src/A.jl" => "a\n", "docs/x.md" => "x\n"))
    lane(args...) = capture(() -> Lane.main([args..., "--repo", d]))
    rc, out = lane("new", "aud", "--owns", "src/*, test/a_test.jl")
    @test rc == 0 && occursin("owns: src/* test/a_test.jl changelog.d/aud.md", out)
    @test readchomp(`git -C $d config branch.feat/aud.lane-owns`) == "src/* test/a_test.jl changelog.d/aud.md"
    led = read(joinpath(d, ".lanes/ledger.jsonl"), String)
    @test occursin("\"ev\":\"lane-new\"", led) && occursin("\"owns\":[\"src/*\",\"test/a_test.jl\",\"changelog.d/aud.md\"]", led)
    @test success(pipeline(`jq -e .owns`; stdin = IOBuffer(led), stdout = devnull))
    wt = joinpath(d, ".worktrees/aud")
    fails(out) = [String(m.captures[1]) for m in eachmatch(r"\[FAIL\] (.*)", out)]
    rc, out = lane("audit", "aud")
    @test rc == 0 && occursin("0 changed", out)
    commit!(wt, Dict("src/A.jl" => "b\n", "changelog.d/aud.md" => "- fix: A\n"), "fix: A")
    rc, out = lane("audit", "aud")
    @test rc == 0 && isempty(fails(out)) && occursin("lane audit: OK", out)
    commit!(wt, Dict("docs/x.md" => "y\n"), "docs: out of scope")              # a committed change outside owns
    rc, out = lane("audit", "aud")
    @test rc == 1 && fails(out) == ["outside owns: docs/x.md"]
    sh(`git -C $wt reset -q --soft "HEAD~1"`); sh(`git -C $wt restore -q --staged docs/x.md`); sh(`git -C $wt checkout -q -- docs/x.md`)
    write(joinpath(wt, "notes.txt"), "untracked\n")                          # an untracked file counts too
    rc, out = lane("audit", "aud")
    @test rc == 1 && fails(out) == ["outside owns: notes.txt"]
    rm(joinpath(wt, "notes.txt"))
    sh(`git -C $wt mv src/A.jl src/B.jl`); sh(`git -C $wt commit -q -m mv`)  # a rename inside owns: both paths
    rc, out = lane("audit", "aud")
    @test rc == 0 && occursin("src/A.jl", out) && occursin("src/B.jl", out)
    rep = tempname()
    write(rep, "# changed files\n- `src/A.jl`\n- src/B.jl\n- changelog.d/aud.md\n")
    rc, out = lane("audit", "aud", "--reported", rep)
    @test rc == 0 && !occursin("[info] no --reported", out)
    write(rep, "src/B.jl\nsrc/C.jl\n")                                         # the report differs from the diff
    rc, out = lane("audit", "aud", "--reported", rep)
    @test rc == 1 && fails(out) == [
        "changed but not reported: changelog.d/aud.md", "changed but not reported: src/A.jl",
        "reported but not changed: src/C.jl",
    ]
    @test lane("audit", "aud", "--owns", "docs/*")[1] == 1                      # --owns overrides the recorded globs
    # the 0.2.4 review (M3): a commit reverted in the working tree, or a staged change reverted on disk
    rc, out = lane("new", "rev", "--owns", "src/*")
    wr = joinpath(d, ".worktrees/rev")
    commit!(wr, Dict("docs/x.md" => "evil\n"), "out of scope"); write(joinpath(wr, "docs/x.md"), "x\n")
    rc, out = lane("audit", "rev")
    @test rc == 1 && fails(out) == ["outside owns: docs/x.md"]
    sh(`git -C $wr reset -q --hard "HEAD~1"`)
    write(joinpath(wr, "docs/x.md"), "staged\n"); sh(`git -C $wr add docs/x.md`); write(joinpath(wr, "docs/x.md"), "x\n")
    rc, out = lane("audit", "rev")
    @test rc == 1 && fails(out) == ["outside owns: docs/x.md"]
    sh(`git -C $wr reset -q --hard`)
    commit!(wr, Dict("src/é.jl" => "u\n"), "unicode")                        # m7: non-ASCII names are not C-quoted
    rc, out = lane("audit", "rev")
    @test rc == 0 || (print(out); false)
    @test lane("remove", "rev")[1] == 1
    sh(`git -C $d config branch.feat/rev.lane-base feat/rev`)                  # the review (m7): base rewritten to itself
    rc, out = lane("audit", "rev")
    @test rc == 1 && occursin("its base is its own branch", out)
    sh(`git -C $d config branch.feat/rev.lane-base no-such-branch`)
    rc, out = lane("audit", "rev")
    @test rc == 1 && occursin("is not a commit here", out)
    sh(`git -C $d config branch.feat/rev.lane-base main`)
    @test lane("audit", "nope")[1] == 2
    rc, out = lane("new", "bare")                                               # no --owns: the audit fails closed
    @test rc == 0 && occursin("no --owns given", out)
    commit!(joinpath(d, ".worktrees/bare"), Dict("src/A.jl" => "c\n"), "x")
    rc, out = lane("audit", "bare")
    @test rc == 1 && fails(out) == ["outside owns: src/A.jl"]
    sh(`git -C $d config --unset branch.feat/bare.lane-owns`)
    rc, out = lane("audit", "bare")
    @test rc == 1 && occursin("no owned globs recorded", out)
    rc, out = withenv("JULIA_LOAD_PATH" => "/elsewhere") do                    # env hygiene: leaky variables are named
        lane("new", "envy", "--owns", "x")
    end
    @test rc == 0 && occursin("warning: JULIA_LOAD_PATH=/elsewhere", out)
end

@testset "merge_base: the local base wins when it contains origin/<base> (0.2.6)" begin
    # factory-026 item 3: origin/main behind local main made lane audit and dod.jl count work merged locally, not pushed
    base_ref, merge_base = Lane.base_ref, Lane.merge_base                       # _common.jl, as lane.jl and dod.jl include it
    d = tmp_repo(Dict(".gitignore" => "/.worktrees/\n/.lanes/\n", "README.md" => "x\n"))
    @test base_ref(d, "main") == "main"                                         # no origin at all
    o = joinpath(mktempdir(), "origin.git")
    sh(`git clone -q --bare $d $o`); sh(`git -C $d remote add origin $o`); sh(`git -C $d fetch -q origin`)
    @test base_ref(d, "main") == "main"                                         # equal
    lane(args...) = capture(() -> Lane.main([args..., "--repo", d]))
    commit!(d, Dict("side.md" => "merged locally, not pushed\n"), "side")       # local ahead of origin/main
    @test base_ref(d, "main") == "main" && base_ref(d, "origin/main") == "origin/main"
    @test lane("new", "z", "--owns", "docs/*")[1] == 0
    wt = joinpath(d, ".worktrees/z")
    commit!(wt, Dict("docs/z.md" => "z\n"), "z")
    rc, out = lane("audit", "z")
    @test rc == 0 && !occursin("side.md", out) || (print(out); false)          # 0.2.5: FAIL outside owns: side.md
    @test merge_base(wt, "main") == readchomp(`git -C $d rev-parse main`)
    rc, out = lane("audit", "z", "--base", "origin/main")                       # --base overrides the recorded base
    @test rc == 1 && occursin("outside owns: side.md", out)
    for b in ("feat/z", "HEAD", "feat/z~0")                                     # the review: a base holding the lane's tip audits nothing
        rc, out = lane("audit", "z", "--base", b)
        @test rc == 1 && occursin("already contains the lane's tip", out) || (println("--base $b: ", out); false)
    end
    # the review: an expression or SHA is taken as given, never rewritten to origin/<expr>
    @test base_ref(wt, "HEAD~1") == "HEAD~1" && base_ref(wt, "feat/z~1") == "feat/z~1"
    @test merge_base(wt, "HEAD~1") == readchomp(`git -C $wt rev-parse "HEAD~1"`)
    sh(`git -C $d push -q origin main`); sh(`git -C $d fetch -q origin`)
    @test base_ref(d, "main") == "main"                                         # pushed: equal again
    # local behind origin (someone pushed): origin wins
    c = joinpath(mktempdir(), "c"); sh(`git clone -q $o $c`)
    sh(`git -C $c config user.email t@example.com`); sh(`git -C $c config user.name test`); sh(`git -C $c config commit.gpgsign false`)
    commit!(c, Dict("up.md" => "u\n"), "upstream"); sh(`git -C $c push -q origin main`); sh(`git -C $d fetch -q origin`)
    @test base_ref(d, "main") == "origin/main"
    # review round 2 (N1): with origin/HEAD set and origin ahead, 6fa430d rewrote HEAD~1 to origin/HEAD~1
    sh(`git -C $d remote set-head origin main`)
    @test base_ref(d, "HEAD~1") == "HEAD~1" && merge_base(d, "HEAD~1") == readchomp(`git -C $d rev-parse "HEAD~1"`)
    sh(`git -C $d branch -q -m main old`)                                       # no local main: origin
    @test base_ref(d, "main") == "origin/main" && merge_base(d, "main") !== nothing
end

@testset "merge_base without a tracking ref: origin/<b> falls back to a local <b> (0.2.7)" begin
    # factory-027 item 4: a lane saw "origin/main no longer resolves"; 0.2.6 kept the missing ref and
    # `dod.jl --base origin/main` failed with "no merge base", ratchet.jl skipped its direction check
    base_ref, merge_base = Lane.base_ref, Lane.merge_base
    d = tmp_repo(Dict(".gitignore" => "/.worktrees/\n/.lanes/\n", "README.md" => "x\n"))
    main0 = readchomp(`git -C $d rev-parse main`)
    @test base_ref(d, "origin/main") == "main" && merge_base(d, "origin/main") == main0   # no remote at all
    @test base_ref(d, "origin/nope") == "origin/nope" && merge_base(d, "origin/nope") === nothing   # no local nope either
    @test base_ref(d, "origin/") == "origin/"                                    # degenerate: never "" (HEAD)
    lane(args...) = capture(() -> Lane.main([args..., "--repo", d]))
    @test lane("new", "t", "--owns", "docs/*")[1] == 0
    wt = joinpath(d, ".worktrees/t")
    commit!(wt, Dict("docs/t.md" => "t\n"), "t")
    @test merge_base(wt, "origin/main") == main0                                 # in a lane worktree too
    rc, out = lane("audit", "t", "--base", "origin/main")
    @test rc == 0 && occursin("docs/t.md", out) || (print(out); false)           # 0.2.6: "is not a commit here"
    @test occursin("note: `origin/main` does not resolve here", out)            # review S1: the fallback is visible
    @test Lane.base_note(d, "main") === nothing && Lane.base_note(d, "origin/nope") === nothing
    @test base_ref(d, "origin/main~0") == "main~0"                               # review N1: an expression follows the rule
    # review B1: merged into the local main, `--base origin/main` (no remote) must not audit nothing and pass
    commit!(wt, Dict("src/out_of_scope.jl" => "x\n"), "outside owns")
    sh(`git -C $d merge -q --ff-only feat/t`)
    rc, out = lane("audit", "t", "--base", "origin/main")
    @test rc == 1 && occursin("already contains the lane's tip", out) || (print(out); false)   # 6e579f3: rc 0, 0 changed
    @test lane("audit", "t", "--base", main0)[1] == 1                            # an explicit base before the merge: caught
    @test occursin("outside owns: src/out_of_scope.jl", lane("audit", "t", "--base", main0)[2])
    sh(`git -C $d reset -q --hard $main0`)                                      # undo the merge for what follows
    # a remote whose tracking ref was pruned: origin/main existed, then no longer resolves
    o = joinpath(mktempdir(), "origin.git")
    sh(`git clone -q --bare $d $o`); sh(`git -C $d remote add origin $o`); sh(`git -C $d fetch -q origin`)
    @test base_ref(d, "origin/main") == "origin/main"                            # resolves: taken as given
    sh(`git -C $d update-ref -d refs/remotes/origin/main`)
    @test base_ref(d, "origin/main") == "main" && merge_base(wt, "origin/main") == main0
    @test base_ref(d, "main") == "main"                                          # the plain name: unchanged
end

@testset "lane new: the machine-local file reaches the lane (0.2.6)" begin
    # factory-026 item 1: .agents/factory.local.toml is gitignored, so a new worktree lacked it and a repo with
    # require_read_only_roots = true failed closed on every Bash call there
    d = tmp_repo(Dict(".gitignore" => "/.worktrees/\n/.lanes/\n/.agents/factory.local.toml\n/out.txt\n", "scripts/gen.jl" => "write(\"out.txt\", read(\".agents/factory.local.toml\"))\n"))
    mkpath(joinpath(d, ".agents")); write(joinpath(d, ".agents/factory.local.toml"), "[bash_guard]\nread_only_roots = [\"/x\"]\n")
    rc, out = capture(() -> Lane.main(["new", "loc", "--owns", "x", "--repo", d]))
    wt = joinpath(d, ".worktrees/loc")
    @test rc == 0 && occursin("copied .agents/factory.local.toml", out) && occursin("ran scripts/gen.jl", out)
    @test read(joinpath(wt, ".agents/factory.local.toml"), String) == read(joinpath(d, ".agents/factory.local.toml"), String)
    @test isfile(joinpath(wt, "out.txt"))                                       # gen.jl ran in the lane
    commit!(d, Dict("scripts/gen.jl" => "exit(3)\n"), "broken gen")
    rc, out = capture(() -> Lane.main(["new", "bad", "--owns", "x", "--repo", d]))
    @test rc == 0 && occursin("warning: scripts/gen.jl failed", out)            # warns; the lane exists
    rm(joinpath(d, ".agents/factory.local.toml"))
    rc, out = capture(() -> Lane.main(["new", "none", "--owns", "x", "--repo", d]))
    @test rc == 0 && !occursin("copied", out) && !isfile(joinpath(d, ".worktrees/none/.agents/factory.local.toml"))
end

# 0.4.0 (D2): one JSON line per ledger event, as the hooks' `ledger` writes it (session, then the pairs).
ledger_ev(ts, ev; session = "s1", kw...) =
    "{\"ts\":\"$ts\",\"ev\":\"$ev\",\"session\":\"$session\"" * join(",\"$k\":\"$v\"" for (k, v) in kw) * "}"
"The open-lane count of `file` for `session`, by the hooks' own query (OPEN_LANES_JQ from _lanes.sh), as dispatch_limit.sh runs it."
function open_count(file, session; lanes_sh = joinpath(HOOKS, "_lanes.sh"))
    q = ". \"\$1\" && jq -Rrn --arg s \"\$2\" --argjson ttl \"\$LANE_TTL_SECS\" \"[inputs | fromjson? // empty | objects] | \$OPEN_LANES_JQ | .count\" \"\$3\""
    return parse(Int, readchomp(`sh -c $q sh $lanes_sh $session $file`))
end

@testset "lane compact keeps open chains (0.4.0)" begin
    withenv("FACTORY_LANE_TTL_HOURS" => "0") do                                 # 0 = a dispatch never expires (the hooks' rule)
        d = tmp_repo(Dict(".gitignore" => "/.worktrees/\n/.lanes/\n"))
        led = joinpath(d, ".lanes/ledger.jsonl")
        mkpath(dirname(led))
        at(i) = "2026-10-27T$(lpad(div(i, 3600), 2, '0')):$(lpad(div(i, 60) % 60, 2, '0')):$(lpad(i % 60, 2, '0'))Z"
        ls = [
            ledger_ev(at(1), "dispatch"; key = "open1", name = "open1", desc = "d1"),
            ledger_ev(at(2), "spawned"; key = "open1", agent_id = "a-open1"),
            ledger_ev(at(3), "dispatch"; key = "done1", name = "done1", desc = "d2"),
            ledger_ev(at(4), "spawned"; key = "done1", agent_id = "a-done1"),
            ledger_ev(at(5), "close"; key = "done1", why = "returned"),
            ledger_ev(at(6), "dispatch"; key = "open2", name = "open2", desc = "d3"),  # no spawn record
            ledger_ev(at(7), "dispatch"; session = "s2", key = "other", name = "other", desc = "d4"),  # another session's lane
            ledger_ev(at(8), "stop"; agent_id = "a-open1"),                          # its own stop closes open1 (background agent)
            ledger_ev(at(9), "dispatch"; key = "open1", name = "open1", desc = "d1"),  # re-dispatched: open again
        ]
        append!(ls, (ledger_ev(at(10 + i), "stop"; agent_id = "ac$i", agent_type = "-") for i in 1:3000))
        push!(ls, "{\"ts\":\"" * at(3011) * "\",\"ev\":\"dispatch\",\"session\":\"s1\",\"key\":\"torn")   # a crash mid-write
        write(led, join(ls, "\n") * "\n")
        @test open_count(led, "s1") == 2 && open_count(led, "s2") == 1
        lane(args...) = capture(() -> Lane.main([args..., "--repo", d]))
        rc, out = lane("compact")
        @test rc == 0 && occursin(r"compacted 3010 -> \d+ lines, 3 open lanes kept", out) || (print(out); false)
        after = readlines(led)
        @test open_count(led, "s1") == 2 && open_count(led, "s2") == 1          # the same jq query the cap runs
        # the last 200 others + the 6 chain lines (open1: dispatch, spawned, its stop, re-dispatch; open2; other)
        @test 200 <= length(after) <= 200 + 6
        @test all(l -> success(pipeline(`jq -e .`; stdin = IOBuffer(l), stdout = devnull, stderr = devnull)), after)  # valid JSONL
        @test !any(l -> occursin("done1", l), after)                            # the closed chain is gone
        @test any(l -> occursin("\"key\":\"other\"", l), after)                 # another session's open lane is kept
        @test !any(l -> occursin("torn", l), after)                             # the torn line is dropped, not kept as a fragment
        @test !isfile(led * ".tmp")
        @test count(l -> occursin("\"key\":\"open1\"", l), after) == 3           # dispatch, spawned, re-dispatch
        # --keep bounds the others; the chains are always kept
        rc, out = lane("compact", "--keep", "10")
        @test rc == 0 && occursin("3 open lanes kept", out)
        after = readlines(led)
        @test 10 <= length(after) <= 16 && open_count(led, "s1") == 2 && open_count(led, "s2") == 1
        # the dispatch lock (as dispatch_limit.sh takes it) is honoured: held => exit 1, nothing written
        lock = joinpath(d, ".lanes/.dispatch.lock")
        mkdir(lock)
        was = read(led, String)
        rc, out = lane("compact")
        @test rc == 1 && read(led, String) == was
        rm(lock)
        @test lane("compact")[1] == 0 && !isdir(lock)                            # released afterwards
        # an empty or missing ledger: nothing to do, exit 0
        rm(led)
        rc, out = lane("compact")
        @test rc == 0 && occursin("compacted 0 -> 0 lines, 0 open lanes kept", out)
        @test lane("compact", "--keep", "x")[1] == 2
    end
end

@testset "lane audit --report (0.4.0)" begin
    # D5: the first line of a reviewer's or critic's report is the verdict, exact case, nothing else on the line
    d = tmp_repo(Dict(".gitignore" => "/.worktrees/\n/.lanes/\n", "src/A.jl" => "a\n"))
    lane(args...) = capture(() -> Lane.main([args..., "--repo", d]))
    @test lane("new", "rv", "--owns", "src/*")[1] == 0
    wt = joinpath(d, ".worktrees/rv")
    commit!(wt, Dict("src/A.jl" => "b\n", "changelog.d/rv.md" => "- A\n"), "x")
    led = joinpath(d, ".lanes/ledger.jsonl")
    rep = tempname()
    for v in ("MAY MERGE", "MERGE WITH FIXES", "FIX FIRST")
        write(rep, "Verdict: $v\n\nSummary: fine.\n")
        n = length(readlines(led))
        rc, out = lane("audit", "rv", "--report", rep)
        @test rc == 0 && occursin("verdict: $v", out) && occursin("lane audit: OK", out) || (print(out); false)
        last_line = last(readlines(led))
        @test length(readlines(led)) == n + 1
        @test occursin("\"ev\":\"verdict\"", last_line) && occursin("\"lane\":\"rv\"", last_line) &&
            occursin("\"verdict\":\"$v\"", last_line) && occursin("\"report\":\"$(replace(rep, "\\" => "\\\\"))\"", last_line)
        @test success(pipeline(`jq -e '.ev == "verdict"'`; stdin = IOBuffer(last_line), stdout = devnull))
    end
    # review focus 4: the enum stays mechanical. Wrong case, a leading blank line, a stray word, trailing
    # space, CRLF, a missing or empty file: exit 1, no verdict recorded, the audit's other output untouched
    n = length(readlines(led))
    msg = "report $rep has no first line 'Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST'"
    for bad in (
            "verdict: may merge\n", "\nVerdict: MAY MERGE\n", "Verdict: APPROVE\n", "Verdict: MAY MERGE \n",
            "Verdict: MAY MERGE\r\n", "Verdict:MAY MERGE\n", "Verdict: MAY MERGE (with nits)\n", "# Review\nVerdict: MAY MERGE\n", "",
        )
        write(rep, bad)
        rc, out = lane("audit", "rv", "--report", rep)
        @test rc == 1 && occursin("[FAIL] " * msg, out) || (print(repr(bad), " => ", out); false)
        @test length(readlines(led)) == n                                     # nothing recorded
    end
    rm(rep)
    rc, out = lane("audit", "rv", "--report", rep)
    @test rc == 1 && occursin("[FAIL] report $rep", out) && length(readlines(led)) == n
    # with --reported too: both checks run; a bad verdict fails even when the files match
    write(rep, "Verdict: MAY MERGE\n")
    files = tempname()
    write(files, "src/A.jl\nchangelog.d/rv.md\n")
    rc, out = lane("audit", "rv", "--report", rep, "--reported", files)
    @test rc == 0 && !occursin("[info] no --reported", out)
    write(rep, "Verdict: MAYBE\n")
    @test lane("audit", "rv", "--report", rep, "--reported", files)[1] == 1
    # an audit failure does not record the verdict either
    write(rep, "Verdict: FIX FIRST\n")
    write(joinpath(wt, "notes.txt"), "outside owns\n")
    n = length(readlines(led))
    rc, out = lane("audit", "rv", "--report", rep)
    @test rc == 1 && occursin("outside owns: notes.txt", out) && length(readlines(led)) == n
    @test lane("audit", "rv")[1] == 1 && lane("audit", "nope", "--report", rep)[1] == 2   # --report is optional; no lane: 2
end
