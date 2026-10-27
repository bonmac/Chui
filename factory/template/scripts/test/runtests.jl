# Factory tests: every script and hook in scripts/ and .claude/hooks/ has tests here.
#   julia scripts/test/runtests.jl [NAME...] [--hooks-dir DIR]   (also run by `julia scripts/ci.jl guards`)
# NAME selects test files (`hooks` = test_hooks*.jl, `gen`, `lane`, `tdd`, ...; none = all), in file order;
# some files use helpers an earlier one defines (`sync_factory` needs `hooks`), so name those too. --hooks-dir
# runs the hook tests against a COPY of the hooks (0.4.0, D3: the critic's gate audit mutates
# .lanes/scratch/critic/hooks and looks for a test that goes red), not .claude/hooks.
# Stdlib only. Hooks are run as real `sh` processes with JSON on stdin. Needs git and jq.
using Test, TOML   # TOML here, so a selection that skips test_gen.jl still has it

const SCRIPTS = normpath(joinpath(@__DIR__, ".."))
const ROOT = normpath(joinpath(SCRIPTS, ".."))
const TEST_FILES = [
    "test_gen.jl", "test_hooks.jl", "test_hooks_lifecycle.jl", "test_bash_guard.jl", "test_dod.jl", "test_ratchet.jl",
    "test_check_docs.jl", "test_contract_usage.jl", "test_ci.jl", "test_lane.jl", "test_lane_040.jl", "test_changelog.jl", "test_check_claims.jl",
    "test_evidence.jl", "test_sync_factory.jl", "test_runtests_template.jl", "test_tdd.jl", "test_tdd_backfill.jl",
    "test_tdd_classify2.jl", "test_tdd_review.jl",
]
"Parse the command line: (selected names, hooks dir or \"\"). An unknown option is an error, never ignored."
function runtests_args(argv)
    names, hooks = String[], ""
    i = 1
    while i <= length(argv)
        a = argv[i]
        if a == "--hooks-dir" && i < length(argv)
            hooks = abspath(argv[i += 1])
        elseif startswith(a, "--hooks-dir=")
            hooks = abspath(a[length("--hooks-dir=") + 1:end])
        elseif startswith(a, "-")
            error("usage: runtests.jl [NAME...] [--hooks-dir DIR]; unknown option `$a`")
        else
            push!(names, a)
        end
        i += 1
    end
    return names, hooks
end
"The test files NAME... select: test_<name>.jl and test_<name>_*.jl; none selects every file."
function selected_files(names)
    isempty(names) && return TEST_FILES
    files = String[]
    for n in names
        hit = filter(f -> f == "test_$n.jl" || startswith(f, "test_$(n)_"), TEST_FILES)
        isempty(hit) && error("runtests.jl: no test file for `$n` (names: $(join(replace.(TEST_FILES, r"^test_|\.jl$" => ""), ", ")))")
        append!(files, hit)
    end
    return files
end
const SELECTED, HOOKS_DIR = runtests_args(ARGS)
const HOOKS = isempty(HOOKS_DIR) ? joinpath(ROOT, ".claude", "hooks") : HOOKS_DIR
const FACTORY = normpath(joinpath(ROOT, ".."))           # set when run inside factory/template
const IN_FACTORY = isfile(joinpath(FACTORY, "MANIFEST.toml")) && isfile(joinpath(FACTORY, "VERSION"))
const JULIA = [Base.julia_cmd().exec; "--startup-file=no"]

for f in (
        "gen.jl", "dod.jl", "ratchet.jl", "check_docs.jl", "ci.jl", "lane.jl", "sync_factory.jl", "bench.jl", "contract_usage.jl",
        "changelog.jl", "check_claims.jl", "evidence.jl",
    )
    include(joinpath(SCRIPTS, f))
end

sh(cmd) = run(pipeline(cmd; stdout = devnull, stderr = devnull))
"A fresh git repo with one commit on `main`; `files` maps relative path => content."
function tmp_repo(files = Dict{String, String}())
    d = realpath(mktempdir())
    sh(`git -C $d init -q -b main`)
    sh(`git -C $d config user.email t@example.com`)
    sh(`git -C $d config user.name test`)
    sh(`git -C $d config commit.gpgsign false`)
    isempty(files) && (files = Dict("README.md" => "x\n"))
    for (rel, c) in files
        mkpath(dirname(joinpath(d, rel)))
        write(joinpath(d, rel), c)
    end
    sh(`git -C $d add -- .`)
    sh(`git -C $d commit -q -m init`)
    return d
end
function commit!(d, files::Dict, msg = "change")
    for (rel, c) in files
        mkpath(dirname(joinpath(d, rel)))
        write(joinpath(d, rel), c)
    end
    sh(`git -C $d add -- .`)
    return sh(`git -C $d commit -q -m $msg`)
end
"Run f with stdout captured; returns (result, output)."
function capture(f)
    p = tempname()
    r = open(p, "w") do io
        redirect_stdout(f, io)
    end
    return r, read(p, String)
end

@testset "factory" begin
    t0 = time()
    isempty(HOOKS_DIR) || println("hooks under test: $HOOKS")
    for f in selected_files(SELECTED)
        include(f)
    end
    println("factory tests finished in $(round(time() - t0; digits = 1)) s")
end
