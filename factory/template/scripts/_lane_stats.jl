# _lane_stats.jl: the ledger side of scripts/lane.jl (factory 0.4.0, D2 and D11): `compact`, `stats`
# and `handoff`. `include`d inside `module Lane`, never run. Stdlib + jq (as the hooks).
#
# The open-lane rule lives ONCE, in .claude/hooks/_lanes.sh (OPEN_LANES_JQ, LANE_TTL_SECS): this file
# sources that script through `sh` and runs the same jq query dispatch_limit.sh runs, so what
# `compact` keeps is what the cap counts.

"`_lanes.sh`: the repo's own copy, else the one beside this script (the factory template). `nothing` if neither exists."
function lanes_sh(repo)
    for p in (joinpath(repo, ".claude", "hooks", "_lanes.sh"), normpath(joinpath(@__DIR__, "..", ".claude", "hooks", "_lanes.sh")))
        isfile(p) && return p
    end
    return nothing
end

"Run `cmd`; returns (ok, stdout). Stderr is dropped."
function run_out(cmd)
    out = IOBuffer()
    ok = success(pipeline(ignorestatus(cmd); stdout = out, stderr = devnull))
    return ok, String(take!(out))
end

"""
    open_lanes(file, lanes_sh) -> Dict(session => sorted keys) or nothing

The open dispatches of every session of the ledger `file`, by the hooks' own query and TTL
(`FACTORY_LANE_TTL_HOURS` applies, as in the hooks). Sessions with no open lane are absent.
`nothing` when the query cannot be read or jq fails (the caller must not rewrite anything then).
"""
function open_lanes(file, lanes_sh)
    ok, vars = run_out(`sh -c $(raw". \"$1\" && printf '%s\n%s' \"$LANE_TTL_SECS\" \"$OPEN_LANES_JQ\"") sh $lanes_sh`)
    ok && occursin('\n', vars) || return nothing
    ttl, q = split(vars, '\n'; limit = 2)
    # bind `$s` per dispatch session of the file, then run the hooks' query unchanged
    prog = "[inputs | fromjson? // empty | objects] as \$all | [\$all[] | select(.ev == \"dispatch\") | .session // \"-\" | strings] | unique[] as \$s" *
        " | (\$all | ($q)) | select(.count > 0) | \"\\(\$s)\\t\\(.ids | join(\"\\t\"))\""
    ok, out = run_out(`jq -Rrn --argjson ttl $ttl $prog $file`)
    ok || return nothing
    open = Dict{String, Vector{String}}()
    for l in eachline(IOBuffer(out))
        parts = split(l, '\t')
        open[String(parts[1])] = sort!(String.(parts[2:end]))
    end
    return open
end

"Undo jq's @tsv escapes (the hooks sanitise their values, `lane` writes paths and verdicts)."
function untsv(s)
    occursin('\\', s) || return String(s)
    io = IOBuffer()
    cs = collect(s)
    i = 1
    while i <= length(cs)
        if cs[i] == '\\' && i < length(cs)
            c = cs[i + 1]
            print(io, c == 't' ? '\t' : c == 'n' ? '\n' : c == 'r' ? '\r' : c)
            i += 2
        else
            print(io, cs[i])
            i += 1
        end
    end
    return String(take!(io))
end

const LEDGER_FIELDS = (:line, :ts, :ev, :session, :key, :name, :agent_id, :ref, :desc, :lane, :verdict, :teammate)

"""
    ledger_rows(file) -> Vector{NamedTuple}

One row per well-formed ledger line (a torn or malformed line is skipped, as the hooks skip it):
`LEDGER_FIELDS`, missing values as `"-"` (the hooks' own placeholder), `line` the 1-based line number.
"""
function ledger_rows(file)
    isfile(file) || return NamedTuple[]
    prog = "fromjson? // empty | objects | [input_line_number, " * join((".$f" for f in LEDGER_FIELDS[2:end]), ", ") * "] | map(. // \"-\" | tostring) | @tsv"
    ok, out = run_out(`jq -Rr $prog $file`)
    ok || error("jq failed on $file")
    rows = NamedTuple[]
    for l in eachline(IOBuffer(out))
        v = untsv.(split(l, '\t'))
        length(v) == length(LEDGER_FIELDS) || continue
        push!(rows, NamedTuple{LEDGER_FIELDS}((parse(Int, v[1]), v[2:end]...)))
    end
    return rows
end

"""
    compact_keep(rows, keep) -> BitVector

Pure core of `lane compact` (the 0.4.0 critic's rule): every event is kept, in every session, except a
`stop` whose agent_id matches no `spawned` record in the file (teammate turns: the hooks count nothing
from them) and an `idle-*` event outside the last `keep` rows. Every dispatch, spawn, close and verdict
stays, so the hooks' closing rules give the same answer on the compacted file; in particular a
`close` by a ref that names a closed lane never starts closing a live re-dispatch by description.
"""
function compact_keep(rows, keep)
    aids = Set(r.agent_id for r in rows if r.ev == "spawned" && r.agent_id != "-")
    cut = max(0, length(rows) - keep)   # rows after `cut` are the last `keep` ones
    return BitVector(
        !(r.ev == "stop" && !(r.agent_id in aids)) && !(startswith(r.ev, "idle-") && i <= cut) for (i, r) in enumerate(rows)
    )
