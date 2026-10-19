# Negative tests for check.jl: it must pass on the real contracts and fail on each broken copy.
# Usage: julia --startup-file=no contracts/test_check.jl   (uses the running Julia for check.jl)
const HERE = @__DIR__
const ADRS = joinpath(HERE, "..", "adr")

function runcheck(mutate!)
    root = mktempdir()
    cdir = joinpath(root, "contracts"); mkpath(cdir)
    for f in ("README.md", "chui-core.md", "chui-types.md", "chui-frames.md")
        cp(joinpath(HERE, f), joinpath(cdir, f))
    end
    cp(ADRS, joinpath(root, "adr"))
    mutate!(cdir)
    out = IOBuffer()
    p = run(pipeline(ignorestatus(`$(Base.julia_cmd()) --startup-file=no $(joinpath(HERE, "check.jl")) $cdir`);
                     stdout = out, stderr = out))
    p.exitcode, String(take!(out))
end

edit(f, from, to) = cdir -> begin
    path = joinpath(cdir, f); s = read(path, String)
    occursin(from, s) || error("fixture text not found in $f: $from")
    write(path, replace(s, from => to; count = 1))
end

# Set ADR-0009 (one of check.jl's BINDING_ADRS) back to Proposed in the copied adr/ directory.
function unaccept_adr0009!(cdir)
    adir = joinpath(cdir, "..", "adr")
    f = only(filter(n -> startswith(n, "0009-"), readdir(adir)))
    edit(f, r"^- \*\*Status:\*\* .*$"m, "- **Status:** Proposed")(adir)
end

cases = [
    ("unmodified contracts pass", identity, 0, "0 error(s)"),
    ("a wrong `# ->` value fails", edit("chui-types.md", "reserved)   # -> true", "reserved)   # -> false"),
     1, "expected `# -> false` but got `true`"),
    ("a wrong tuple value fails", edit("chui-core.md", "# -> (0.0, 1.0)", "# -> (1.0, 1.0)"),
     1, "expected `# -> (1.0, 1.0)` but got `(0.0, 1.0)`"),
    ("dropping one of several expectations in a block still passes",
     edit("chui-frames.md", "(Base.isexported(Base, :mutate), Base.isexported(Base, :c))       # -> (false, false)",
          "(Base.isexported(Base, :mutate), Base.isexported(Base, :c))"),
     0, ""),   # still has other expectations in that block: must pass
    ("a Base-only block with no expectation at all fails",
     edit("chui-types.md", "reserved)   # -> true", "reserved)"), 1, "has no `# -> <value>` expectation"),
    ("a missing DRAFT banner fails while an ADR is Proposed", unaccept_adr0009!, 1, "has no DRAFT banner"),
    ("a leftover DRAFT banner fails once the ADRs are Accepted",
     edit("chui-frames.md", "> **Binding since 2026-10-19**", "> **DRAFT: not binding.**"),
     1, "still has the DRAFT banner"),
    ("an unqualified names: entry fails", edit("chui-core.md", "names: `ChuiCore.iscommutative`", "names: `iscommutative`"),
     1, "is not qualified with ChuiCore"),
]

nfail = 0
for (name, m!, want_code, want_text) in cases
    code, out = runcheck(m!)
    ok = code == want_code && occursin(want_text, out)
    global nfail += !ok
    println(ok ? "PASS  " : "FAIL  ", name, "  (exit ", code, ")")
    ok || println(out)
end
println("julia ", VERSION, ": ", length(cases) - nfail, "/", length(cases), " check.jl self-tests passed")
exit(nfail == 0 ? 0 : 1)
