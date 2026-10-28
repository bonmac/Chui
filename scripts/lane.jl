#!/usr/bin/env julia
# lane.jl: worktree lanes, per repo, at <repo>/.worktrees/<lane>. Wrapper: scripts/lane.
#
#   scripts/lane new <name> [--repo DIR] [--base BRANCH] [--prefix feat|fix|chore|docs|test] [--owns GLOBS]
#   scripts/lane list [--repo DIR]
#   scripts/lane audit <name> [--repo DIR] [--base B] [--owns GLOBS] [--reported FILE] [--report FILE]
#   scripts/lane remove <name> [--repo DIR] [--allow-ignored]
#   scripts/lane release <agent name or lane key> [--repo DIR]
#   scripts/lane compact [--repo DIR] [--keep N]
#   scripts/lane stats [--repo DIR] [--since ISO]
#   scripts/lane handoff [--repo DIR]
#
# release (0.2.8) tells the dispatch cap (.claude/hooks/dispatch_limit.sh) that an agent lane is
#         closed when TaskStop cannot: the agent is gone, or its dispatch never ran.
# compact (0.4.0, D2) rewrites the ledger keeping every dispatch, spawn, close, verdict and denial
#         event of every session; it drops only `stop`s whose agent_id no `spawned` or
#         `unknown-result` record names (teammate turns: the hooks close nothing on them), non-JSON
#         lines and idle events outside the last N (200) lines. Atomic (tmp file, rename), holding
#         the cap's lock throughout. The open set per session (the hooks' own query, _lanes.sh) is
#         run before and after: if it would change, nothing is replaced. precompact.sh runs it past
#         2,000 lines. Code: scripts/_lane_stats.jl. Every append this script makes (`lane-new`,
#         `verdict`, `release`) takes the same lock (review round 1, M2), so none is lost in a rename.
# stats   (0.4.0, D11) one Markdown row per dispatch of the ledger: dispatched, closed (by the
#         hooks' closing rules), duration, the verdict `audit --report` recorded for that round, the
#         dispatch denials of its session and the idle-unreported events of its name while it was open.
# handoff (0.4.0, D11) the HANDOFF "Open lanes" table: one row per worktree (outside .worktrees/:
#         `unmanaged`) and per open dispatch without a worktree. Both read-only.
#
# new     refuses past the cap ([lanes] max_open in the repo's .agents/agent-registry.toml,
#         default 4) and when .worktrees/ is not gitignored; branch <prefix>/<name> from base;
#         records the base in git config branch.<branch>.lane-base and the owned file globs
#         (--owns, comma or space separated, risk.toml glob rule; `changelog.d/<name>.md` is
#         always added) in branch.<branch>.lane-owns, and appends a `lane-new` line to the ledger.
#         (0.2.6) Copies the gitignored .agents/factory.local.toml into the lane and runs
#         scripts/gen.jl there. Run from inside a lane, it still creates <repo>/.worktrees/<name>
#         (a sibling, which that lane's hooks treat as in-repo since 0.2.6).
#         Warns when JULIA_PROJECT, JULIA_LOAD_PATH or JULIA_DEPOT_PATH leak in from the parent.
# audit   (0.2.4) fails when the lane's changes since the merge base with its base (--base
#         overrides the recorded one; the local base wins when it contains origin/<base>, 0.2.6) (commits,
#         uncommitted and untracked files) touch a path outside its owned globs, when no globs
#         are recorded, or, with --reported FILE (one path per line, as the lane reported its
#         changed files), when the two lists differ. /change-review runs it before a lane lands.
#         (0.4.0, D5) --report FILE: the review report's first line must be exactly
#         `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST` (one of the three) and its second line
#         `Head: <sha>` must name the lane's current HEAD (a stale round fails), else FAIL; a passing
#         audit records {ev: verdict, lane, verdict, head, report} in the ledger (`lane stats` shows it).
#         (review round 4, A2) The report must come from a read-only reviewer: the ledger holds a
#         `dispatch` named as the report (`<name>.md` or `<name>--r<digits>.md`, exact base name first) and whose
#         subagent_type is reviewer, critic or verifier (an implementer's own report had passed as a
#         review); and the lane worktree must be clean (`git status --porcelain` empty), else FAIL.
# list   name, branch, base, ahead/behind, clean/dirty. Read-only.
# remove  refuses a dirty lane, one whose branch is not merged into its base, and one holding
#         ignored files (reports, Manifest.toml, scratch) unless --allow-ignored. Never forces.
#         Keeps the branch (delete it yourself once you are sure).
module Lane

    using TOML, Dates
    include(joinpath(@__DIR__, "_common.jl"))
    include(joinpath(@__DIR__, "_lane_stats.jl"))   # 0.4.0: compact, stats, handoff (the ledger side)

    const NAME = r"^[a-z0-9][a-z0-9-]{0,39}$"
    const PREFIXES = ("feat", "fix", "chore", "docs", "test")

    repo_root(dir) = something(git(dir, "rev-parse", "--show-toplevel"), "")
    lanes_dir(repo) = joinpath(repo, ".worktrees")

    function max_open(repo)
        p = joinpath(repo, ".agents", "agent-registry.toml")
        isfile(p) || return 4
        return get(get(TOML.parsefile(p), "lanes", Dict()), "max_open", 4)
    end

    function lanes(repo)
        d = lanes_dir(repo)
        isdir(d) || return String[]
        return sort!(filter(n -> isfile(joinpath(d, n, ".git")), readdir(d)))
    end

    function info(repo, name)
        wt = joinpath(lanes_dir(repo), name)
        br = something(git(wt, "branch", "--show-current"), "?")
        base = something(git(repo, "config", "branch.$br.lane-base"), "main")
        counts = git(wt, "rev-list", "--left-right", "--count", "$base...HEAD")
        behind, ahead = counts === nothing ? ("?", "?") : split(counts)
        dirty = !isempty(something(git(wt, "status", "--porcelain"), "x"))
        return (; name, branch = br, base, ahead, behind, dirty)
    end

    "Owned globs from a --owns value: comma or whitespace separated."
    split_globs(s) = String.(filter!(!isempty, split(s, r"[,\s]+")))

    function cmd_new(repo, name, opts; io = stdout)
        occursin(NAME, name) || return (println(stderr, "lane: name must match $(NAME.pattern)"); 2)
        prefix = get(opts, "--prefix", "feat")
        prefix in PREFIXES || return (println(stderr, "lane: --prefix must be one of $(PREFIXES)"); 2)
        base = get(opts, "--base", something(git(repo, "branch", "--show-current"), "main"))
        cap = max_open(repo)
        n = length(lanes(repo))
        n >= cap && return (println(stderr, "lane: $n lanes open in $repo (cap $cap). Merge and remove one first."); 1)
        git(repo, "check-ignore", "-q", ".worktrees/$name") === nothing &&
            return (println(stderr, "lane: .worktrees/ is not gitignored in $repo; add `/.worktrees/` to .gitignore first."); 1)
        branch = "$prefix/$name"
        wt = joinpath(lanes_dir(repo), name)
        ispath(wt) && return (println(stderr, "lane: $wt already exists"); 1)
        git(repo, "worktree", "add", "-b", branch, wt, base) === nothing &&
            return (println(stderr, "lane: git worktree add failed (does branch $branch exist?)"); 1)
        git(repo, "config", "branch.$branch.lane-base", base)
        owns = unique!([split_globs(get(opts, "--owns", "")); "changelog.d/$name.md"])
        git(repo, "config", "branch.$branch.lane-owns", join(owns, ' '))
        recorded = ledger_line(repo, "lane-new"; lane = name, branch, base, owns)
        println(io, "lane: created $wt on $branch (base $base); $(n + 1)/$cap lanes open; owns: ", join(owns, ' '))
        local_setup(repo, wt; io)
        haskey(opts, "--owns") || println(io, "lane: no --owns given: `scripts/lane audit $name` will fail until the owned globs are recorded")
        foreach(w -> println(io, "lane: warning: ", w), env_warnings())
        recorded || (println(stderr, "lane: the lane exists but its `lane-new` record was NOT written (the ledger lock is held, or the ledger is not writable)"); return 1)
        return 0
    end

    """
        local_setup(repo, wt; io) -> Bool

    Factory 0.2.6: a new worktree gets the repo's machine-local, gitignored `.agents/factory.local.toml`
    (the user's own file: copying it is the intended setup, not a T3 edit), then `scripts/gen.jl` runs
    there to render `.claude/hooks/read-only-roots.txt`. Without them a repo with
    `require_read_only_roots = true` fails closed on every Bash call in the lane. Warns, never fails.
    """
    function local_setup(repo, wt; io = stdout)
        src = joinpath(repo, FACTORY_LOCAL)
        isfile(src) || return true
        try
            mkpath(dirname(joinpath(wt, FACTORY_LOCAL)))
            cp(src, joinpath(wt, FACTORY_LOCAL); force = true)
        catch e
            println(io, "lane: warning: could not copy $FACTORY_LOCAL into the lane: ", sprint(showerror, e))
            return false
        end
        println(io, "lane: copied $FACTORY_LOCAL (machine-local, gitignored) into the lane")
        gen = joinpath(wt, "scripts", "gen.jl")
        isfile(gen) || (println(io, "lane: warning: no scripts/gen.jl in the lane; render its local files yourself"); return false)
        cmd = Cmd(`$(Base.julia_cmd()) --startup-file=no $gen`; dir = wt, ignorestatus = true)
        out = IOBuffer()
        ok = success(pipeline(cmd; stdout = out, stderr = out))
        println(
            io, ok ? "lane: ran scripts/gen.jl in the lane: " * strip(String(take!(out))) :
                "lane: warning: scripts/gen.jl failed in the lane (bash_guard may fail closed there); run it: cd $wt && julia scripts/gen.jl\n" * String(take!(out))
        )
        return ok
    end

    "The lane ledger the hooks read: `[lanes] ledger` in the registry (gen.jl renders it into limits.env), default .lanes/ledger.jsonl."
    function ledger_path(repo)
        p = joinpath(repo, ".agents", "agent-registry.toml")
        rel = isfile(p) ? get(get(TOML.parsefile(p), "lanes", Dict()), "ledger", ".lanes/ledger.jsonl") : ".lanes/ledger.jsonl"
        return joinpath(repo, rel)
    end

    const BEFORE_LEDGER_APPEND = Ref{Function}(() -> nothing)   # a test hook (test_lane_040c.jl): runs under the lock
    """
    Append one JSON line to the repo's lane ledger under the hooks' lock (`with_lock`, _lane_stats.jl);
    returns `true` if it was written (`false` when the lock was held for 5 s: review round 1, M2, an
    append between `compact`'s read and its rename was lost). Never throws. Critic round 3 M1: the line goes to the
    pending file and is then folded (as the hooks' `ledger` does), so a hook's line that timed out into pending while
    this held the lock lands first: the ledger's order is arrival order. A torn last line is ended first (0.2.8).
    """
    function ledger_line(repo, ev; kw...)
        esc(x) = "\"" * replace(string(x), "\\" => "\\\\", "\"" => "\\\"") * "\""
        val(v) = v isa AbstractVector ? "[" * join(esc.(v), ",") * "]" : esc(v)
        fields = ["\"ts\":" * esc(Dates_now()), "\"ev\":" * esc(ev), ("\"$k\":" * val(v) for (k, v) in kw)...]
        f = try
            ledger_path(repo)
        catch
            return false
        end
        written = with_lock(joinpath(dirname(f), ".dispatch.lock"); ledger = f) do   # pending folded first (review round 1 B1)
            try
                BEFORE_LEDGER_APPEND[]()
                append_lines(pending_file(f), Vector{UInt8}("{" * join(fields, ",") * "}"))
                fold_pending!(f)
                true
            catch
                false
            end
        end
        return written === true
    end
    Dates_now() = Dates.format(Dates.now(Dates.UTC), "yyyy-mm-ddTHH:MM:SS") * "Z"

    """
        audit(changed, owns, reported) -> problems

    Pure core of `lane audit`: every changed path must match an owned glob, and, when the lane
    reported its changed files (`reported !== nothing`), the two lists must be equal.
    """
    function audit(changed, owns, reported = nothing)
        bad = String[]
        isempty(owns) && push!(bad, "no owned globs recorded (create the lane with --owns, or pass --owns to audit)")
        for f in changed
            isempty(owns) || any(g -> globmatch(g, f), owns) || push!(bad, "outside owns: $f")
        end
        if reported !== nothing
            foreach(f -> push!(bad, "changed but not reported: $f"), sort!(setdiff(changed, reported)))
            foreach(f -> push!(bad, "reported but not changed: $f"), sort!(setdiff(reported, changed)))
        end
        return bad
    end

    "Paths in a reported-files list: one per line; blank lines and # comments skipped; `- ` and backticks stripped."
    read_reported(path) = sort!(
        unique!(
            [
                strip(replace(l, r"^\s*[-*]\s+" => "", "`" => "")) for l in eachline(path)
                    if !isempty(strip(l)) && !startswith(strip(l), "#")
            ]
        )
    )

    function cmd_audit(repo, name, opts; io = stdout)
        name in lanes(repo) || return (println(stderr, "lane: no lane `$name` in $repo"); 2)
        l = info(repo, name)
        wt = joinpath(lanes_dir(repo), name)
        owns = haskey(opts, "--owns") ? split_globs(opts["--owns"]) :
            split_globs(something(git(repo, "config", "branch.$(l.branch).lane-owns"), ""))
        if haskey(opts, "--base")   # 0.2.6: audit against another base, never one that already holds the lane's own commits
            # bases as base_ref resolves them (0.2.7 review B1: the raw name made `git` fail and the check pass)
            ahead = something(git(wt, "rev-list", "--count", "$(base_ref(wt, l.base))..HEAD"), "0")
            git(wt, "merge-base", "--is-ancestor", "HEAD", base_ref(wt, opts["--base"])) !== nothing && ahead != "0" &&
                return (println(io, "lane audit $name: [FAIL] --base $(opts["--base"]) already contains the lane's tip ($ahead commits past $(l.base)): it would audit nothing\nlane audit: FAILED (1)"); 1)
            l = merge(l, (; base = opts["--base"]))
        end
        # the review: a lane-base rewritten to the lane's own branch (or to a missing ref) audits nothing
        l.base == l.branch && return (println(io, "lane audit $name: [FAIL] its base is its own branch ($(l.base)): branch.$(l.branch).lane-base was rewritten\nlane audit: FAILED (1)"); 1)
        rb = base_ref(wt, l.base)   # an `origin/<b>` that does not resolve here is the local `<b>` (0.2.7)
        git(wt, "rev-parse", "--verify", "--quiet", "$rb^{commit}") === nothing &&
            return (println(io, "lane audit $name: [FAIL] its base `$(l.base)` is not a commit here\nlane audit: FAILED (1)"); 1)
        note = base_note(wt, l.base)
        if note !== nothing
            println(io, note)
            # 0.2.7 review B1: `--base origin/<b>` audits a lane merged locally against the remote; when the
            # local `<b>` stands in for it and already holds the lane's tip, the audit would see nothing
            git(wt, "merge-base", "--is-ancestor", "HEAD", rb) !== nothing &&
                return (println(io, "lane audit $name: [FAIL] the local `$rb` standing in for `$(l.base)` already contains the lane's tip (merged locally, or the lane has no commits yet): it would audit nothing. Fetch the remote, or pass --base <the commit before the merge>\nlane audit: FAILED (1)"); 1)
        end
        mb = merge_base(wt, l.base)
        mb === nothing && return (println(stderr, "lane: no merge base between $(l.base) and $(l.branch)"); 2)
        lines(x) = String.(filter!(!isempty, split(something(x, ""), '\n')))
        # the commits (merge base..HEAD), the index and the working tree, each on its own (a change committed
        # and then reverted in the working tree is still on the branch), plus untracked files; renames count
        # at both paths; quotePath=false keeps non-ASCII names as they are
        g(args...) = lines(git(wt, "-c", "core.quotePath=false", args...))
        changed = sort!(
            unique!(
                [
                    g("diff", "--name-only", "--no-renames", mb, "HEAD"); g("diff", "--name-only", "--no-renames", "--cached", mb);
                    g("diff", "--name-only", "--no-renames"); g("ls-files", "--others", "--exclude-standard")
                ]
            )
        )
        reported = haskey(opts, "--reported") ? read_reported(opts["--reported"]) : nothing
        bad = audit(changed, owns, reported)
        report = get(opts, "--report", nothing)   # 0.4.0 (D5): the review report's first line is the verdict; a Head line names this HEAD
        head = something(git(wt, "rev-parse", "HEAD"), "")
        verdict, problem = report === nothing ? (nothing, nothing) : report_check(report, head)
        problem === nothing || push!(bad, problem)
        if report !== nothing   # review round 4 (A2): a reviewer's report, of a lane that holds nothing uncommitted
            problem = report_dispatch(repo, report)
            problem === nothing || push!(bad, problem)
            l.dirty && push!(bad, "lane worktree is dirty; commit or drop before the audit")
        end
        println(
            io, "lane audit $name: $(l.branch) vs $(l.base) (merge base $(first(mb, 10))), $(length(changed)) changed; owns: ",
            isempty(owns) ? "(none)" : join(owns, ' ')
        )
        foreach(f -> println(io, "    ", f), changed)
        foreach(b -> println(io, "  [FAIL] ", b), bad)
        reported === nothing && println(io, "  [info] no --reported list: the lane's own changed-file list was not compared")
        verdict === nothing || println(io, "  verdict: $verdict ($report)")
        # the verdict is recorded only for a passing audit, so `lane stats` never shows one for a lane that failed it
        isempty(bad) && verdict !== nothing && !ledger_line(repo, "verdict"; lane = name, verdict, head, report) &&
            push!(bad, "could not write the verdict to the lane ledger $(ledger_path(repo))")
        println(io, isempty(bad) ? "lane audit: OK" : "lane audit: FAILED ($(length(bad)))")
        return isempty(bad) ? 0 : 1
    end

    const VERDICT = r"^Verdict: (MAY MERGE|MERGE WITH FIXES|FIX FIRST)$"
    const HEADLINE = r"^Head: ([0-9a-f]{7,40})$"
    """
        report_check(path, head) -> (verdict, problem)

    0.4.0 (D5): a review report's first line is exactly `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST`
    (one of the three, exact case, nothing else on the line: no bold, not the template line, a CR counts),
    and its second line `Head: <sha>` (full, or a prefix of 7+ hex characters; review round 4: line 2 exactly,
    as the `_verdict` fragment asks) names the lane worktree's HEAD, so a report of an earlier round cannot
    pass this one. One of the two results is `nothing`. Anchored and mechanical on purpose: `verdict: may
    merge` is no verdict.
    """
    function report_check(path, head)
        isfile(path) || return nothing, "report $path is missing"
        ls = [endswith(l, '\n') ? l[1:prevind(l, lastindex(l))] : l for l in readlines(path; keep = true)]
        m = isempty(ls) ? nothing : match(VERDICT, ls[1])
        m === nothing && return nothing, "report $path has no first line 'Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST'"
        h = length(ls) < 2 ? nothing : match(HEADLINE, ls[2])
        h === nothing && return nothing, "report $path has no line 2 'Head: <sha>' naming the lane's HEAD $(first(head, 7))"
        startswith(head, h.captures[1]) ||
            return nothing, "report $path names Head $(h.captures[1]) but the lane's HEAD is $(first(head, 7)): a stale round; the review must be of this HEAD"
        return String(m.captures[1]), nothing
    end
    # report_dispatch (round 4, A2: the report's name is a reviewer/critic/verifier dispatch of the ledger) is in _lane_stats.jl

    function cmd_list(repo; io = stdout)
        ls = lanes(repo)
        println(io, "lanes in $repo: $(length(ls))/$(max_open(repo))")
        for n in ls
            l = info(repo, n)
            println(
                io, "  ", rpad(l.name, 24), rpad(l.branch, 30), "base ", rpad(l.base, 12),
                "+", l.ahead, "/-", l.behind, l.dirty ? "  DIRTY" : "  clean"
            )
        end
        return 0
    end

    function cmd_remove(repo, name; io = stdout, allow_ignored = false)
        name in lanes(repo) || return (println(stderr, "lane: no lane `$name` in $repo"); 1)
        l = info(repo, name)
        l.dirty && return (println(stderr, "lane: `$name` has uncommitted changes; commit or discard them first."); 1)
        git(repo, "merge-base", "--is-ancestor", l.branch, l.base) === nothing &&
            return (println(stderr, "lane: $(l.branch) is not merged into $(l.base); merge it (after review) first."); 1)
        wt = joinpath(lanes_dir(repo), name)
        ignored = filter(!isempty, split(something(git(wt, "status", "--porcelain", "--ignored"), ""), '\n'))
        if !isempty(ignored) && !allow_ignored
            println(stderr, "lane: `$name` holds ignored files that removal would delete:")
            foreach(l -> println(stderr, "    ", l), first(ignored, 20))
            println(stderr, "lane: copy what you need (e.g. reports) out, then re-run with --allow-ignored.")
            return 1
        end
        git(repo, "worktree", "remove", wt) === nothing &&
            return (println(stderr, "lane: git worktree remove failed"); 1)
        println(io, "lane: removed .worktrees/$name (branch $(l.branch) kept)")
        return 0
    end

    """
        cmd_release(repo, key)

    Close an agent lane the dispatch cap still counts (factory 0.2.8, critic B1): appends
    `{ev: close, ref: key, why: released, session: "*"}`, which `_lanes.sh` matches in every session
    against a dispatch's name, key or agent id. For an agent that is gone: a TaskStop for it fails
    validation and fires no hook. `key` is sanitised as the hooks' `ledger` does.
    """
    function cmd_release(repo, key; io = stdout)
        k = replace(key, r"[^A-Za-z0-9_./:@-]" => "_")
        f = ledger_file(repo, "$k is NOT released")
        f === nothing && return 1
        if !ledger_line(repo, "close"; session = "*", ref = k, why = "released")
            println(stderr, "lane: could not write the lane ledger $f (its lock is held, or it is not writable); $k is NOT released")
            return 1
        end
        println(io, "lane: released $k (the dispatch cap no longer counts a lane with that name, key or agent id)")
        return 0
    end

    function main(args)
        usage = "usage: scripts/lane new <name> [--repo DIR] [--base B] [--prefix P] [--owns GLOBS] | list [--repo DIR] | audit <name> [--repo DIR] [--base B] [--owns GLOBS] [--reported FILE] [--report FILE] | remove <name> [--repo DIR] [--allow-ignored] | release <agent name or lane key> [--repo DIR] | compact [--repo DIR] [--keep N] | stats [--repo DIR] [--since ISO] | handoff [--repo DIR]"
        opts, pos = try
            parse_args(args, ("--allow-ignored",), ("--repo", "--base", "--prefix", "--owns", "--reported", "--report", "--keep", "--since"))
        catch e
            println(stderr, "lane: ", e isa ErrorException ? e.msg : e)
            return 2
        end
        isempty(pos) && (println(stderr, usage); return 2)
        repo = repo_root(abspath(get(opts, "--repo", pwd())))
        isempty(repo) && (println(stderr, "lane: not inside a git repository"); return 2)
        # A lane's own checkout resolves to the lane; manage lanes from the main checkout.
        common = git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
        common === nothing || (repo = dirname(common))
        sub = pos[1]
        sub == "list" && length(pos) == 1 && return cmd_list(repo)
        sub == "new" && length(pos) == 2 && return cmd_new(repo, pos[2], opts)
        sub == "audit" && length(pos) == 2 && return cmd_audit(repo, pos[2], opts)
        sub == "release" && length(pos) == 2 && !isempty(pos[2]) && return cmd_release(repo, pos[2])
        sub == "remove" && length(pos) == 2 && return cmd_remove(repo, pos[2]; allow_ignored = get(opts, "--allow-ignored", false))
        sub == "compact" && length(pos) == 1 && return cmd_compact(repo, opts)
        sub == "stats" && length(pos) == 1 && return cmd_stats(repo, opts)
        sub == "handoff" && length(pos) == 1 && return cmd_handoff(repo)
        println(stderr, usage)
        return 2
    end

end # module

abspath(PROGRAM_FILE) == @__FILE__() && exit(Lane.main(ARGS))
