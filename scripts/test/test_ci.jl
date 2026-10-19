"""
    reachability(root, profile) -> Vector{String} of problems

`template`/`package`: every ci.jl job is called by some workflow. A narrower profile (the
coordinator keeps only Guards.yml): every workflow `.factory-version` recorded is present and
calls ci.jl, and some workflow calls `guards`.
"""
function reachability(root, profile)
    wf = joinpath(root, ".github/workflows")
    used = Set{String}()
    for f in (isdir(wf) ? readdir(wf) : String[]), m in eachmatch(r"scripts/ci\.jl ([a-z]+)", read(joinpath(wf, f), String))
        push!(used, m.captures[1])
    end
    problems = String[]
    if profile in ("template", "package")
        for j in sort!(collect(setdiff(keys(CI.JOBS), used)))
            push!(problems, "job $j is never called by a workflow")
        end
    else
        given = sort!([k for k in keys(get(CI.factory_record(root), "managed", Dict())) if startswith(k, ".github/workflows/")])
        isempty(given) && push!(problems, ".factory-version records no workflows")
        for k in given
            p = joinpath(root, k)
            if !isfile(p)
                push!(problems, "workflow $k from the factory is missing")
            elseif !(basename(k) in ("CompatHelper.yml", "TagBot.yml")) && !occursin(r"scripts/ci\.jl [a-z]+", read(p, String))
                push!(problems, "workflow $k calls no ci.jl job")
            end
        end
        "guards" in used || push!(problems, "no workflow calls the guards job")
    end
    return problems
end

"""
The profile a vendored checkout was synced with. Without a `.factory-version` (never synced, or
the record not committed), a checkout holding the factory (`factory/MANIFEST.toml`) is the
coordinator, else a package; 0.2.0 always fell back to `package` and so reported every
package job as never called in a coordinator checkout.
"""
checkout_profile(root) = get(CI.factory_record(root), "profile",
                             isfile(joinpath(root, "factory", "MANIFEST.toml")) ? "coordinator" : "package")

