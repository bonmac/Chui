# The tdd.jl history and evidence rules (factory 0.3.0; spec §0.5, §3.1-3.2, §4.2, §4.3, §5.2, §6).
# Top-level definitions, included after _common.jl (it uses `git`, `merge_base`) by tdd.jl's
# `module Tdd` and by dod.jl; never run on its own, no `module` of its own, no side effects.
# Needs only Base, the SHA stdlib and _common.jl. Every failure String starts with its rule id.

using SHA: sha1

"One non-merge lane commit: `author` is `name <email>`, `phase` the `TDD:` trailer, `mode` the
commit's own `TDD-Mode:` trailer as (mode, reason), `paths` repo-relative."
struct LaneCommit
    sha::String
    author::String
    phase::Union{Nothing, String}
    mode::Union{Nothing, Tuple{String, String}}
    paths::Vector{String}
end

const LEAD_AUTHOR = "lead <lead@factory.invalid>"
role_author(role) = "$role <$role@factory.invalid>"
const PHASE_ROLE = Dict(
    "stub" => "implementer", "green" => "implementer", "refactor" => "implementer",
    "red" => "test-writer", "test-fix" => "test-writer", "test-refactor" => "test-writer", "backfill" => "test-writer",
)
const ROLE_AUTHORS = (role_author("test-writer"), role_author("implementer"))
const SEEDED_RUNNERS = ("test/runtests.jl", "test/Project.toml")
is_code_path(p) = startswith(p, "src/") || startswith(p, "ext/")
is_test_path(p) = startswith(p, "test/")
sha7(s) = first(s, 7)

# ---- Commits

"The `Key: value` lines of the last paragraph of a commit message."
function trailers(msg)
    paras = filter(p -> !isempty(strip(p)), split(msg, r"\n[ \t]*\n"))
    ms = isempty(paras) ? [] : [match(r"^([A-Za-z0-9][A-Za-z0-9-]*):\s*(.*?)\s*$", l) for l in split(last(paras), '\n')]
    return Dict{String, String}(m.captures[1] => m.captures[2] for m in ms if m !== nothing)
end
"`TDD-Mode: <mode> — <reason>` (em dash) as (mode, reason); the reason is \"\" when there is none."
parse_mode(v) = (p = split(v, " — "; limit = 2); (String(strip(p[1])), length(p) == 2 ? String(strip(p[2])) : ""))

"The paths commit `sha` changes (`--root`: a root commit's files count as added), as (status, path)."
changed(root, sha) = [(String(first(l, 1)), String(split(l, '\t')[end])) for l in
    split(something(git(root, "diff-tree", "--root", "--no-commit-id", "-r", "--no-renames", "--name-status", sha), ""), '\n'; keepempty = false)]

"The non-merge commits of `base..HEAD` (from the merge base), oldest first; `nothing` without a merge base."
function lane_commits(root, base)
    mb = merge_base(root, base)
    mb === nothing && return nothing
    shas = split(something(git(root, "rev-list", "--no-merges", "--reverse", "$mb..HEAD"), ""), '\n'; keepempty = false)
    return map(shas) do s
        info = something(git(root, "log", "-1", "--format=%an <%ae>%x00%B", s), "\0")
        author, msg = split(info, '\0'; limit = 2)
        t = trailers(msg)
        ph = strip(get(t, "TDD", ""))
        mode = haskey(t, "TDD-Mode") ? parse_mode(t["TDD-Mode"]) : nothing
        LaneCommit(String(s), String(author), isempty(ph) ? nothing : String(ph), mode, [p for (_, p) in changed(root, s)])
    end
end

# ---- H1-H9

"The lane's mode and any H8 failure about the mode trailer (spec §4.2, §6): the oldest trailer decides."
function lane_mode(commits)
    i = findfirst(c -> c.mode !== nothing, commits)
    i === nothing && return ("required", String[])
    c = commits[i]
    m, reason = c.mode
    at = "$(sha7(c.sha)) TDD-Mode: $m"
    c.author == LEAD_AUTHOR || return ("required", m == "skip" ? ["H8 $at is not authored $LEAD_AUTHOR: skip refused"] : String[])
    m in ("required", "refactor", "skip") || return ("required", ["H8 $at: unknown mode (required, refactor or skip)"])
    m == "skip" && isempty(reason) && return ("required", ["H8 $at has no reason: skip mode refused"])
    return (m, String[])
end

