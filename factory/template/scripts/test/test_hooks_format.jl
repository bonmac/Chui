# format_check.sh (0.4.0, D10): the advisory PostToolUse(Edit|Write) Runic check. Included from
# test_hooks.jl (uses its helpers hook, write_payload, TEST_HOOKS). A stub `runic` on a temp PATH
# dir records every call and exits as told; the real PATH is replaced, so a runic installed on the
# machine never takes part. Fails open by design: a bad payload, a missing runic, a non-.jl file
# and a missing path all exit 0 and run nothing.
@testset "hooks: format_check (advisory runic)" begin
    root = realpath(mktempdir())
    write(joinpath(root, "a.jl"), "f(x)=x\n")
    write(joinpath(root, "a.md"), "# x\n")
    base_path = join(unique([dirname(Sys.which("jq")), dirname(Sys.which("sh")), "/usr/bin", "/bin"]), ":")
    # stub_runic(code, lines): a PATH with a `runic` that appends its argv to `calls`, prints `lines` and exits `code`
    function stub_runic(code; lines = String[])
        d = realpath(mktempdir())
        calls = joinpath(d, "calls.txt")
        body = "#!/bin/sh\nprintf '%s\\n' \"\$*\" >>\"$calls\"\n" *
            join(("printf '%s\\n' '" * l * "'\n" for l in lines)) * "exit $code\n"
        write(joinpath(d, "runic"), body)
        chmod(joinpath(d, "runic"), 0o755)
        return Dict("PATH" => d * ":" * base_path), calls
    end
    calls_of(f) = isfile(f) ? readlines(f) : String[]

    @testset "unformatted .jl: exit 2, the file named, runic's tail quoted" begin
        env, calls = stub_runic(1; lines = ["--- a.jl", "+++ a.jl", "-f(x)=x", "+f(x) = x"])
        code, out, err = hook("format_check.sh", write_payload(joinpath(root, "a.jl")), root; env)
        @test code == 2
        @test startswith(err, "[factory] a.jl is not Runic-formatted")
        @test occursin("+f(x) = x", err)
        @test calls_of(calls) == ["--check $(joinpath(root, "a.jl"))"]
    end

    @testset "runic's tail is at most 20 lines" begin
        env, _ = stub_runic(1; lines = ["line $i" for i in 1:30])
        code, _, err = hook("format_check.sh", write_payload(joinpath(root, "a.jl")), root; env)
        @test code == 2
        @test !occursin("line 10\n", err) && occursin("line 11\n", err) && occursin("line 30\n", err)
    end

    @testset "formatted .jl: exit 0, silent" begin
        env, calls = stub_runic(0)
        code, out, err = hook("format_check.sh", write_payload(joinpath(root, "a.jl")), root; env)
        @test (code, out, err) == (0, "", "")
        @test length(calls_of(calls)) == 1
    end

    @testset "runic crashes (rc other than 1): exit 0, said, formatting not claimed (review M1)" begin
        for rc in (139, 127, 2)
            env, calls = stub_runic(rc; lines = ["boom"])
            code, out, err = hook("format_check.sh", write_payload(joinpath(root, "a.jl")), root; env)
            @test code == 0 || (println("rc $rc: hook exit $code"); false)
            @test out == ""
            @test startswith(err, "[factory] runic --check failed (rc $rc); formatting not checked")
            @test !occursin("not Runic-formatted", err)
            @test length(calls_of(calls)) == 1
        end
    end

    @testset "no runic on PATH: exit 0, nothing run" begin
        _, calls = stub_runic(1)                              # the stub exists but its dir is NOT on PATH
        code, out, err = hook("format_check.sh", write_payload(joinpath(root, "a.jl")), root; env = Dict("PATH" => base_path))
        @test (code, out, err) == (0, "", "")
        @test isempty(calls_of(calls))
    end

    @testset "fails open: other file types, no path, not JSON, a missing file" begin
        env, calls = stub_runic(1; lines = ["diff"])
        @test hook("format_check.sh", write_payload(joinpath(root, "a.md")), root; env) == (0, "", "")
        @test hook("format_check.sh", "{\"session_id\":\"s1\",\"tool_input\":{\"content\":\"x\"}}", root; env) == (0, "", "")
        @test hook("format_check.sh", "not json {", root; env) == (0, "", "")
        @test hook("format_check.sh", "", root; env) == (0, "", "")
        @test hook("format_check.sh", write_payload(joinpath(root, "missing.jl")), root; env) == (0, "", "")
        @test isempty(calls_of(calls))
    end

    @testset "the `path` key is honoured; a file outside the root keeps its full path" begin
        env, calls = stub_runic(1; lines = ["diff"])
        code, _, err = hook("format_check.sh", write_payload(joinpath(root, "a.jl"); key = "path"), root; env)
        @test code == 2 && startswith(err, "[factory] a.jl is not Runic-formatted")
        other = realpath(mktempdir())
        write(joinpath(other, "b.jl"), "g(x)=x\n")
        code, _, err = hook("format_check.sh", write_payload(joinpath(other, "b.jl")), root; env)
        @test code == 2 && startswith(err, "[factory] $(joinpath(other, "b.jl")) is not Runic-formatted")
        @test length(calls_of(calls)) == 2
    end
end
