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
    compact_keep(rows, open_keys, keep) -> BitVector

Pure core of `lane compact`: keep every row of an open chain (its key; the agent ids it spawned;
any `ref` to its key, name or ids), the last `keep` other rows, and, for every kept `close` by
`ref`, the dispatch or spawn that ref names (so the hooks' "known ref" test gives the same answer).
"""
function compact_keep(rows, open_keys, keep)
    keys = Set(open_keys)
    names = Set(r.name for r in rows if r.ev == "dispatch" && r.key in keys)
    aids = Set(r.agent_id for r in rows if r.ev in ("spawned", "unknown-result") && r.key in keys)
    refs = setdiff(union(keys, names, aids), ("-",))
    kept = BitVector(r.key in keys || r.agent_id in aids || r.ref in refs for r in rows)
    others = findall(.!kept)
    kept[others[max(1, end - keep + 1):end]] .= true
    kr = Set(r.ref for (i, r) in enumerate(rows) if kept[i] && r.ev == "close" && r.ref != "-")
    for (i, r) in enumerate(rows)
        kept[i] && continue
        kept[i] = r.ev == "dispatch" && (r.name in kr || r.key in kr) || r.ev in ("spawned", "unknown-result") && r.agent_id in kr
    end
    return kept
end

"""
    cmd_compact(repo, opts)

D2: rewrite the ledger as `compact_keep` says, under the hooks' lock (`.lanes/.dispatch.lock`, mkdir,
waited for 5 s, never broken), through a temp file and a rename. The open set per session is
recomputed on the result and must equal the one before, else nothing is replaced (exit 1).
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
    kept = compact_keep(rows, keys, keep)
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