"""
    history_rules(commits; stub_ok) -> Vector{String}

H1-H9 of spec §4.2 over `commits` (oldest first). `stub_ok(sha)` decides H5 for each `stub`. Pure.
"""
function history_rules(commits::AbstractVector; stub_ok::Function)
    out = String[]
    fail(id, c, what) = push!(out, "$id $(sha7(c.sha)) $(something(c.phase, "(no phase)")): $what")
    # H9 always applies; an unknown phase is reported as H1
    for c in commits
        if c.phase === nothing
            c.author in ROLE_AUTHORS && fail("H9", c, "a phase-less commit authored $(c.author)")
        elseif !haskey(PHASE_ROLE, c.phase)
            fail("H1", c, "unknown phase `$(c.phase)`")
        elseif c.author != role_author(PHASE_ROLE[c.phase])
            fail("H9", c, "authored $(c.author), not $(role_author(PHASE_ROLE[c.phase]))")
        end
    end
    mode, mode_fails = lane_mode(commits)
    append!(out, mode_fails)
    mode == "skip" && return out
    any(c -> any(is_code_path, c.paths), commits) || return out           # H1: no code, H2-H8 off
    for c in commits
        tw = c.phase !== nothing && get(PHASE_ROLE, c.phase, "") == "test-writer"
        impl = c.phase !== nothing && get(PHASE_ROLE, c.phase, "") == "implementer"
        tests = filter(is_test_path, c.paths)
        c.phase === nothing && any(is_code_path, c.paths) && fail("H1", c, "changes code with no `TDD:` trailer")
        impl && !isempty(tests) && fail("H3", c, "changes test files: $(join(tests, ", "))")
        if tw
            bad = filter(p -> is_code_path(p) || p == "Project.toml" || startswith(p, "changelog.d/"), c.paths)
            isempty(bad) || fail("H3", c, "changes code, Project.toml or changelog.d: $(join(bad, ", "))")
        end
        if c.phase !== nothing
            r = filter(in(SEEDED_RUNNERS), c.paths)
            isempty(r) || fail("H3", c, "a phase commit changes the seeded runners: $(join(r, ", "))")
        end
        exempt = c.phase === nothing && c.author == LEAD_AUTHOR && all(in(SEEDED_RUNNERS), tests)
        !tw && !isempty(tests) && !exempt && fail("H4", c, "touches test/** outside a test-writer phase: $(join(tests, ", "))")
        c.phase == "stub" && !stub_ok(c.sha) && fail("H5", c, "the stub does more than declare")
    end
    if mode == "refactor"
        for c in commits
            c.phase in ("red", "test-fix", "green", "stub") && fail("H8", c, "refactor mode allows no red, green or stub")
            any(is_test_path, c.paths) && fail("H8", c, "refactor mode allows no test/** change")
        end
        return out
    end
    count(c -> c.phase == "red", commits) >= 1 || push!(out, "H2 mode required: the lane has no `TDD: red` commit")
    open, greened = false, false
    for (i, c) in enumerate(commits)
        p = c.phase
        if p == "stub"
            open && fail("H6", c, "a stub after a red that has no green yet; a stub comes before its red")
            any(x -> x.phase == "red", commits[(i + 1):end]) || fail("H6", c, "no red after this stub")
        elseif p in ("red", "test-fix")
            open = true
        elseif p == "green"
            open || fail("H6", c, "a green with no red or test-fix open before it")
            open, greened = false, true
        elseif p in ("refactor", "test-refactor")
            (greened && !open) || fail("H6", c, "a $p before a green (or while a red is open)")
        end
    end
    open && push!(out, "H7 the lane ends on a red: its green is missing")
    return out
end

# ---- H5: a stub only declares

"""`Base.remove_linenums!`, then each macrocall's own line slot (`args[2]`) set to `nothing` and the
`:toplevel` LineNumberNodes dropped: `remove_linenums!` keeps both (measured on 1.13.2 and 1.10.12)."""
function strip_lines!(ex)
    Base.remove_linenums!(ex)
    function walk(x)
        x isa Expr || return
        x.head === :macrocall && length(x.args) >= 2 && (x.args[2] = nothing)
        x.head === :toplevel && filter!(a -> !(a isa LineNumberNode), x.args)
        foreach(walk, x.args)
    end
    walk(ex)
    return ex
end
is_compat_name(n) = n === Symbol("@compat") || n == Expr(:., :Compat, QuoteNode(Symbol("@compat")))
is_names(x) = x isa Symbol || (x isa Expr && x.head === :tuple && !isempty(x.args) && all(a -> a isa Symbol, x.args))
is_export(x) = x isa Expr && x.head in (:export, :public) && all(a -> a isa Symbol, x.args)
"A `@compat public a, h` / `@compat export g` (also `Compat.@compat`) statement, as it parses."
function is_compat_decl(ex)
    (ex isa Expr && ex.head === :macrocall && length(ex.args) >= 2 && is_compat_name(ex.args[1])) || return false
    rest = ex.args[3:end]
    length(rest) == 1 && return is_export(rest[1]) && rest[1].head === :export
    return length(rest) == 2 && rest[1] === :public && is_names(rest[2])