@testset "ci.jl" begin
    wf = joinpath(ROOT, ".github/workflows")
    used = Set{String}()
    for f in readdir(wf), m in eachmatch(r"scripts/ci\.jl ([a-z]+)", read(joinpath(wf, f), String))
        push!(used, m.captures[1])
        @test haskey(CI.JOBS, m.captures[1]) || (println("$f calls unknown job $(m.captures[1])"); false)
    end
    # every job reachable from CI (template, package); a narrower profile checks what it was given
    probs = reachability(ROOT, IN_FACTORY ? "template" : checkout_profile(ROOT))
    @test isempty(probs) || (foreach(println, probs); false)
    @testset "reachability is profile-aware" begin
        n = mktempdir()                               # never synced: profile from the checkout's shape
        @test checkout_profile(n) == "package"
        mkpath(joinpath(n, "factory")); write(joinpath(n, "factory/MANIFEST.toml"), "version = 1\n")
        @test checkout_profile(n) == "coordinator"
        @test reachability(n, checkout_profile(n)) == [".factory-version records no workflows", "no workflow calls the guards job"]
        c = mktempdir()                               # a coordinator checkout: only Guards.yml
        mkpath(joinpath(c, ".github/workflows"))
        cp(joinpath(wf, "Guards.yml"), joinpath(c, ".github/workflows/Guards.yml"))
        write(joinpath(c, ".factory-version"), "profile = \"coordinator\"\n[managed]\n\".github/workflows/Guards.yml\" = \"x\"\n")
        @test isempty(reachability(c, "coordinator"))
        @test !isempty(reachability(c, "package"))   # the package profile still demands every job
        write(joinpath(c, ".factory-version"), "profile = \"coordinator\"\n[managed]\n\".github/workflows/Guards.yml\" = \"x\"\n\".github/workflows/CI.yml\" = \"x\"\n")
        @test any(contains("CI.yml"), reachability(c, "coordinator"))   # a given workflow went missing
        rm(joinpath(c, ".github/workflows/Guards.yml"))
        @test any(contains("guards"), reachability(c, "coordinator"))
    end
    # no workflow runs Julia code except through ci.jl (CompatHelper/TagBot are external tools)
    for f in readdir(wf)
        f in ("CompatHelper.yml", "TagBot.yml") && continue
        for l in eachline(joinpath(wf, f))
            m = match(r"^\s*(?:-\s*)?run:\s*(.*)$", l)
            m === nothing || m.captures[1] == "|" || @test occursin("scripts/ci.jl", m.captures[1])
        end
    end
    rc, out = capture(() -> CI.run_job("guards", ROOT, String[]; dry = true))
    @test rc == 0 && occursin("scripts/gen.jl --check", out)
    rc, out = capture(() -> CI.run_job("contracts", ROOT, String[]))
    @test rc == 0 && occursin("skipped: no upstreams", out)
    rc, out = capture(() -> CI.run_job("test", ROOT, ["laws"]; dry = true))
    @test occursin("-- laws", out)
    @test capture(() -> CI.run_job("nope", ROOT, String[]))[1] == 2

    @testset "test job really runs Pkg.test on a package" begin
        d = mktempdir()
        write(joinpath(d, "Project.toml"), """
            name = "FactoryProbe"
            uuid = "4b3a7c1e-0d5e-4c55-9a0b-2b6f0f1e9a11"
            version = "0.1.0"
            [extras]
            Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
            [targets]
            test = ["Test"]
            """)
        mkpath(joinpath(d, "src")); write(joinpath(d, "src/FactoryProbe.jl"), "module FactoryProbe\nf() = 1\nend\n")
        mkpath(joinpath(d, "test"))
        write(joinpath(d, "test/runtests.jl"), "using Test, FactoryProbe\n@test FactoryProbe.f() == 1\n@test ARGS == [\"unit\"]\n")
        rc, out = capture(() -> CI.run_job("test", d, ["unit"]))
        @test rc == 0 || (print(out); false)
    end

    @testset "docs, jet and contracts leave tracked files byte-identical (0.2.2)" begin
        # 0.2.1 ran Pkg.develop in docs/ and test/jet/ in place: Julia >= 1.11 wrote an absolute
        # [sources] path into the tracked Project.toml, added the package to [deps], dropped comments.
        uuid = "7d2c1f0e-3b4a-4e5f-8a9b-0c1d2e3f4a5b"
        tomlv = "TOML = \"fa267f1f-6049-4f14-aa54-33bafae1ed76\""
        d = tmp_repo(Dict(
            "Project.toml" => "name = \"FactoryEnvProbe\"\nuuid = \"$uuid\"\nversion = \"0.1.0\"\n",
            "src/FactoryEnvProbe.jl" => "module FactoryEnvProbe\nf() = 1\nend\n",
            ".gitignore" => "/Manifest*.toml\n/docs/Manifest*.toml\n/test/jet/Manifest*.toml\n/test/contracts/Manifest*.toml\n",
            # a relative [sources] path (Julia >= 1.11) must still resolve from the scratch copy
            "docs/Project.toml" => "# docs env: this comment must survive\n[deps]\nFactoryEnvProbe = \"$uuid\"\n$tomlv\n\n[sources]\nFactoryEnvProbe = {path = \"..\"}\n\n[compat]\nTOML = \"1\"\n",
            "docs/make.jl" => "using TOML, FactoryEnvProbe\nFactoryEnvProbe.f() == 1 || error(\"probe\")\n",
            "test/jet/Project.toml" => "# jet env: this comment must survive\n[deps]\n$tomlv\n\n[compat]\nTOML = \"1\"\n",
            "test/jet/runjet.jl" => "using TOML\nconst N = Symbol(TOML.parsefile(joinpath(@__DIR__, \"..\", \"..\", \"Project.toml\"))[\"name\"])\n@eval using \$N\n",
            "test/contracts/Project.toml" => "# contracts env\n[deps]\nTest = \"8dfed614-e22c-5e08-85e1-65c5234f0b40\"\n\n[compat]\nTest = \"1\"\n",
            "test/contracts/upstreams.toml" => "[upstreams]\nUp = \"https://example.invalid/Up.jl\"\n",
            "test/contracts/runtests.jl" => "using Test\n@test Base.active_project() != abspath(\"test/contracts/Project.toml\")\n",
        ))
        files = filter(f -> isfile(joinpath(d, f)), CI.tracked_files(d))
        before = Dict(f => read(joinpath(d, f)) for f in files)
        td = mktempdir()                                                # tempname() reads TMPDIR per call
        withenv("JULIA_PKG_OFFLINE" => "true", "JULIA_PKG_PRECOMPILE_AUTO" => "0", "TMPDIR" => td) do
            for job in ("docs", "jet", "contracts")
                rc, out = capture(() -> CI.run_job(job, d, String[]))
                @test (rc == 0 && occursin("ci.jl $job: OK", out)) || (print(out); false)
            end
            @test all(f -> read(joinpath(d, f)) == before[f], files)
            @test isempty(read(`git -C $d status --porcelain`, String))
            @test isempty(CI.SCRATCH)
            @test !any(e -> isfile(joinpath(td, e, "Project.toml")), readdir(td))   # scratch envs deleted
            write(joinpath(d, "test/contracts/runtests.jl"), "using Test\n@test 1 == 2\n")
            @test capture(() -> CI.run_job("contracts", d, String[]))[1] == 1  # a failing contract test fails the job
        end
        rc, out = capture(() -> CI.run_job("contracts", d, ["main"]; dry = true))     # no --in-place gate now
        @test rc == 0 && occursin("test/contracts", out) && occursin(" main", out) && !occursin("--project=.", out)
        rm(joinpath(d, "test/contracts/Project.toml"))
        rc, out = capture(() -> CI.run_job("contracts", d, String[]))
        @test rc == 0 && occursin("skipped: no test/contracts/Project.toml", out)
    end

    if IN_FACTORY
        @testset "seeded environments: compat on everything, Manifests ignored (0.2.2)" begin
            ign = readlines(joinpath(ROOT, ".gitignore"))
            envs = String[]
            for (r, _, fs) in walkdir(ROOT), f in fs
                f == "Project.toml" && push!(envs, relpath(r, ROOT))
            end
            @test issubset(["test/jet", "test/contracts"], envs)
            for e in envs                                                  # ADR-0004 rule 3
                p = TOML.parsefile(joinpath(ROOT, e, "Project.toml"))
                c = get(p, "compat", Dict())
                @test haskey(c, "julia") || (println("$e: no julia compat"); false)
                for dep in keys(get(p, "deps", Dict()))
                    @test haskey(c, dep) || (println("$e: no compat for $dep"); false)
                end
                @test "/$e/Manifest*.toml" in ign || (println(".gitignore misses /$e/Manifest*.toml"); false)
            end
            @test "/docs/Manifest*.toml" in ign
        end
    end
end