end

"""
    cmd_compact(repo, opts)

D2: rewrite the ledger as `compact_keep` says, holding the hooks' lock (`.lanes/.dispatch.lock`, mkdir,
waited for 5 s, never broken) for the whole read, rewrite and rename (a temp file, then `mv`). The open
set per session (the hooks' query) is recomputed on the result and must equal the one before, else
nothing is replaced (exit 1).
"""
function cmd_compact(repo, opts; io = stdout)
    keep = tryparse(Int, get(opts, "--keep", "200"))
    (keep === nothing || keep < 0) && return (println(stderr, "lane: --keep must be a non-negative integer"); 2)
    sh = lanes_sh(repo)
    sh === nothing && return (println(stderr, "lane: no .claude/hooks/_lanes.sh in $repo or beside lane.jl (it holds the open-lane query); nothing compacted"); 1)
    f = try
        ledger_path(repo)
    catch
        println(stderr, "lane: cannot read [lanes] ledger from .agents/agent-registry.toml (fix the file); nothing compacted")
        return 1
    end
    lock = joinpath(dirname(f), ".dispatch.lock")
    mkpath(dirname(f))
    held = false
    for _ in 1:50
        held = try
            mkdir(lock); true
        catch
            sleep(0.1); false
        end
        held && break
    end
    held || return (println(stderr, "lane: the ledger lock $lock is held (waited 5 s); nothing compacted. If no hook is running, remove that directory."); 1)
    try
        return compact!(f, sh, keep; io)
    finally
        rm(lock; force = true)
    end
end

function compact!(f, sh, keep; io)
    isfile(f) || return (println(io, "compacted 0 -> 0 lines, 0 open lanes kept"); 0)
    before = open_lanes(f, sh)
    before === nothing && return (println(stderr, "lane: the open-lane query (_lanes.sh via jq) failed on $f; nothing compacted"); 1)
    lines = readlines(f)
    rows = ledger_rows(f)
    keys = unique!(reduce(vcat, values(before); init = String[]))
    kept = compact_keep(rows, keep)
    tmp = f * ".tmp"
    open(tmp, "w") do o
        for (i, r) in enumerate(rows)
            kept[i] && println(o, lines[r.line])
        end
    end
    after = open_lanes(tmp, sh)
    if after != before
        rm(tmp; force = true)
        println(stderr, "lane: compaction would change the open lanes ($before -> $after); nothing replaced")
        return 1
    end
    mv(tmp, f; force = true)
    println(io, "compacted $(length(lines)) -> $(count(kept)) lines, $(length(keys)) open lanes kept")
    return 0
end

# --- stats and handoff (D11) --------------------------------------------------------------------

parse_ts(s) = try
    DateTime(s, dateformat"yyyy-mm-ddTHH:MM:SSZ")
catch
    nothing
end
"`2h00m` between two ledger timestamps; `-` when one does not parse."
function duration(a, b)
    ta, tb = parse_ts(a), parse_ts(b)
    (ta === nothing || tb === nothing) && return "-"
    m = max(0, round(Int, Dates.value(tb - ta) / 60_000))
    return "$(div(m, 60))h$(lpad(m % 60, 2, '0'))m"
end
"teammate_idle.sh's spelling of a name (tr -c 'A-Za-z0-9_.-' '_')."
idle_name(s) = replace(s, r"[^A-Za-z0-9_.-]" => "_")

