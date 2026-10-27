# Factory 0.4.0 read-only agents (plan Task 3, spec D3, ADR-0016): when the hook payload's
# `agent_type` is in READ_ONLY_AGENTS (limits.env, rendered by gen.jl from default_mode = "read_only"),
# bash_guard allows only the D3 allowlist and write_guard only .lanes/reports/** and
# .lanes/scratch/<agent_type>/**. Included from test_hooks.jl (helpers hook, bash, json, blocked,
# write_payload, TEST_HOOKS, hooks_with_roots); split out for the 400-line budget of ratchets.toml.
bash_as(agent, cmd; cwd = "") = "{\"session_id\":\"s1\",\"agent_type\":\"$(json(agent))\",\"cwd\":\"$(json(cwd))\",\"tool_input\":{\"command\":\"$(json(cmd))\"}}"
write_as(agent, path) = "{\"session_id\":\"s1\",\"agent_type\":\"$(json(agent))\",\"tool_input\":{\"file_path\":\"$(json(path))\"}}"

@testset "read-only agents (0.4.0)" begin
    r = realpath(mktempdir())
    env = read(joinpath(TEST_HOOKS, "limits.env"), String)
    @test occursin(r"^READ_ONLY_AGENTS=\" .* \"$"m, env)      # gen.jl renders the list, space-delimited

    @testset "the plan's Task 3 contract" begin
        @test blocked("bash_guard.sh", bash_as("reviewer", "sed -i s/a/b/ src/x.jl"), r)
        @test blocked("bash_guard.sh", bash_as("reviewer", "git commit -m x"), r)
        @test blocked("bash_guard.sh", bash_as("reviewer", "echo x | tee .lanes/reports/reviewer.md"), r)
        @test blocked("bash_guard.sh", bash_as("critic", "julia -e 'write(\"a\",\"b\")'"), r)
        @test !blocked("bash_guard.sh", bash_as("reviewer", "git diff \$(git merge-base HEAD main)"), r)
        @test !blocked("bash_guard.sh", bash_as("reviewer", "julia scripts/ci.jl test --timeout 900"), r)
        @test !blocked("write_guard.sh", write_as("reviewer", "$r/.lanes/reports/reviewer-f040.md"), r)
        @test !blocked("write_guard.sh", write_as("critic", "$r/.lanes/scratch/critic/hooks/bash_guard.sh"), r)
        @test blocked("write_guard.sh", write_as("reviewer", "$r/src/x.jl"), r)
        @test !blocked("bash_guard.sh", bash_as("", "sed -i s/a/b/ src/x.jl"), r)  # the lead is unchanged
        # critic round 1 (B1, B2): each of these is blocked for a read-only agent
        for c in [
                "julia scripts/evidence.jl x -- sed -i s/a/b/ src/x.jl", "julia scripts/tdd.jl mutate --root /x --item i --src a:1 --from a --to b",
                "julia scripts/ci.jl test --root /x", "cat a > src/x.jl", "find . -name x -delete", "git -c core.fsmonitor='touch p' status",
                "git log --output=f", "rg --pre cat x", "git branch -f main HEAD~3", "git worktree remove .worktrees/f040", "cp a src/b",
            ]
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        @test !blocked("bash_guard.sh", bash_as("critic", "cp -R .claude/hooks .lanes/scratch/critic/hooks"), r)
        @test !blocked("bash_guard.sh", bash_as("critic", "julia scripts/test/runtests.jl hooks --hooks-dir .lanes/scratch/critic/hooks"), r)
    end

    @testset "allowed: the read-only commands, the gate scripts, the scratch" begin
        for c in (
                "cat src/x.jl", "head -n 20 f", "grep -rn foo src", "rg foo", "ls -la .lanes", "wc -l f", "find . -name '*.jl'",
                "cd .worktrees/f040 && git status", "pwd", "git log --oneline -5", "git show HEAD --stat", "git blame src/x.jl",
                "git ls-files", "git merge-base HEAD main", "git rev-parse --short HEAD", "git branch --show-current",
                "git branch --list", "git branch --list 'feat/*'", "git worktree list", "git worktree list --porcelain",
                "git -C .worktrees/f040 diff --stat", "git --no-pager log -1", "julia scripts/dod.jl --base main",
                "julia --startup-file=no scripts/ci.jl guards --timeout 900", "julia +lts scripts/ci.jl test",
                "julia scripts/ci.jl quality", "julia scripts/ci.jl docs", "scripts/lane audit f040 --reported r.txt",
                "./scripts/lane audit f040", "julia scripts/lane.jl audit f040", "julia scripts/evidence.jl latest test",
                "julia scripts/test/runtests.jl", "julia scripts/test/runtests.jl gen hooks", "mkdir -p .lanes/scratch/reviewer/x",
                "cp f .lanes/scratch/reviewer/", "cp -R .claude/hooks .lanes/scratch/reviewer/hooks",
                "git diff 2>&1 | head -50", "echo done", "diff a b", "jq -r .x f.json", "sort f | uniq -c",
                # D8: evidence.jl may wrap a command that is itself allowed (the verifier records a gate run)
                "julia scripts/evidence.jl test -- julia scripts/ci.jl test --timeout 900",
                "timeout 900 julia scripts/ci.jl test", "time julia scripts/dod.jl",
            )
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
    end

    @testset "denied: writes, other tools, options that run or write" begin
        for c in (
                "touch x", "rm f", "mv a b", "mkdir src/new", "cp f src/", "cp -t src f", "tee f", "sed -i.bak s/a/b/ f",
                "perl -pi -e s/a/b/ f", "sh -c 'echo x'", "bash x.sh", "python3 -c 'print(1)'", "julia -E '1+1'",
                "julia -L x.jl scripts/ci.jl test", "julia .lanes/scratch/reviewer/x.jl", "julia /abs/scripts/ci.jl test",
                "julia scripts/ci.jl bench", "julia scripts/ci.jl", "julia scripts/tdd.jl gaps", "julia scripts/lane.jl new x",
                "scripts/lane new x", "scripts/lane remove f040", "julia scripts/evidence.jl", "julia scripts/evidence.jl x",
                "julia scripts/evidence.jl x -- julia scripts/ci.jl bench", "julia scripts/gen.jl", "julia scripts/dod.jl --root /x",
                "julia scripts/test/runtests.jl --root /x", "cat f > out", "cat f >> out", "cat f 2> err", "cat f 2>/dev/null",
                "echo x > /dev/null", "git diff > d.patch", "find . -exec rm {} \\;", "find . -execdir cat {} +", "find . -ok rm {} \\;",
                "find . -fprint f", "find . -fprint0 f", "find . -fls f", "git -c x=y log", "git -cx=y log", "git --config-env=x=Y log",
                "git --exec-path=.lanes/scratch/reviewer log", "git --git-dir=/x log", "git diff --output=f", "git status --output f",
                "git branch", "git branch x", "git branch -d x", "git branch --list -D x", "git worktree add x", "git worktree",
                "git add f", "git checkout x", "git restore f", "git stash list", "git push", "git fetch", "git config x y",
                "git log -c", "GIT_PAGER='touch p' git log", "GIT_EXTERNAL_DIFF=cmd git diff", "FOO=1 cat f", "env FOO=1 cat f",
                "sudo cat f", "xargs rm", "nohup cat f", "exec cat f", "eval cat", "rg --pre=cat x", "sort -o f f", "sort --output=f f",
                "mkdir .lanes/scratch/critic/x", "cp f .lanes/scratch/critic/", "mkdir .lanes/scratch", "mkdir .lanes/scratch/reviewer/../x",
                "cp f .lanes/reports/r.md", "mkdir /tmp/x", "ls && touch x", "cat f | tee g", "`touch x`", "cat \$(touch x)",
                "/usr/bin/git log", ".lanes/scratch/reviewer/git log", "./cat f", "timeout -s KILL 5 cat f", "less f && touch g",
                "git -C .lanes/scratch/reviewer --exec-path=. log",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        # the denial names the allowlist and the agent type, and says where reports go
        rc, _, err = hook("bash_guard.sh", bash_as("critic", "touch x"), r)
        @test rc == 2 && occursin("'critic'", err) && occursin("scripts/dod.jl", err) && occursin(".lanes/reports/", err) &&
            occursin("merge-base", err) && occursin(".lanes/scratch/critic/", err)
        # the scratch is the agent's own; another agent's scratch is a write like any other
        @test !blocked("bash_guard.sh", bash_as("critic", "mkdir -p .lanes/scratch/critic/x"), r)
        # a write agent, and an unknown agent type, keep the lead's rules (writes modelled, T3 checked)
        for a in ("implementer", "nobody", "verifier-2")
            @test !blocked("bash_guard.sh", bash_as(a, "sed -i s/a/b/ src/x.jl"), r)
            @test blocked("bash_guard.sh", bash_as(a, "git reset --hard"), r)
        end
        # the lead's rules still apply underneath: a denylisted command is denied with its own message
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "git reset --hard"), r)
        @test rc == 2 && occursin("discards work", err)
    end

    @testset "write_guard: reports and the agent's scratch only" begin
        @test !blocked("write_guard.sh", write_as("critic", "$r/.lanes/reports/critic-2.md"), r)
        @test !blocked("write_guard.sh", write_as("reviewer", "$r/.lanes/scratch/reviewer/notes.md"), r)
        for p in (
                "$r/.lanes/scratch/critic/x", "$r/.lanes/scratch/reviewer", "$r/.lanes/scratch", "$r/.lanes/reports",
                "$r/.lanes/ledger.jsonl", "$r/.lanes/evidence/test-abc.txt", "$r/README.md", "$r/.lanes/scratch/reviewer/../../x",
                "/tmp/scratch.md", "$r/.lanes/reportsx/a.md",
            )
            @test blocked("write_guard.sh", write_as("reviewer", p), r) || (println("not blocked for reviewer: $p"); false)
        end
        rc, _, err = hook("write_guard.sh", write_as("reviewer", "$r/src/x.jl"), r)
        @test rc == 2 && occursin("'reviewer'", err) && occursin(".lanes/reports/**", err) && occursin(".lanes/scratch/reviewer/**", err)
        @test !blocked("write_guard.sh", write_as("", "$r/src/x.jl"), r)
        @test !blocked("write_guard.sh", write_as("implementer", "$r/src/x.jl"), r)
        @test blocked("write_guard.sh", write_as("reviewer", "$r/.claude/hooks/bash_guard.sh"), r)   # T3 under the lead's rules too
        # a lane worktree root: the main checkout's .lanes/reports/ counts (0.2.6 in_main), its tree does not
        main = tmp_repo(Dict("a" => "x\n"))
        sh(`git -C $main worktree add -q $main/.worktrees/l1 -b l1`)
        lane = joinpath(main, ".worktrees", "l1")
        @test !blocked("write_guard.sh", write_as("reviewer", "$main/.lanes/reports/reviewer.md"), lane)
        @test !blocked("write_guard.sh", write_as("reviewer", "$lane/.lanes/reports/reviewer.md"), lane)
        @test blocked("write_guard.sh", write_as("reviewer", "$main/a"), lane)
        @test blocked("write_guard.sh", write_as("reviewer", "$main/.lanes/scratch/reviewer/x"), lane)   # the scratch is the session root's
    end

    @testset "review round 1: the scratch is never a cwd, a -C target or a script source; julia options; uniq" begin
        sc = "$r/.lanes/scratch/reviewer"
        for d in ("$sc/scripts", "$sc/p", "$sc/bare", "$r/.lanes/reports", "$r/factory/template/scripts"); mkpath(d); end
        write("$sc/scripts/dod.jl", "println(\"scratch\")\n")                 # a dod.jl the agent wrote itself
        # B1: a second operand or an option that writes a file or runs a program
        for c in (
                "uniq README.md .claude/hooks/bash_guard.sh", "uniq -c a b", "file -C -m magic", "file -bC x", "file --compile x",
                "sort --compress-program=touch f", "sort --compress-program touch f", "less -o f x", "less -of x", "less -O f x",
                "less --log-file=f x", "less --LOG-FILE=f x",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        for c in ("uniq f", "uniq -c f", "sort f | uniq", "file x", "less f", "sort -r f")
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        # B2 (+ m2): a script is the repo's own scripts/<name> resolved against the tracked cwd (payload cwd, then each `cd`);
        # no segment runs with a cwd below .lanes/ or outside a trusted checkout; evidence.jl never wraps a cd
        for (c, cwd) in [
                ("cd .lanes/scratch/reviewer && julia scripts/dod.jl", ""), ("julia scripts/dod.jl", sc), ("ls", sc),
                ("cd .lanes/scratch/reviewer && ls", ""), ("cd .lanes/reports && git status", ""), ("cd .lanes && ls", ""),
                ("cd .worktrees/f040/.lanes/scratch/reviewer && ls", ""), ("cd /tmp && julia scripts/dod.jl", ""), ("cd /tmp && ls", ""),
                ("cd \$D && ls", ""), ("cd - && ls", ""), ("julia ../scripts/dod.jl", ""), ("julia scripts/dod.jl", "/tmp"),
                (".lanes/scratch/reviewer/scripts/lane audit x", ""), ("cd .lanes/scratch/reviewer && ../../../scripts/lane audit x", ""),
                ("julia scripts/gen.jl", ""), ("julia scripts/gen.jl --check --x", ""), ("julia scripts/gen.jl --apply", ""),
                ("julia scripts/evidence.jl x -- cd /tmp", ""), ("julia scripts/evidence.jl x -- time cd /tmp", ""),
                ("julia scripts/evidence.jl x -- pushd x", ""), ("julia .lanes/scratch/reviewer/scripts/dod.jl", ""),
            ]
            @test blocked("bash_guard.sh", bash_as("reviewer", c; cwd), r) || (println("not blocked for reviewer: $c (cwd $cwd)"); false)
        end
        for (c, cwd) in [
                ("cd factory/template && julia --startup-file=no scripts/gen.jl --check", ""),
                ("(cd $r/factory/template && julia --startup-file=no scripts/gen.jl --check)", ""),
                ("julia --startup-file=no scripts/gen.jl --check", "$r/factory/template"), ("julia $r/scripts/dod.jl", ""),
                ("cd .worktrees/f040 && julia scripts/dod.jl --base main", ""), ("cd .claude/worktrees/x && scripts/lane audit x", ""),
                ("cd src && julia ../scripts/dod.jl", ""), ("julia factory/template/scripts/ci.jl test", ""),
                ("cd factory/template && julia scripts/test/runtests.jl gen hooks", ""), ("./scripts/lane audit x", ""),
                ("cd .worktrees/f040 && git status", ""), ("cat .lanes/scratch/reviewer/notes.md", ""), ("ls .lanes/reports", ""),
                ("julia scripts/test/runtests.jl hooks --hooks-dir .lanes/scratch/reviewer/hooks", ""),
            ]
            @test !blocked("bash_guard.sh", bash_as("reviewer", c; cwd), r) || (println("blocked for reviewer: $c (cwd $cwd)"); false)
        end
        # B3: only --startup-file=no and a juliaup +channel before the script
        for c in (
                "julia --project=.lanes/scratch/reviewer/p scripts/ci.jl test", "julia --project scripts/ci.jl test", "julia --project=. scripts/dod.jl",
                "julia +lts --project=p scripts/ci.jl test", "julia -J x scripts/ci.jl test", "julia --sysimage=x scripts/ci.jl test",
                "julia --sysimage x scripts/ci.jl test", "julia --load x scripts/ci.jl test", "julia -t 4 scripts/ci.jl test",
                "julia --threads=4 scripts/ci.jl test", "julia --color=yes scripts/ci.jl test", "julia --startup-file=yes scripts/dod.jl",
                "julia --startup-file no scripts/dod.jl", "julia -- scripts/dod.jl",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        for c in ("julia --startup-file=no +lts scripts/ci.jl test", "julia +1.10 scripts/dod.jl", "julia +lts --startup-file=no scripts/evidence.jl latest")
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        # B4: git -C only into a trusted checkout (this root, its main checkout, a lane worktree of either), never below .lanes/
        for c in (
                "git -C .lanes/scratch/reviewer/bare status", "git -C .lanes/scratch/reviewer log", "git -C .lanes/reports status",
                "git -C .lanes status", "git -C /tmp log", "git -C .. log", "git -C \$D log", "git -C ~ log",
                "git -C .worktrees/f040 -C ../../.lanes/scratch/reviewer status", "git -C .worktrees/f040/.lanes/scratch/reviewer status",
                "git --no-pager -C .lanes/scratch/reviewer log", "git -C $r/.lanes/scratch/reviewer log",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        for c in ("git -C . status", "git -C src log", "git -C factory/template status", "git -C .claude/worktrees/x log", "git -C $r log",
                "git -C .worktrees/f040 -C .. status", "git -C .worktrees/f040 diff --stat")
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        # a session rooted in a lane worktree: the main checkout and its lanes are trusted too, their .lanes/ is not
        main = tmp_repo(Dict("a" => "x\n"))
        sh(`git -C $main worktree add -q $main/.worktrees/l1 -b l1`)
        lane = joinpath(main, ".worktrees", "l1")
        for (c, cwd) in [
                ("julia scripts/dod.jl", main), ("julia scripts/dod.jl", "$main/.worktrees/l2"), ("git -C $main status", ""),
                ("git -C ../.. log", ""), ("cd $main && julia scripts/ci.jl test", ""), ("git -C $main/.worktrees/l2 log", ""),
            ]
            @test !blocked("bash_guard.sh", bash_as("reviewer", c; cwd), lane) || (println("blocked for reviewer: $c (cwd $cwd)"); false)
        end
        for (c, cwd) in [
                ("julia scripts/dod.jl", "$main/.lanes/scratch/reviewer"), ("git -C $main/.lanes/scratch/reviewer/bare status", ""),
                ("git -C $main/.lanes/reports status", ""), ("cd $main/.lanes/scratch/reviewer && ls", ""), ("git -C $main/.. log", ""),
            ]
            @test blocked("bash_guard.sh", bash_as("reviewer", c; cwd), lane) || (println("not blocked for reviewer: $c (cwd $cwd)"); false)
        end
        # round 2 (N1-N3): sort, uniq, file and less take a fixed short-option set and no long option (abbreviated long options
        # and getopt clusters spelt -o in other ways); a lone - is an operand; uniq takes at most one operand including -
        for c in (
                "uniq - src/x.jl", "sort -ro src/x.jl g", "sort --out=src/x.jl g", "sort --outp=src/x.jl g", "file --comp -m x",
                "file --compil x", "sort --compress=x f", "less --log-f=f x", "less --LOG-F=f x", "sort -k2 -o x f", "sort -T src f",
                "sort -m f", "uniq -f 1 f", "uniq -c - f", "uniq --count f", "file -C x", "file -m x f", "less -k f x",
                "sort -nro x f",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        for c in (
                "sort -n f", "uniq -c f", "file -b f", "sort -nr f", "sort -k2 -t, f", "sort -k 2 f", "sort -t , -k 1,1 -n f", "uniq -",
                "uniq -c -", "cat f | sort -u", "uniq -ci f", "file -bi f", "file -h f", "less f", "sort -rn -k2 f", "sort -bfs f",
                "sort -k2,2n -k1 f", "sort -tk f", "sort -- f", "less -- f",   # round 3: `--` ends the options (what follows is an operand)
            )
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        # round 3 (R1): rg takes a fixed option set too (ripgrep 15.2 `--hostname-bin=PROG` runs PROG; rg rejects abbreviations,
        # so exact long-option matching is safe); `less +cmd` runs a less command
        for c in (
                "rg --hostname-bin=./x --hyperlink-format=default x", "rg --pre cat x", "rg --hostname-bin=x x", "rg --hostname-bin x x",
                "rg --pre=cat x", "rg --pre-glob '*' x", "rg -o x", "rg --color=always x", "rg --colour=never x", "rg --no-head x",
                "rg -z x", "rg --sort path x", "rg --type-add 'j:*.jl' x", "rg -nj x", "less +!x f", "less +G f", "less -n +F f",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        for c in (
                "rg -n x", "rg --no-heading -n x f", "rg -g '*.jl' x", "rg --glob '*.jl' x", "rg --glob='*.jl' x", "rg -t julia x",
                "rg -nC 3 x", "rg -e x -e y f", "rg --color=never x", "rg -A 2 -B 2 x", "rg --max-count 3 x", "rg -c x", "rg -l x src",
                "rg -iw x", "rg -F -- --no-verify .", "rg -- -x f", "rg --files", "rg --files-with-matches x", "rg -S x", "rg -Hn x f",
                "rg -N x", "rg -v x f", "rg --count --no-messages x", "rg --fixed-strings x", "rg --smart-case --word-regexp x",
                "rg --ignore-case --line-number --context 2 x",
            )
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "rg --hostname-bin=x x"), r)
        @test rc == 2 && occursin("rg", err) && occursin("--no-heading", err)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "sort --out=x f"), r)
        @test rc == 2 && occursin("sort", err) && occursin("-n -r -u -b -f -s -k -t", err)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "less -o f x"), r)
        @test rc == 2 && occursin("less", err) && occursin("no short option", err)
        # the denial says why
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "cd .lanes/scratch/reviewer && julia scripts/dod.jl"), r)
        @test rc == 2 && occursin(".lanes/", err)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "julia --project=p scripts/dod.jl"), r)
        @test rc == 2 && occursin("--startup-file=no", err)
    end

    @testset "review round 4 (A1, A5): cp/mkdir fixed options, no symlink target; the agents' own command list" begin
        # A1: macOS cp takes -s/-l (a symlink or hard link is made under the scratch, then a plain cp writes THROUGH it to
        # the linked file outside), so cp takes only -R -r -p and mkdir only -p (getopt clusters, `--` ends the options,
        # no long option), and a target whose path or any parent below the root is an existing symlink is refused
        sc = "$r/.lanes/scratch/reviewer"
        mkpath("$sc/real"); write("$r/risk.toml", "version = 1\n"); write("$sc/pf", "p\n")   # round 1 made $sc/p a directory
        symlink("$r/risk.toml", "$sc/lnk"); symlink("$sc/real", "$sc/lnkdir")
        for c in (
                "cp -s $r/risk.toml .lanes/scratch/reviewer/r", "cp -l $r/risk.toml .lanes/scratch/reviewer/r", "cp -Rs .claude/hooks .lanes/scratch/reviewer/h",
                "cp -sR .claude/hooks .lanes/scratch/reviewer/h", "cp -a .claude/hooks .lanes/scratch/reviewer/h", "cp -f p .lanes/scratch/reviewer/q",
                "cp -n p .lanes/scratch/reviewer/q", "cp -X p .lanes/scratch/reviewer/q", "cp -pf p .lanes/scratch/reviewer/q", "cp --parents p .lanes/scratch/reviewer/",
                "mkdir -m 777 .lanes/scratch/reviewer/d", "mkdir -v .lanes/scratch/reviewer/d", "mkdir -pm 700 .lanes/scratch/reviewer/d",
                "mkdir --parents .lanes/scratch/reviewer/d", "mkdir -p -- -v .lanes/scratch/reviewer/d",
                # the symlink the agent planted (or found): the link itself, below a linked directory, the scratch's own parents
                "cp .lanes/scratch/reviewer/pf .lanes/scratch/reviewer/lnk", "cp p .lanes/scratch/reviewer/lnkdir/x", "cp -R .claude/hooks .lanes/scratch/reviewer/lnkdir",
                "mkdir .lanes/scratch/reviewer/lnkdir/new", "mkdir -p .lanes/scratch/reviewer/lnkdir", "mkdir -p .lanes/scratch/reviewer/lnkdir/a/b",
                "cp p $sc/lnk", "cp p .lanes/scratch/reviewer/real/../lnkdir/x",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        for c in (
                "cp -R .claude/hooks .lanes/scratch/reviewer/hooks", "cp -Rp .claude/hooks .lanes/scratch/reviewer/h2", "cp -rp .claude/hooks .lanes/scratch/reviewer/h3",
                "cp -p p .lanes/scratch/reviewer/", "cp -R -p .claude/hooks .lanes/scratch/reviewer/h4", "cp -- p .lanes/scratch/reviewer/g", "mkdir -p .lanes/scratch/reviewer/x/y",
                "mkdir -- .lanes/scratch/reviewer/z", "mkdir -p .lanes/scratch/reviewer/real/sub", "cp -R -- -s .lanes/scratch/reviewer/q",   # a FILE named -s
                "cp p .lanes/scratch/reviewer/real/q", "cp lnk .lanes/scratch/reviewer/real/",   # a plain cp of a link copies the file
            )
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        # round-4 review (B1, M1): abspath folds `..` lexically, so `d/dl/../PWNED` passed while the OS followed the link `dl`
        # that `cp -R` had copied; and an expansion in the target was not resolved. A `.`/`..` component is refused on the RAW
        # target, a `cp -R` source tree holding a symlink is refused, and a `$` or backtick anywhere in the arguments is refused
        mkpath("$r/srcdir"); symlink(r, "$r/srcdir/dl"); write("$r/a", "a\n"); mkpath("$sc/d"); symlink(r, "$sc/d/dl")
        for c in (
                "cp -R srcdir .lanes/scratch/reviewer/d", "cp -r srcdir .lanes/scratch/reviewer/d2", "cp -Rp srcdir/ .lanes/scratch/reviewer/d3",
                "cp a .lanes/scratch/reviewer/d/dl/../PWNED", "mkdir -p .lanes/scratch/reviewer/d/dl/../PWNEDDIR", "cp a .lanes/scratch/reviewer/./x",
                "cp a ./.lanes/scratch/reviewer/x", "mkdir -p .lanes/scratch/reviewer/x/../y", "cp a $sc/d/dl/../P",
                "cp a .lanes/scratch/reviewer/\$(echo ../../../SUBST)", "cp a .lanes/scratch/reviewer/`echo x`",
                "mkdir -p .lanes/scratch/reviewer/\$(printf ../../../D)", "cp \$(echo a) .lanes/scratch/reviewer/x", "mkdir -p \$D/.lanes/scratch/reviewer/x",
                "cp -R .lanes/scratch/reviewer/lnk .lanes/scratch/reviewer/real/", "cp -R .lanes/scratch/reviewer/d .lanes/scratch/reviewer/d4",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        mkpath("$r/.claude/hooks"); write("$r/.claude/hooks/x.sh", "x\n")
        for c in ("cp -R .claude/hooks .lanes/scratch/reviewer/h", "cp -R .claude/hooks/ .lanes/scratch/reviewer/h5/", "cp a .lanes/scratch/reviewer/d/q",
                "cp -R .claude/hooks a .lanes/scratch/reviewer/h6")
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        # round-4 review round 2 (N1, N2): a glob in an operand is expanded by the shell, not by the guard (`dws/*` reached the
        # link dl; `d/*` was a literal to ro_nolink), so `*`, `?`, `[`, `{` and a leading `~` are refused in every operand; and the
        # symlink scan of a cp -R source is unbounded in depth, with a tree deeper than 8 levels refused up front (the cost cap)
        mkpath("$r/dws"); symlink(r, "$r/dws/dl"); mkpath("$r/deep/1/2/3/4/5/6/7/8/9"); symlink(r, "$r/deep/1/2/3/4/5/6/7/8/9/dl")
        mkpath("$r/deep2/1/2/3/4/5/6/7/8/9"); write("$r/deep2/1/2/3/4/5/6/7/8/9/f", "f\n"); mkpath("$r/ok8/1/2/3/4/5/6/7"); write("$r/ok8/1/2/3/4/5/6/7/f", "f\n")
        for c in (
                "cp -R dws/* .lanes/scratch/reviewer/g", "cp a .lanes/scratch/reviewer/d/*", "mkdir -p .lanes/scratch/reviewer/g/*/X",
                "cp a .lanes/scratch/reviewer/d?", "cp [d]l .lanes/scratch/reviewer/x", "cp a .lanes/scratch/reviewer/{x,y}", "cp ~/a .lanes/scratch/reviewer/x",
                "mkdir -p ~/.lanes/scratch/reviewer/x", "cp -R d* .lanes/scratch/reviewer/g", "cp -R deep .lanes/scratch/reviewer/deep", "cp -R deep2 .lanes/scratch/reviewer/deep2",
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        @test !blocked("bash_guard.sh", bash_as("reviewer", "cp -R ok8 .lanes/scratch/reviewer/ok8"), r)              # 8 levels: allowed
        # round-4 review round 3 (P1): operands were stored space-joined and re-split, so `cp -R "sp ace"` scanned `sp` and `ace`
        # (nothing) and planted the link; and write_guard matched the scratch prefix lexically, so a Write through a planted link
        # under the scratch passed. Operands are never re-split; a scratch or report Write follows no symlink and takes no ./.. component
        # The splitter flattens a quoted space or an escape to `_` (`"sp ace"` reaches the guard as `sp_ace`), so an operand holding
        # `_` is trusted only when it exists as written: the source itself, a target's parent (a new last component is fine)
        mkpath("$r/sp ace/in"); symlink(r, "$r/sp ace/in/dl"); mkpath("$r/no_link/in"); write("$r/no_link/in/f", "f\n"); mkpath("$sc/x_y")
        for c in (
                "cp -R \"sp ace\" .lanes/scratch/reviewer/sp", "cp -R 'sp ace' .lanes/scratch/reviewer/sp", "cp -R sp\\ ace .lanes/scratch/reviewer/sp",
                "cp -R no_link \"sp ace\" .lanes/scratch/reviewer/sp", "cp a \".lanes/scratch/reviewer/d/dl/x y\"", "cp a \".lanes/scratch/reviewer/d/d l/q\"",
                "mkdir -p \".lanes/scratch/reviewer/d/dl/x y\" .lanes/scratch/reviewer/z", "cp a \"x y/../.lanes/scratch/reviewer/q\"",
                "mkdir -p \".lanes/scratch/reviewer/new one/z\"", "cp -R \"no link\" .lanes/scratch/reviewer/nl", "cp -R sp_ace .lanes/scratch/reviewer/sp",
                "cp -R no_link .lanes/scratch/reviewer/nl", "cp -R no_link no_link .lanes/scratch/reviewer/n_l",   # a same-named `no_link` could hide `no link`
            )
            @test blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("not blocked for reviewer: $c"); false)
        end
        for c in ("cp a \".lanes/scratch/reviewer/x y\"", "cp no_link/in/f .lanes/scratch/reviewer/nl", "mkdir -p .lanes/scratch/reviewer/x_y/z",
                "cp \"no link/in/f\" .lanes/scratch/reviewer/n_l", "cp a \".lanes/scratch/reviewer/x_y/new one\"", "mkdir -p .lanes/scratch/reviewer/x_y/b_c")
            @test !blocked("bash_guard.sh", bash_as("reviewer", c), r) || (println("blocked for reviewer: $c"); false)
        end
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "cp -R \"sp ace\" .lanes/scratch/reviewer/sp"), r)
        @test rc == 2 && occursin("quoted space", err) && occursin("sp_ace", err)
        for p in ("$r/.lanes/scratch/reviewer/d/dl/q", "$r/.lanes/scratch/reviewer/lnkdir/x", "$r/.lanes/scratch/reviewer/lnk", "$r/.lanes/scratch/reviewer/d/./q",
                "$r/.lanes/scratch/reviewer/d/dl/../q", "$r/.lanes/scratch/reviewer/\$X/q", "$r/.lanes/reports/lnkrep/q")
            islink("$r/.lanes/reports/lnkrep") || symlink(r, "$r/.lanes/reports/lnkrep")
            @test blocked("write_guard.sh", write_as("reviewer", p), r) || (println("write not blocked: $p"); false)
        end
        rc, _, err = hook("write_guard.sh", write_as("reviewer", "$r/.lanes/scratch/reviewer/d/dl/q"), r)
        @test rc == 2 && occursin("symlink", err) && occursin("$sc/d/dl", err)
        for p in ("$r/.lanes/scratch/reviewer/plain.md", "$r/.lanes/scratch/reviewer/d/q", "$r/.lanes/scratch/reviewer/real/x y", "$r/.lanes/reports/reviewer-9.md")
            @test !blocked("write_guard.sh", write_as("reviewer", p), r) || (println("write blocked: $p"); false)
        end
        h = joinpath(mktempdir(), "hooks"); cp(TEST_HOOKS, h); rm(joinpath(h, "_bash_guard_agents_lib.sh"))                       # write_guard needs the lib too
        @test blocked("write_guard.sh", write_as("", "$r/src/x.jl"), r; hooks = h)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "cp a .lanes/scratch/reviewer/d/*"), r)
        @test rc == 2 && occursin("glob", err) && occursin(".lanes/scratch/reviewer/d/*", err)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "cp -R deep2 .lanes/scratch/reviewer/deep2"), r)
        @test rc == 2 && occursin("deeper than 8 levels", err)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "cp -R srcdir .lanes/scratch/reviewer/d"), r)
        @test rc == 2 && occursin("symlink", err) && occursin("srcdir/dl", err)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "cp a .lanes/scratch/reviewer/d/dl/../PWNED"), r)
        @test rc == 2 && occursin("..", err) && occursin("component", err)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "cp -s $r/risk.toml .lanes/scratch/reviewer/r"), r)
        @test rc == 2 && occursin("cp -s", err) && occursin("-R -r -p", err)
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "cp p .lanes/scratch/reviewer/lnkdir/x"), r)
        @test rc == 2 && occursin("symlink", err) && occursin("$sc/lnkdir", err)
        r2 = realpath(mktempdir()); real = realpath(mktempdir()); mkpath("$r2/.lanes"); symlink(real, "$r2/.lanes/scratch")   # the scratch's parent is a link
        @test blocked("bash_guard.sh", bash_as("reviewer", "mkdir -p .lanes/scratch/reviewer/x"), r2)
        rm("$r2/.lanes/scratch"); mkpath("$r2/.lanes/scratch")
        @test !blocked("bash_guard.sh", bash_as("reviewer", "mkdir -p .lanes/scratch/reviewer/x"), r2)
        # A5: the agents' command list is their own (RO_AGENT_CMDS, _bash_guard_agents_lib.sh), pinned here so a change is deliberate;
        # it no longer shares RO_CMDS with the reference-root policy, so a tool added for the roots is not granted to an agent
        lib = read(joinpath(TEST_HOOKS, "_bash_guard_agents_lib.sh"), String)
        @test occursin("\nRO_AGENT_CMDS=' cat head tail less grep rg find ls wc stat file cd pushd popd pwd echo printf true false test date diff cmp sort cut tr uniq basename dirname realpath which jq '\n", lib)
        @test !occursin("RO_CMDS", read(joinpath(TEST_HOOKS, "_bash_guard_agents.sh"), String))
        h = joinpath(mktempdir(), "hooks"); cp(TEST_HOOKS, h); roots = joinpath(h, "_read_only_roots.sh")
        write(roots, replace(read(roots, String), "RO_CMDS=' cat " => "RO_CMDS=' xargs cat "; count = 1))
        @test blocked("bash_guard.sh", bash_as("reviewer", "xargs ls"), r; hooks = h) && !blocked("bash_guard.sh", bash_as("reviewer", "cat p"), r; hooks = h)
    end

    @testset "fails closed: a missing library, a limits.env without the list" begin
        h = joinpath(mktempdir(), "hooks"); cp(TEST_HOOKS, h); rm(joinpath(h, "_bash_guard_agents.sh"))
        for (g, p) in (("bash_guard.sh", bash("ls")), ("write_guard.sh", write_payload("$r/src/x.jl")))
            rc, _, err = hook(g, p, r; hooks = h)
            @test rc == 2 && occursin("_bash_guard_agents.sh", err)
        end
        h = joinpath(mktempdir(), "hooks"); cp(TEST_HOOKS, h)
        env = joinpath(h, "limits.env")
        write(env, replace(read(env, String), r"^READ_ONLY_AGENTS=.*\n"m => ""))
        rc, _, err = hook("bash_guard.sh", bash_as("reviewer", "ls"), r; hooks = h)
        @test rc == 2 && occursin("READ_ONLY_AGENTS", err) && occursin("gen.jl", err)
        @test blocked("write_guard.sh", write_as("reviewer", "$r/.lanes/reports/r.md"), r; hooks = h)
        @test !blocked("bash_guard.sh", bash("ls"), r; hooks = h)                            # the lead: no agent_type, no list needed
        @test blocked("bash_guard.sh", bash_as("implementer", "ls"), r; hooks = h)           # any agent: the guard cannot tell
    end

    @testset "runtests.jl: NAME... selects test files; --hooks-dir DIR overrides HOOKS (0.4.0)" begin
        @test runtests_args(String[]) == (String[], "")
        @test runtests_args(["hooks", "gen"]) == (["hooks", "gen"], "")
        @test runtests_args(["hooks", "--hooks-dir", "x/hooks"]) == (["hooks"], abspath("x/hooks"))
        @test runtests_args(["--hooks-dir=x/hooks"]) == (String[], abspath("x/hooks"))
        @test_throws ErrorException runtests_args(["--hooks-dir"])
        @test_throws ErrorException runtests_args(["--root", "x"])
        @test selected_files(["hooks"]) == ["test_hooks.jl", "test_hooks_lifecycle.jl", "test_hooks_tdd.jl", "test_hooks_tdd040.jl"]
        @test selected_files(["gen", "lane"]) == ["test_gen.jl", "test_lane.jl", "test_lane_040.jl", "test_lane_040b.jl"]
        @test selected_files(String[]) == TEST_FILES
        @test_throws ErrorException selected_files(["nosuch"])
    end
end
