# Validate contract files against ADR-0010's format (see README.md).
# Usage: julia --startup-file=no check.jl <contracts-dir>
# Checks: entry headers and `since=… status=…` lines; unique, sequential IDs; stable entries have
# Statement/Example/test:; `names:` lines are qualified with the owning package; the DRAFT banner
# is present while the ADRs it depends on are not all Accepted, and absent once they are; every
# julia block parses; every "(Base only)"
# block runs and matches its `# -> <value>` expectations.
const HDR = r"^### (C[CTF]-\d{3}) (.+)$"
const META = r"^`since=(\S+) status=(stable|deprecated|retired)`$"
const PREFIX = Dict("chui-core.md" => "CC", "chui-types.md" => "CT", "chui-frames.md" => "CF")
const OWNER = Dict("chui-core.md" => "ChuiCore", "chui-types.md" => "ChuiTypes", "chui-frames.md" => "ChuiFrames")
const EXPECT = r"#\s*->\s*(.+?)\s*$"
const BANNER = "**DRAFT: not binding.**"
const BINDING_ADRS = ("0002", "0004", "0007", "0009", "0010")

dir = ARGS[1]
nerr = Ref(0)
err(msg) = (nerr[] += 1; println("  ERROR: ", msg))

# returns (fence flag per line, julia blocks [(startline, preceding-text, code)])
function scan(lines)
    infence = false; lang = ""; buf = String[]; start = 0
    blocks = Tuple{Int,String,String}[]; fenced = falses(length(lines))
    for (i, l) in enumerate(lines)
        m = match(r"^\s*```(\w*)\s*$", l)
        if m !== nothing
            if !infence
                infence = true; lang = m[1]; buf = String[]; start = i
            else
                infence = false
                lang == "julia" && push!(blocks, (start, start > 1 ? lines[start-1] : "", join(buf, "\n")))
            end
            fenced[i] = true; continue
        end
        fenced[i] = infence
        infence && push!(buf, l)
    end
    infence && err("unterminated code fence")
    fenced, blocks
end

# Are all the ADRs the contracts rest on Accepted?
function adrs_accepted(adrdir)
    isdir(adrdir) || (err("ADR directory not found: $adrdir"); return false)
    ok = true
    for n in BINDING_ADRS
        fs = filter(f -> startswith(f, n * "-"), readdir(adrdir))
        length(fs) == 1 || (err("expected one ADR-$n file in $adrdir, found $(length(fs))"); ok = false; continue)
        st = findfirst(l -> startswith(l, "- **Status:**"), readlines(joinpath(adrdir, fs[1])))
        line = st === nothing ? "" : readlines(joinpath(adrdir, fs[1]))[st]
        accepted = startswith(strip(replace(line, "- **Status:**" => "")), "Accepted")
        println("  ADR-$n: ", accepted ? "Accepted" : "not Accepted")
        ok &= accepted
    end
    ok
end

# Run a Base-only block; check each `# -> value` expectation against repr of that expression.
function run_base_only(f, ln, code)
    ex = Meta.parseall(code)
    codelines = split(code, '\n')
    # pair each top-level expression with its first line (from the preceding LineNumberNode)
    items = Tuple{Int,Any}[]; cur = 1
    for a in ex.args
        a isa LineNumberNode ? (cur = a.line) : push!(items, (cur, a))
    end
    mod = Module(Symbol("Snip", ln))
    nexp = 0
    for (k, (l, a)) in enumerate(items)
        v = try
            Core.eval(mod, a)
        catch e
            err("$f:$(ln + l) Base-only block threw: $(sprint(showerror, e))"); return 0
        end
        stop = k < length(items) ? items[k+1][1] - 1 : length(codelines)
        exps = [m[1] for m in (match(EXPECT, codelines[i]) for i in l:stop) if m !== nothing]
        isempty(exps) && continue
        nexp += 1
        want = String(last(exps)); got = repr(v)
        if got == want
            println("  ok  $f:$(ln + l)  -> ", got)
        else
            err("$f:$(ln + l) expected `# -> $want` but got `$got`")
        end
    end
    nexp == 0 && err("$f:$ln Base-only block has no `# -> <value>` expectation")
    nexp