"""
    dispatches(rows) -> Vector{NamedTuple}

One entry per `dispatch` row, closed as `_lanes.sh` closes it (the first later row of its session, or
a session-"*" close: a `close` with its key, or a ref equal to its name, key or a spawned agent id, or a
ref naming no lane of the session with its description; a `stop` of a spawned agent id), with the
`dispatch-denied` rows of its session and the `idle-unreported` rows of its name while it was open,
and the last `verdict` recorded for its name or key (`lane audit --report`). TTL expiry is not applied:
stats are history, the cap is the hooks' business.
"""
function dispatches(rows)
    out = NamedTuple[]
    for (i, d) in enumerate(rows)
        d.ev == "dispatch" || continue
        insess(r) = r.session == d.session || (r.session == "*" && r.ev == "close")
        later = [r for r in rows[(i + 1):end] if insess(r)]
        aids = Set(r.agent_id for r in later if r.ev in ("spawned", "unknown-result") && r.key == d.key && r.agent_id != "-")
        known = Set{String}()   # the names, keys and spawned agent ids of the session: a ref to one never closes by desc
        for r in rows
            insess(r) || r === d || continue
            r.ev == "dispatch" && push!(known, r.name, r.key)
            r.ev == "spawned" && push!(known, r.agent_id)
        end
        delete!(known, "-")
        closes(r) = r.ev == "close" && (
            r.key == d.key || r.ref != "-" && (
                r.ref == d.name || r.ref == d.key || r.ref in aids || (!(r.ref in known) && r.desc != "-" && r.desc == d.desc)
            )
        ) || r.ev == "stop" && r.agent_id in aids
        ci = findfirst(closes, later)
        closed = ci === nothing ? nothing : later[ci]
        last_i = closed === nothing ? length(rows) : closed.line_index
        window = rows[(i + 1):last_i]
        name = d.name == "-" ? d.key : d.name
        v = findlast(r -> r.ev == "verdict" && r.lane in (d.name, d.key), rows)
        push!(
            out, (;
                name, key = d.key, ts = d.ts, closed = closed === nothing ? "-" : closed.ts,
                duration = closed === nothing ? "open" : duration(d.ts, closed.ts),
                verdict = v === nothing ? "-" : rows[v].verdict,
                denied = count(r -> r.ev == "dispatch-denied" && r.session == d.session, window),
                idle = count(r -> r.ev == "idle-unreported" && r.teammate in (d.name, idle_name(d.name)), window),
            )
        )
    end
    return out
end

"The ledger's rows with their index in the vector (so a closing row can bound a window)."
indexed_rows(repo) = [merge(r, (; line_index = i)) for (i, r) in enumerate(ledger_rows(ledger_path(repo)))]

"`scripts/lane stats [--since ISO]`: one Markdown row per dispatch, oldest first, from `--since` (string order on the ISO timestamp)."
function cmd_stats(repo, opts; io = stdout)
    since = get(opts, "--since", "")
    println(io, "| name | dispatched | closed | duration | verdict | denied | idle-unreported |")
    println(io, "|---|---|---|---|---|---|---|")
    for x in dispatches(indexed_rows(repo))
        x.ts >= since || continue
        println(io, "| $(x.name) | $(x.ts) | $(x.closed) | $(x.duration) | $(x.verdict) | $(x.denied) | $(x.idle) |")
    end
    return 0
end

"`git worktree list --porcelain` of `repo`, the main checkout excluded: (path, head, branch)."
function worktrees(repo)
    out = something(git(repo, "worktree", "list", "--porcelain"), "")
    wts = NamedTuple[]
    for block in split(out, "\n\n")
        path, head, branch = "", "-", "-"
        for l in eachline(IOBuffer(block))
            startswith(l, "worktree ") && (path = l[10:end])
            startswith(l, "HEAD ") && (head = first(l[6:end], 7))
            startswith(l, "branch refs/heads/") && (branch = l[19:end])
            l == "detached" && (branch = "(detached)")
        end
        isempty(path) && continue
        ispath(path) && ispath(repo) && realpath(path) == realpath(repo) && continue
        push!(wts, (; path, head, branch))
    end
    return wts
end

"""
`scripts/lane handoff`: the HANDOFF "Open lanes" table. One row per worktree (one outside
`.worktrees/` is `unmanaged`: EnterWorktree lanes, plain `git worktree add`), then one per open
dispatch of the ledger with no worktree of its name.
"""
function cmd_handoff(repo; io = stdout)
    ds = dispatches(indexed_rows(repo))
    rname = basename(repo)
    function status(name)
        mine = filter(x -> x.name == name || x.key == name, ds)
        oi = findlast(x -> x.closed == "-", mine)
        s = oi !== nothing ? "open since $(mine[oi].ts)" : isempty(mine) ? "no dispatch" : "closed $(last(mine).closed)"
        vs = filter(x -> x.verdict != "-", mine)
        return isempty(vs) ? s : "$s; verdict: $(last(vs).verdict)"
    end
    println(io, "| Lane | Repo | Worktree / branch | Head | Dirty | Status |")
    println(io, "|---|---|---|---|---|---|")
    seen = String[]
    for w in worktrees(repo)
        name = basename(w.path)
        push!(seen, name)
        managed = isdir(w.path) && isdir(lanes_dir(repo)) && realpath(dirname(w.path)) == realpath(lanes_dir(repo))
        dirty = !isdir(w.path) ? "missing" : isempty(something(git(w.path, "status", "--porcelain"), "?")) ? "no" : "yes"
        println(io, "| $name | $rname | `$(relpath(w.path, repo))` / `$(w.branch)` | $(w.head) | $dirty | ", managed ? status(name) : "unmanaged", " |")
    end
    for x in ds
        x.closed == "-" && !(x.name in seen) || continue
        push!(seen, x.name)
        println(io, "| $(x.name) | $rname | - | - | - | open since $(x.ts), no worktree |")
    end
    return 0
end
