# Spec: factory 0.2.6, lanes that work in their own worktrees

Status: Implemented (lane factory-026, awaiting the lead's review and merge) · Date: 2026-10-20 · Tier: T3 (hooks, lane machinery)

## Goal

Seven factory problems that lanes hit on 2026-10-20. Each one was reproduced in a scratch repo built
from the 0.2.5 template (`sync_factory.jl --apply` into an empty repo) before it was fixed, and
re-run on the 0.2.6 template afterwards. Items 4 and 5 need a repo OUTSIDE `/tmp` and `$TMPDIR`,
because `allowed()` lets every write there through. They ran in a gitignored `.lanes/scratch/`.

## Items, causes, fixes

1. **`lane new` drops machine-local files.** `.agents/factory.local.toml` is gitignored, so a new
   worktree lacks it and `.claude/hooks/read-only-roots.txt`. In a repo with
   `require_read_only_roots = true`, every Bash call in the lane fails closed. 0.2.5: after
   `lane new x`, both files are missing and `ls` in a session rooted there gives rc 2 ("requires
   read-only roots"). **Fix:** `lane new` copies the file when the repo has one (`Lane.local_setup`)
   and runs the lane's own `scripts/gen.jl` there. A failing gen.jl is a loud warning; the lane
   still exists. The file is T3 data the user owns, and copying the user's own file is the intended
   setup, not a T3 edit. It is documented in lane.jl's header, the lane-lifecycle skill and
   checks.toml (blind spot: the copy is made once; a later change does not reach open lanes).

2. **A bash_guard gap.** The cause is neither the glob anchor nor the first word `scripts/lane`.
   When `scripts/lane new y && cp .agents/factory.local.toml .worktrees/y/.agents/` is checked,
   `.worktrees/y` does not exist yet (the hook runs before the command). So `t3_check` found no
   enclosing checkout and matched `.worktrees/y/.agents` against the ROOT's globs, which anchor at
   the root and cannot match. With `y` existing, the same `cp` was denied (`T3_DIR`: the directory
   holds T3 paths). **Fix:** `t3_check` treats `<root>/.worktrees/<n>` and
   `<root>/.claude/worktrees/<n>` as a checkout root by its place, existing or not. Its T3 list is
   the lane's own `protected-paths.txt` once it exists, else the hooks' list. A `cp`/`mv`/`ln`
   target ending in `/` is a directory even before it exists, so the denial names the file
   (`.agents/factory.local.toml is a T3 protected path`). Regression tests: seven commands in
   `test_bash_guard.jl` "lane worktrees", all rc 0 on 0.2.5.

3. **`merge_base` preferred `origin/<base>` even when behind.** **Fix:** `base_ref` in
   `_common.jl` picks the local `<base>` when it contains `origin/<base>` (local ahead or equal) or
   no origin exists, and `origin/<base>` when the local branch is missing, behind or diverged.
   `merge_base` tries that ref first and then the other. It is used by `lane audit`, `dod.jl`,
   `ratchet.jl` and `bench.jl`. `lane audit` takes `--base B` (it overrides the recorded base).
   0.2.5: `[FAIL] outside owns: side.md` for a file merged into local main but not pushed, and
   `dod.jl: 2 files changed`. 0.2.6: `lane audit: OK`, `dod.jl: 1 files changed`.

4. **Hooks blocked writes into nested lane worktrees.** `lane new` resolves the main checkout from
   `--git-common-dir`, so a sub-lane made inside lane `x` lands at `<main>/.worktrees/<sub>`, a
   sibling outside `CLAUDE_PROJECT_DIR=<main>/.worktrees/x`. **Choice: honour the repo's lane
   worktrees as in-repo**, not "document the in-worktree disjoint-files pattern":
   - The other pattern cannot isolate a sub-lane: two agents in one worktree share an index and
     HEAD, so a commit by one sweeps up the other's staged work, and `lane audit` cannot tell
     them apart.
   - An in-process teammate (root = the main checkout) can already write every lane worktree, so
     a lane rooted in its worktree gains nothing a teammate lacked.
   - The scratch copies lanes used instead had no guards at all.
   - **How:** `_lib.sh` reads the session root's `.git` file. When it is a linked worktree
     (`gitdir: <main>/.git/worktrees/<n>`), it sets `MAIN` (also `MAIN_P`, symlinks resolved, and
     `MAIN_L`, the root minus `/.worktrees/<n>`, when it is the same directory).
   - `allowed()` then accepts `<main>/.worktrees/?*`, `<main>/.claude/worktrees/?*` and
     `<main>/.lanes/reports/?*`. The main checkout's own files stay outside, and T3 paths in a
     sibling stay blocked (`t3_check` takes `MAIN` as its root there).
   - Which sibling a lane may touch is left to the brief and `lane audit` (a recorded blind spot).
   - 0.2.5: rc 2 for a doc in the sub-lane. 0.2.6: rc 0, while a T3 path there and `<main>/notes.md`
     stay rc 2.

5. **teammate_idle vs write_guard.** The lead's hook (root = main) looked only at
   `<main>/.lanes/reports/<name>.md`, which a lane rooted in its worktree may not write. **Fix,
   both sides:** write_guard lets a lane write `<main>/.lanes/reports/` (item 4's `in_main`), and
   teammate_idle also accepts `.lanes/reports/<name>.md` inside any `.worktrees/*/` or
   `.claude/worktrees/*/`. The denial says "in your repo root or your lane worktree". 0.2.5: rc 2
   for both; 0.2.6: rc 0 for both.

6. **Test template (ADR-0007 §2, amended 2026-10-20).**
   - The seeded `test/runtests.jl` shows the form in a comment:
     `sr = @check record = false db = false …` then `@test Supposition.results(sr).ispass`
     (`results` is not exported: `UndefVarError` without the prefix, run on both versions). The
     comment says why.
   - It is not a live `@testitem`: TestItemRunner would run it, and Supposition is not a seeded
     test dependency.
   - The seeded `.gitignore` gains `/test/SuppositionDB/`; CLAUDE.md, property_tester and
     law_tester say the same.
   - Reproduced with Supposition 0.3.5. A bare failing `@check` inside `@testset` exits 0 on 1.10.12
     with summary "None", and exits 1 on 1.13.2. The template form exits 1 with `Pass 1 Fail 1` on both.

7. **The 1.10 Manifest.** Reproduced: a project with PrecompileTools resolved on 1.13.2 (v1.3.4,
   whose General compat is `julia = "1.12.0 - 1"`) fails on 1.10.12 with
   `UndefVarError: StaticData not defined`. Julia 1.10.12 reads `Manifest-v1.10.toml` in
   preference to `Manifest.toml` (checked with `Pkg.Types.manifestfile_path`), and the seeded
   `/Manifest*.toml` already ignores it. An empty one needs `Pkg.resolve()`, because
   `Pkg.instantiate()` alone errors ("does not appear in the manifest"). Then it loads
   PrecompileTools 1.2.1 and records `julia_version = "1.10.12"`. **Fix:** document the pattern
   (CLAUDE.md "Testing", seeded `test/runtests.jl`); seed no file. An empty manifest would be a
   committed or synced file with no content, and `/Manifest*.toml` already covers it. A test asserts
   that the seeded `.gitignore` ignores `Manifest-v1.10.toml`, `test/Manifest-v1.10.toml` and
   `test/SuppositionDB/`.

8. **Found on the way: check_docs under a subdirectory root.** The first template run of item 6
   failed check_docs (`CLAUDE.md:92: missing test/SuppositionDB/` and three more). `gitignored()`
   looked up the `.gitignore` path that `git check-ignore -v` prints (relative to the repo's top)
   from the checked root. For `factory/template` that root is a subdirectory, so the file never
   counted as tracked. **Fix:** a `:(top)` pathspec. Test: a repo whose root is `sub/` (0.2.5 false,
   0.2.6 true).

## Migration

- Managed files update on sync. `.gitignore`, `CLAUDE.md` and `test/runtests.jl` are SEEDED, so
  existing packages see the diff only: add `/test/SuppositionDB/` and the two Testing bullets by hand.
- No guard is stricter for existing work. The new T3 denial applies to lane worktrees that did not
  exist yet, which were always meant to be protected.

## Not done

- Real CI runs (they need a push); syncs into the coordinator and the packages (their own lanes).
- `ci.jl test` does not create `Manifest-v1.10.toml` itself (CI resolves afresh; this is a local
  workflow).
