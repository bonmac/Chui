# bash_guard cases from the guard-rereview security review (factory 0.2.3). Split from
# test_hooks.jl (whose helpers hook, bash, blocked, hooks_with_roots and REF_ROOTS it uses) to
# keep both under the 400-line scripts budget of ratchets.toml.
@testset "hooks: bash_guard guard-rereview" begin
    root = realpath(mktempdir())
    @testset "bash_guard: guard-rereview bypasses (0.2.3)" begin
        # ⏎ is a newline and “ a double quote; raw strings keep $ and \ literal. All but three gave rc 0 on 0.2.2.
        nl(c) = replace(c, "⏎" => "\n", "“" => "\"")
        gb(c; hooks = HOOKS) = hook("bash_guard.sh", bash(nl(c); cwd = root), root; hooks)[1]
        cases = [
            # M1: TMPDIR reassigned without `=`; a literal $TMPDIR/... is never a relative path
            raw"unset TMPDIR; rm -rf $TMPDIR/opt", raw"unset TMPDIR && rm -rf “$TMPDIR“/Users",
            raw"printf -v TMPDIR /; rm -rf $TMPDIR/opt", raw"read TMPDIR < f; rm -rf $TMPDIR/opt",
            raw"for TMPDIR in /; do :; done; rm -rf $TMPDIR/opt", raw"rm -r $TMPDIR/../../../../opt",
            # M2: keywords, wrappers, quoted or escaped names, find -exec/-delete, xargs
            "if [ -d build ]; then rm -rf build; fi", raw"for d in build dist; do rm -rf $d; done",
            "if rm -rf /opt/x; then :; fi", "while rm -rf /opt/x; do :; done", "until rm -rf /opt/x; do :; done",
            "! rm -rf /opt/x", "else rm -rf /opt/x", "elif rm -rf /opt/x; then :; fi", "{ rm -rf /opt/x; }",
            "exec rm -rf /opt/x", "nohup rm -rf /opt/x", "timeout 5 rm -rf /opt/x", "timeout -s KILL 5 rm -rf /opt/x",
            "doas rm -rf /opt/x", "builtin rm -rf /opt/x", "caffeinate rm -rf /opt/x", "caffeinate -t 5 rm -rf /opt/x",
            "sudo -u root rm -rf /opt/x", "sudo -E -u root nice -n 5 rm -rf /opt/x",
            "xargs rm -rf /opt/x", "xargs -0 -I {} rm -rf /opt/x", "ls | xargs rm -rf",
            "find . -name node_modules -exec rm -rf {} +", raw"find . -exec true \; -exec rm -rf /opt/x \;",
            "find /opt -delete", "find /opt -name x -fprint /opt/list",
            raw"\rm -rf /opt/x", "'rm' -rf /opt/x", "\"rm\" -rf /opt/x", raw"r\m -rf /opt/x",
            raw"rm${IFS}-rf${IFS}/opt/x", raw"$RM -rf /opt/x", "`echo rm` -rf /opt/x",
            "rm -rf /private/tmp/claude-501/p/s/x `pwd`", "eval rm -rf /opt/x", "eval \"rm -rf /opt/x\"",
            "echo x | 'tee' /opt/x", raw"echo x | \tee /opt/x", "echo x | if true; then tee /opt/x; fi",
            "echo x | xargs touch /opt/x",
            # M3: a false heredoc start must not hide later lines
            "echo 'see <<EOF'⏎git reset --hard", "echo \"a <<EOF\"⏎rm -rf /opt/x", "# note <<EOF⏎rm -rf /opt/x",
            "cat <<<EOF⏎rm -rf /opt/x", raw"echo $((1<<FOO))⏎rm -rf /opt/x", raw"echo “$((1<<FOO))“⏎rm -rf /opt/x",
            "(( x<<FOO ))⏎rm -rf /opt/x", "cat <<EOF \"⏎\"; rm -rf /opt/x⏎EOF", "cat <<NEVER⏎rm -rf /opt/x",
            # m1: writes through tools that were not modelled
            "sed -i '' 's/a/b/' /opt/x", "sed -i.bak s/a/b/ /opt/x", "sed -i -e s/a/b/ /opt/x",
            "perl -pi -e 's/a/b/' /opt/x", "perl -i.bak -pe 's/a/b/' /opt/x", "cp -t /opt a",
            "cp --target-directory=/opt a", "install -t /opt a", "echo x >| /opt/x", "echo x >|/opt/x",
            raw"echo x >“$HOME“/x", "curl -o /opt/x http://e", "curl --output=/opt/x http://e",
            "wget -O /opt/x http://e", "tar -xf a.tar -C /opt", "tar xzf a.tgz --directory=/opt",
            "unzip a.zip -d /opt", "git clone x /opt/x", "git init /opt/x", "git worktree add /opt/x",
            "git worktree add -b b /opt/x", "git --git-dir /opt/x/.git commit -m m",
            "git --git-dir /opt/x/.git reset --hard", "\"git\" reset --hard", "git push \"--force\"",
            # m3: backslash-newline continuation
            "rm \\⏎-rf /opt/x", "git reset \\⏎--hard",
            # the 0.2.3 reviewer: long and late clean flags, commit -n (= --no-verify)
            "git clean --force", "git clean -d --force", "git clean -x -d -f", "git commit -nm x", "git commit -n -m x",
            "git commit -an", "git commit -m x -n"]
        for c in cases
            @test gb(c) == 2 || (println("not blocked: $(nl(c))"); false)
        end
        # m2: --git-dir / --work-tree name the repository, like -C
        h = hooks_with_roots(REF_ROOTS)
        mt = expanduser("~/ro-fixture/ref-a")
        for c in ("git --git-dir ~/ro-fixture/ref-a/.git checkout .", "git --git-dir=$mt/.git checkout .",
                  "git --work-tree=$mt checkout .", "git --work-tree $mt checkout .")
            @test gb(c; hooks = h) == 2 || (println("not blocked: $c"); false)
        end
        @test gb("git --git-dir ~/ro-fixture/ref-a/.git log -1"; hooks = h) == 0
        # must not regress: the commands guard-rereview listed as passing, and more
        allow = [
            "git commit -m \"fix: don't split on ; or | in messages\"", raw"git commit -m 'it'“'“'s fine; really > ok'",
            raw"git commit -m “feat(x): add > and < handling“ -m “Body with 'quotes' and \“escapes\““",
            "git commit -m \"rm -rf build is blocked\"", "git commit -m \"mention git reset --hard in text\"",
            "git commit -m \"docs: git push needs approval\"", "git log --format='%H %s' -5", "git log --oneline | head -5",
            "git diff main...HEAD -- src/ > /dev/null", "julia -e 'println(\"a > b; c\")'",
            "julia --project=. -e 'using Pkg; Pkg.test()'", raw"julia --startup-file=no -e “x = 1 > 0 ? \“y\“ : \“n\“; println(x)“",
            "gh pr view 12 --json title,body", "gh pr list --state open", "gh api repos/o/r/pulls --jq '.[].title'",
            "gh run view 123 --log-failed", "gh issue list --label bug", "sed -n '1,20p' file.jl",
            "sed -e 's/a|b/c/g' f > out.txt", "sed -i '' -e 's/<Package>/X/g' f", "grep -E 'a|b|c' f | sort | uniq -c",
            "awk -F'|' '{print \$1 > \"/dev/stderr\"}' f", raw"echo “$(date)“ > notes.txt", "ls 2>&1 | head",
            "cmd 2>/dev/null || true", "rm -r build", "rm build/x.txt", "mkdir -p .worktrees/a && touch .worktrees/a/x",
            "find . -name '*.jl' -exec grep -l foo {} +", "echo 'a#b' ; echo \"c # d\"", raw"printf '%s\n' “it's“ > x.txt",
            "git stash push -m \"lane-a wip\"", "julia -e 'run(`ls`)'", "echo ok # don't worry", "cd /tmp && ls",
            "diff <(sort a) <(sort b)", raw"echo $((1 > 0))", "[ 1 -gt 0 ] && echo yes", "test -f a || echo no > log.txt",
            "cat ~/ro-fixture/ref-a/README.md", "rg foo ~/ro-fixture/ref-a",
            # the commit idiom, real heredocs, continuations and the new wrappers
            "git commit -m \"\$(cat <<'EOF'⏎feat: x⏎⏎rm -rf /opt/x; git reset --hard⏎EOF⏎)\"",
            "cat > notes.md <<'EOF'⏎rm -rf /⏎EOF", "cat <<-EOF⏎\tgit reset --hard⏎\tEOF", "cat <<A <<B⏎a⏎A⏎b⏎B⏎ls",
            raw"echo $((1 << 2))", "echo \"a \\⏎b\"", "ls \\⏎-la", "sed -i '' '/^#/d' f.txt", "sed -i -e '/^#/d' f.txt",
            "sed -n '/^#/p' /opt/x", "perl -ne 'print' /opt/x", "cp /opt/x ./y", "curl -sSL http://e -o out.txt",
            "tar -czf out.tgz -C src .", "tar -tf /opt/a.tar", "git clone https://github.com/o/r",
            "git clone https://github.com/o/r sub/r", "git worktree list", "find . -name '*.tmp' -delete", "find /opt -name x",
            raw"find . -type f -exec grep -l foo {} \;", "timeout 60 julia --project=. -e 1", "xargs -n1 echo < list.txt",
            "sudo -n true", "if [ -f a ]; then echo yes; fi", raw"for f in *.jl; do echo “$f“; done",
            raw"while read -r l; do echo “$l“; done < f", "echo `date` > out.txt", raw"x=$(git rev-parse HEAD) && echo “$x“",
            "nohup julia x.jl > log.txt 2>&1 &", "{ echo a; echo b; } > out.txt", "echo x >| out.txt",
            "git clean -n", "git clean --dry-run -d", "git commit -m x", "git commit -am \"fix: not -n here\"",
            "git commit -m fix-nothing", "git commit --amend --no-edit", "git commit -mrun"]
        for c in allow
            @test gb(c) == 0 || (println("blocked: $(nl(c)) ", hook("bash_guard.sh", bash(nl(c); cwd = root), root)[3]); false)
        end
        @test gb("echo " * "a"^70000) == 2 && gb("echo " * "a"^60000) == 0  # > 64 KiB: could outlast the timeout
        push = Dict("FACTORY_ALLOW_PUSH" => "1")
        @test !blocked("bash_guard.sh", bash("git push --force-with-lease"), root; env = push)
        @test blocked("bash_guard.sh", bash("git push \"--force\""), root; env = push)  # 0.2.2: the quotes hid it
    end
end