end
"(kind, names) of an export/public/@compat statement, else nothing."
function decl_names(ex)
    is_export(ex) && return (ex.head, Set{Symbol}(ex.args))
    is_compat_decl(ex) || return nothing
    rest = ex.args[3:end]
    length(rest) == 1 && return (:export, Set{Symbol}(rest[1].args))
    return (:public, Set{Symbol}(rest[2] isa Symbol ? [rest[2]] : rest[2].args))
end
const DOC_NAMES = (GlobalRef(Core, Symbol("@doc")), Symbol("@doc"), Expr(:., :Core, QuoteNode(Symbol("@doc"))))
function field_only(body)
    for x in body.args
        (x isa Symbol || x isa String) && continue          # a field, or a field docstring
        x isa Expr && x.head === :const && length(x.args) == 1 && (x = x.args[1])
        x isa Symbol || (x isa Expr && x.head === :(::) && length(x.args) == 2 && x.args[1] isa Symbol) || return false
    end
    return true
end
"Is the added statement `ex` one H5 allows? `inc(path)` checks an `include(path)`."
function allowed_decl(ex, inc; doc = true)
    ex isa Expr || return false
    h = ex.head
    h === :function && length(ex.args) == 1 && return ex.args[1] isa Symbol
    h === :struct && return field_only(ex.args[3])
    h in (:abstract, :primitive, :using, :import) && return true
    (is_export(ex) || is_compat_decl(ex)) && return true
    h === :call && length(ex.args) == 2 && ex.args[1] === :include && ex.args[2] isa String && return inc(ex.args[2])
    if doc && h === :macrocall && length(ex.args) == 4 && ex.args[1] in DOC_NAMES && ex.args[3] isa String
        return allowed_decl(ex.args[4], _ -> false; doc = false)
    end
    return false
end
"The statements of `ex`, flattened through `module`/`baremodule` bodies, keyed by module path."
function statements!(out, ex, path = ())
    for x in (ex isa Expr && ex.head in (:toplevel, :block) ? ex.args : [ex])
        if x isa Expr && x.head === :module
            push!(out, (path, Expr(:module_decl, x.args[1], x.args[2])))   # a new module is no decl
            statements!(out, x.args[3], (path..., x.args[2]))
        elseif !(x === nothing || x isa LineNumberNode)
            push!(out, (path, x))
        end
    end
    return out
end
function parsed_statements(text, file)
    ex = Meta.parseall(text; filename = file)
    has_err(x) = x isa Expr && (x.head in (:error, :incomplete) || any(has_err, x.args))
    has_err(ex) && return nothing
    return statements!(Tuple{Tuple, Any}[], strip_lines!(ex))
end
counts(v) = (d = Dict{Any, Int}(); foreach(x -> d[x] = get(d, x, 0) + 1, v); d)
"The elements of multiset `a` not in `b`, with multiplicity."
minus(a, b) = [k for (k, n) in a for _ in 1:(n - get(b, k, 0))]

"""
    stub_declares_only(root, sha) -> Bool

H5 of spec §4.2 for the `stub` commit `sha`: every changed src/ext file only gains declarations,
compared as multisets of line-stripped statements; removals only as an export/public replaced by
a superset; `include` only of a file the commit adds, itself declaration-only.
"""
function stub_declares_only(root, sha)
    ch = changed(root, sha)
    added = Set(p for (s, p) in ch if s == "A")
    parent = git(root, "rev-parse", "--verify", "--quiet", "$sha^")
    show_(rev, p) = something(git(root, "show", "$rev:$p"), "")
    seen = Set{String}()
    function inc_ok(file, arg)
        p = normpath(joinpath(dirname(file), arg))
        (p in added && !(p in seen)) || return false
        push!(seen, p)
        st = parsed_statements(show_(sha, p), p)
        return st !== nothing && all(x -> allowed_decl(x[2], a -> inc_ok(p, a)), st)
    end
    for (s, f) in ch
        is_code_path(f) || continue
        endswith(f, ".jl") || return false
        old = s == "A" || parent === nothing ? Tuple{Tuple, Any}[] : parsed_statements(show_(parent, f), f)
        new = s == "D" ? Tuple{Tuple, Any}[] : parsed_statements(show_(sha, f), f)
        (old === nothing || new === nothing) && return false
        co, cn = counts(old), counts(new)
        plus, gone = minus(cn, co), minus(co, cn)
        all(x -> allowed_decl(x[2], a -> inc_ok(f, a)), plus) || return false
        for (path, x) in gone
            d = decl_names(x)
            d === nothing && return false
            any(y -> y[1] == path && (e = decl_names(y[2]); e !== nothing && e[1] == d[1] && d[2] ⊆ e[2]), plus) || return false
        end
    end
    return true