end

accepted = adrs_accepted(joinpath(dir, "..", "adr"))
total_blocks = 0; ran = 0; nexpect = 0
for f in ["README.md", "chui-core.md", "chui-types.md", "chui-frames.md"]
    path = joinpath(dir, f)
    lines = readlines(path)
    println(f, " (", length(lines), " lines)")
    hasbanner = any(l -> occursin(BANNER, l), lines)
    accepted || hasbanner ||
        err("$f has no DRAFT banner ($BANNER) but ADR-$(join(BINDING_ADRS, "/")) are not all Accepted")
    accepted && hasbanner &&
        err("$f still has the DRAFT banner ($BANNER) but ADR-$(join(BINDING_ADRS, "/")) are all Accepted")
    fenced, blocks = scan(lines)
    if haskey(PREFIX, f)
        pre = PREFIX[f]; ids = String[]; nstable = 0
        prov = findfirst(==("## PROVISIONAL"), lines)
        prov === nothing && err("no '## PROVISIONAL' section")
        hdrs = [i for i in eachindex(lines) if !fenced[i] && startswith(lines[i], "### ")]
        for (k, i) in enumerate(hdrs)
            m = match(HDR, lines[i])
            m === nothing && (err("line $i: '### ' heading does not match ADR-0010 regex: $(lines[i])"); continue)
            id = m[1]
            startswith(id, pre * "-") || err("line $i: $id has the wrong prefix for $f")
            prov !== nothing && i > prov && err("line $i: $id is inside PROVISIONAL (must have no ID)")
            mm = i < length(lines) ? match(META, lines[i+1]) : nothing
            mm === nothing && (err("line $(i+1): $id not followed by `since=… status=…`"); continue)
            stop = k < length(hdrs) ? hdrs[k+1] - 1 : (prov === nothing ? length(lines) : prov - 1)
            body = lines[i+2:stop]
            status = mm[2]
            if status == "stable"
                nstable += 1
                any(l -> startswith(l, "test:"), body) || err("$id (stable) has no 'test:' line")
                any(l -> startswith(l, "**Statement"), body) || err("$id (stable) has no Statement")
                any(l -> startswith(l, "**Example"), body) || err("$id (stable) has no Example")
            end
            for l in body
                startswith(l, "names:") || continue
                ns = [x.match for x in eachmatch(r"`[^`]+`", l)]
                isempty(ns) && err("$id: empty 'names:' line")
                for n in ns
                    startswith(n, "`" * OWNER[f] * ".") || err("$id: name $n is not qualified with $(OWNER[f])")
                end
            end
            push!(ids, id)
            println("  ", rpad(id, 7), " since=", mm[1], " status=", status, "  ", m[2])
        end
        length(unique(ids)) == length(ids) || err("duplicate IDs: $ids")
        expected = [string(pre, "-", lpad(n, 3, '0')) for n in 1:length(ids)]
        ids == expected || err("IDs not sequential from 001: $ids")
        println("  -> $(length(ids)) entries, $nstable stable, IDs unique+sequential: ",
                length(unique(ids)) == length(ids) && ids == expected)
    end
    # every julia block must parse; "(Base only)" blocks are also executed and checked
    for (ln, prev, code) in blocks
        global total_blocks += 1
        ex = try
            Meta.parseall(code)
        catch e
            err("$f:$ln julia block fails to parse: $(sprint(showerror, e))"); continue
        end
        bad = findfirst(a -> a isa Expr && a.head in (:error, :incomplete), ex.args)
        bad === nothing || (err("$f:$ln julia block has a parse error: $(ex.args[bad])"); continue)
        if occursin("(Base only)", prev)
            global nexpect += run_base_only(f, ln, code)
            global ran += 1
        end
    end
end
println("julia ", VERSION, ": ", total_blocks, " julia blocks parsed, ", ran, " Base-only blocks executed, ",
        nexpect, " value expectations checked, ", nerr[], " error(s)")
exit(nerr[] == 0 ? 0 : 1)