end

# ---- E1-E5: evidence (`<root>/.lanes/evidence/`, written by evidence.jl) and the TDD ledger

"The `key: value` header of an evidence file and its `--- tdd ---` part (\"\" when none)."
function evidence_file(path)
    isfile(path) || return nothing
    t = read(path, String)
    h = Dict{String, String}()
    for l in split(t, '\n')
        startswith(l, "--- ") && break
        m = match(r"^([a-z]+):\s*(.*)$", l)
        m === nothing || (h[m.captures[1]] = m.captures[2])
    end
    i = findfirst("\n--- tdd ---\n", t)
    return (h = h, tdd = i === nothing ? "" : t[(last(i) + 1):end])
end
clean(ev) = get(ev.h, "dirty", "") == "false" && get(ev.h, "termsignal", "") == "0"
const NOT_RED = r"\b(WRONG[-_]REASON|PASSED|NOT[-_]RUN|COLLATERAL)\b"
red_pass(ev, sha) = ev !== nothing && clean(ev) && get(ev.h, "head", "") == sha &&
    occursin(r"\b(ASSERTION|BEHAVIOUR)\b", ev.tdd) && !occursin(NOT_RED, ev.tdd)
green_pass(ev, sha) = ev !== nothing && clean(ev) && get(ev.h, "head", "") == sha && get(ev.h, "exit", "") == "0"
mutate_pass(ev) = ev !== nothing && clean(ev) && get(ev.h, "exit", "") == "0"

"The evidence kind's slug for item `name` (spec §5.2): at most 33 characters."
evidence_slug(name) = first(replace(lowercase(name), r"[^a-z0-9]+" => "-"), 24) * "-" * bytes2hex(sha1(name))[1:8]

"The `@testitem`s of a test file: name => only `@test_broken` assertions?"
function test_items(text)
    ex = Meta.parseall(text)
    items = Dict{String, Bool}()
    ex isa Expr || return items
    for x in ex.args
        x isa Expr && x.head === :macrocall && x.args[1] === Symbol("@testitem") && length(x.args) >= 4 && x.args[3] isa String || continue
        ms = Symbol[]
        walk(e) = e isa Expr && (e.head === :macrocall && e.args[1] isa Symbol && startswith(string(e.args[1]), "@test") && push!(ms, e.args[1]); foreach(walk, e.args))
        walk(x.args[end])
        items[x.args[3]] = !isempty(ms) && all(==(Symbol("@test_broken")), ms)
    end
    return items
end
"The items a commit adds (new names in its changed test files): name => @test_broken-only?"
function added_items(root, sha)
    out = Dict{String, Bool}()
    for (s, f) in changed(root, sha)
        (is_test_path(f) && endswith(f, ".jl") && s != "D") || continue
        old = s == "A" ? Dict{String, Bool}() : test_items(something(git(root, "show", "$sha^:$f"), ""))
        for (n, broken) in test_items(something(git(root, "show", "$sha:$f"), ""))
            haskey(old, n) || (out[n] = broken)
        end
    end
    return out
end

"The flat string fields of each JSONL line of the ledger (no JSON stdlib)."
function ledger_records(path)
    isfile(path) || return nothing
    return [Dict{String, String}(m.captures[1] => replace(m.captures[2], r"\\(.)" => s"\1")
        for m in eachmatch(r"\"([A-Za-z_]+)\"\s*:\s*\"((?:[^\"\\]|\\.)*)\"", l)) for l in eachline(path) if !isempty(strip(l))]
end
"The outermost ancestor-or-self of `root` that holds `.lanes/ledger.jsonl` (spec §0.5), or nothing."
function default_ledger(root)
    found, d = nothing, abspath(root)
    while true
        p = joinpath(d, ".lanes", "ledger.jsonl")
        isfile(p) && (found = p)
        dirname(d) == d && return found
        d = dirname(d)
    end
end
canon(p) = (q = rstrip(p, '/'); ispath(q) ? realpath(q) : q)

"""
    evidence_rules(root, commits; ledger, base = nothing) -> Vector{String}

E1-E5 of spec §4.3. The refactor-mode merge base is `merge_base(root, base)`, or the first
commit's parent when `base` is nothing.
"""
function evidence_rules(root, commits::AbstractVector; ledger, base = nothing)
    out = String[]
    dir = joinpath(root, ".lanes", "evidence")
    ev(kind, sha) = evidence_file(joinpath(dir, "$kind-$(sha7(sha)).txt"))
    fail(id, c, what) = push!(out, "$id $(sha7(c.sha)) $(something(c.phase, "(no phase)")): $what")
    files = isdir(dir) ? readdir(dir) : String[]
    for c in commits
        c.phase in ("red", "test-fix") && !red_pass(ev("red", c.sha), c.sha) &&
            fail("E1", c, "no passing red-$(sha7(c.sha)) (head $(c.sha), clean, ASSERTION/BEHAVIOUR items only)")
        c.phase in ("green", "refactor", "test-refactor") && !green_pass(ev("green", c.sha), c.sha) &&
            fail("E2", c, "no passing green-$(sha7(c.sha)) (head $(c.sha), clean, exit 0)")
        if c.phase == "backfill"
            for (name, broken) in sort!(collect(added_items(root, c.sha)))
                broken && (push!(out, "note $(sha7(c.sha)): `$name` has only @test_broken assertions: listed, not proved"); continue)
                s = evidence_slug(name)
                ok = any(f -> (startswith(f, "mutate-$s-") || startswith(f, "mutexp-$s-")) && endswith(f, ".txt") &&
                    mutate_pass(evidence_file(joinpath(dir, f))), files)
                ok || fail("E3", c, "item `$name` has no passing mutate-$s or mutexp-$s evidence")
            end
        end
        for f in files
            endswith(f, "-$(sha7(c.sha)).txt") || continue
            e = evidence_file(joinpath(dir, f))
            e !== nothing && !clean(e) && fail("E4", c, "evidence $f is dirty or killed")
        end
    end
    if first(lane_mode(commits)) == "refactor" && !isempty(commits)
        mb = base === nothing ? git(root, "rev-parse", "--verify", "--quiet", "$(commits[1].sha)^") : merge_base(root, base)
        (mb !== nothing && green_pass(ev("green", mb), mb)) ||
            push!(out, "E2 refactor mode: no passing green-$(sha7(something(mb, "?"))) at the merge base")
    end
    roles = filter(c -> c.author in ROLE_AUTHORS, commits)
    recs = ledger === nothing ? nothing : ledger_records(ledger)
    if recs === nothing
        isempty(roles) || push!(out, "E5 no TDD ledger ($(something(ledger, "none found above $root"))): $(length(roles)) role commit(s) unchecked")
        return out
    end
    for c in roles
        t = first(split(c.author, ' '))
        any(r -> get(r, "ev", "") == "tdd-commit" && get(r, "sha", "") == c.sha && get(r, "agent_type", "") == t, recs) ||
            fail("E5", c, "no tdd-commit record with this sha and agent_type $t in $ledger")
    end
    shas, me = Set(c.sha for c in commits), canon(root)
    for r in recs
        get(r, "ev", "") == "tdd-commit-violation" || continue
        (get(r, "sha", "") in shas || canon(get(r, "checkout", "")) == me) &&
            push!(out, "E5 tdd-commit-violation for $(sha7(get(r, "sha", "?"))): $(get(r, "reason", "(no reason)"))")
    end
    return out
end

"""
    audit(root; base = "main", ledger = nothing, io) -> exit code

H1-H9 and E1-E5 over `base..HEAD`; prints each failure (rule id first). 0 none, 1 some, 2 could
not evaluate. `ledger` defaults to `default_ledger(root)`.
"""
function audit(root; base = "main", ledger = nothing, io = stdout)
    commits = lane_commits(root, base)
    commits === nothing && (println(io, "tdd.jl audit: no merge base with `$base` in $root (exit 2)."); return 2)
    ledger = something(ledger, default_ledger(root), Some(nothing))
    v = [history_rules(commits; stub_ok = s -> stub_declares_only(root, s)); evidence_rules(root, commits; ledger, base)]
    foreach(l -> println(io, l), v)
    bad = count(l -> occursin(r"^[HE][0-9]", l), v)
    println(io, "tdd.jl audit: ", bad == 0 ? "OK" : "NOT OK, $bad failure(s)", " ($(length(commits)) commit(s), ledger $(something(ledger, "none")))")
    return bad == 0 ? 0 : 1
end
