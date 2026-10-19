# Factory changelog

Versions of the development-process template. Repos record the version they vendor in
`.factory-version`; `scripts/sync_factory.jl` shows the diff before taking a new one.
A breaking change (a renamed file, a new required field, a stricter guard) bumps the minor
version while below 1.0.

## 0.2.5 (2026-10-20)

Checks that give the same answer in a fresh clone as in a dev checkout. The first GitHub
Actions runs (2026-10-19) failed where every local run passed, because
`.claude/hooks/read-only-roots.txt` is gitignored: rendered in a dev checkout, absent in CI.
No guard is stricter; nothing to migrate.

- **check_docs: a reference to a gitignored path is never stale** (`scripts/check_docs.jl`).
  A reference that does not resolve is asked of `git check-ignore -v` (as a file and as a
  directory, against each root it may resolve in). It passes only when it is untracked and a
  tracked `.gitignore` ignores it with a non-negated pattern: `.git/info/exclude` and a global
  excludes file differ per machine and do not count, and a tracked file deleted in the work
  tree is still reported (both found by the lane's review). 0.2.4 reported `missing .claude/hooks/read-only-roots.txt` for every doc naming it in
  a fresh clone (CI of the coordinator: HANDOFF.md, factory/CHANGELOG.md, factory/README.md; of
  a package: HANDOFF.md, changelog.d) and passed in a dev checkout. The gitignore decides, not
  a name list, so Manifests and `.lanes/` are covered the same way. New blind spot in
  `.agents/checks.toml`: a typo that still matches an ignore pattern passes (a glob, or an
  unanchored directory such as `dev/`). The new test failed
  on the 0.2.4 tree (2 failed, 1 errored) and passes now.
- **gen.jl tests are hermetic** (`scripts/test/test_gen.jl`). `gen_sandbox` copied the host's
  gitignored `.agents/factory.local.toml` and rendered `read-only-roots.txt` when present, so the
  drift test (`--check` must fail after `read_only_roots` changes) passed only where the roots
  file existed: in a fresh clone `--check` skips the absent local output and reported OK
  (CI of a package: `test_gen.jl:91`, `Evaluated: !(first((true, "gen.jl --check: OK (30 files)\n")))`).
  The sandbox now drops both and renders the roots file from the committed config alone; the
  test also checks that an absent roots file is skipped, not reported missing.
- **hook tests are hermetic** (`scripts/test/test_hooks.jl`, `test_bash_guard.jl`). They ran the
  real `.claude/hooks` dir. A coordinator sets `require_read_only_roots = true`, so in its fresh
  clone (no roots file) bash_guard failed closed on every command: 222 failures in the
  coordinator's own test run, hidden in CI because check_docs failed first (60 in `hooks` alone
  on the 0.2.4 tree). The fail-closed message contains "missing", so the missing-library tests
  passed there for the wrong reason. The tests now run `TEST_HOOKS` by default, a copy with no
  roots, not required; tests that need roots or `REQUIRED=1` already build their own. The
  settings.json wiring test runs its command against a scratch project holding that copy.
- How the class was searched: the full template suite in a fresh clone of the coordinator
  (1345/1346 on 0.2.4, the gen.jl test above), the coordinator's own suite in a fresh clone of a
  scratch coordinator synced to 0.2.5 (which found the hook tests), and a static search of the
  tests for the gitignored files (`factory.local.toml`, the roots file, Manifests).
- Template tests: 1356/1356 on Julia 1.13.2 and 1.10.12 (1346 in 0.2.4). In fresh clones with
  no local files, `scripts/ci.jl guards` passes for a scratch coordinator and a scratch copy of a
  pushed package, each synced to 0.2.5 (both failed on 0.2.4), and for a package bootstrapped
  from 0.2.5 into an empty repo with a doc that names the roots file.

## 0.2.4 (2026-10-19)

Gates that hold when an agent works around them: T3 paths guarded through Bash, the gate's own
tests protected, CI skips that say whether they ran, lanes audited after the fact, and numbers in
docs derived instead of typed. Most of the items come from a study of a reference project's agent
workflow. Template tests: 1346/1346 on Julia 1.13.2 and 1.10.12 (1006 in 0.2.3), recorded by
`scripts/evidence.jl` in `.lanes/evidence/tests-5052c66.txt` and `tests-lts-5052c66.txt` (dirty
tree: 0.2.4 uncommitted on 5052c66). Each new test was run against the 0.2.3 tree first and failed
there (see "Evidence" below).
**Stricter guards**: bash_guard denies Bash writes to T3 paths, both guards deny a payload they
cannot read, and `ci.jl` fails when a seeded file is missing. The CHANGELOG rule says a stricter
guard bumps the minor version; the lead chose 0.2.4. New T3 files and manual edits: read the
migration notes.

- **T3 through Bash** (`.claude/hooks/_bash_guard_write.sh`, new). Every write target bash_guard
  already models (redirections incl. `>|` and heredoc targets, `tee`, `sed -i`/`perl -i`,
  `cp`/`mv`/`install`/`ln`/`rsync` targets, `rm`, `rmdir`, `truncate`, `touch`, `mkdir`,
  `chmod`, `chown`, `dd of=`, `curl -o`, `wget -O/-P`, `tar -x -C`, `unzip -d`,
  `find -delete/-fprint`, `git init/clone/worktree`) now goes through `t3_check`, plus the new
  `git rm`, `git mv`, `git restore` and `git checkout ... -- PATHS`. A target matching a T3 glob of
  its checkout's `protected-paths.txt` (the nearest enclosing git checkout, as in write_guard;
  compared lowercased) is denied unless the SESSION has `FACTORY_ALLOW_T3=1`. A directory
  target that holds a T3 path is denied for the commands that change what is inside it
  (`rm -r scripts`, `mv .claude x`, `cp x scripts/`, `find . -name x -delete`, `tar -x -C .`,
  `chmod -R`), as is a target that is a nested git checkout. 0.2.3 gave rc 0 for
  `sed -i '' s/T3/T0/ risk.toml`, `printf x > scripts/dod.jl` and
  `rm scripts/test/test_dod.jl`; all 46 deny cases of the new test passed on 0.2.3. With no
  `protected-paths.txt` at all, a write inside the repo fails closed. The in-place editor code
  moved from `_bash_guard_cmd.sh` into the new library, and so did `outside()` (cmd 148 lines, lib
  140, write 148; the 150-line ratchet holds). Cost, 100 calls each from sh: 62 → 54 ms for
  `git status && ls -la src` (noise), 60 → 67 ms for a 6-segment command with 7 in-root targets
  (no fork unless a path has capitals or glob characters). In the test suite, which spawns sh
  from Julia: 55-80 ms per call on a loaded machine; the ≤ 250 ms test bound holds. `checks.toml` now says exactly what is still uncovered:
  any write bash_guard does not model, such as julia/python/sh code, `git apply`, `patch`,
  editors, and targets held in variables.
- **Fixes from the 0.2.4 adversarial review** (each reproducer gave rc 0 before its fix and is a
  test now):
  - A bare `.git` marker (a `.git` directory made inside `scripts/`, an empty `.git` file inside `.claude/`) made a directory a
    "checkout" with no T3 paths, for both guards. A checkout now needs `.git/HEAD` or a
    `gitdir:` file. A target is checked against its nearest checkout's list AND the repo root's,
    and writes below any `.git` directory are denied. write_guard now uses bash_guard's
    `t3_check`, so it also fails closed without `protected-paths.txt` (0.2.3: rc 0).
  - Glob characters in a target (`rm risk.tom?`, `rm scripts/dod.j*`, `printf x > risk.tom?`) are
    expanded by the guard as the shell would expand them; a brace list (`rm {risk,x}.toml`) inside
    the repo is denied.
  - Targets that resolved to the wrong path: `$'risk.toml'` and `$"risk.toml"` (the `$` is
    dropped), `~+/` (and `~-/` is denied), `x->f` redirects (the `->` exemption predates quote
    handling and is gone), `git --git-dir=.git rm`, repeated `git -C` (cumulative now),
    `env -C DIR rm f`, `rsync a dst -q` (last non-option operand), `find ... -exec rm {} +`
    (an -exec command outside a short read-only list checks find's start paths as directory
    targets), and the GNU names (`gsed`, `grm`, `gtimeout`, ...). `git -c alias.*` is blocked.
  - False positives removed: `cp`/`mv`/`install`/`ln` into an existing directory check
    `DIR/<source name>` (so `cp /tmp/notes.md .` passes and `cp -r /tmp/scripts .` does not);
    `git rm --cached` and `git restore --staged` touch only the index.
  - `lane audit` read `git diff <merge-base>` (working tree only): a commit reverted in the
    working tree, or a staged change reverted on disk, passed. It now takes the union of the
    commits, the index, the working tree and the untracked files, with `core.quotePath=false`.
  - dod.jl no longer counts an empty fragment or a dotfile fragment (`changelog.d/.mine.md`),
    neither of which `fold` would release. `test_totals` sums every `Test Summary:` table (one per
    top-level testset; 0.2.4-pre read the last one) and strips ANSI colour. check_claims reports
    a mistyped marker (`<!-- Claim: ... -->`, `<!--claim x=1-->`) instead of ignoring it, and the
    template and package `factory.toml` now seed `required = ["max_open"]`. ci.jl treats an
    unknown table in `upstreams.toml` and an unreadable `.factory-version` as `missing` (red).
    bash_guard denies a payload with no command string (`{}`, a number, an array); write_guard
    denies a non-string target. `changelog.jl` knows `## [Unreleased]` and indented headings.
  - From the re-verification: `unzip` without `-d` and `tar -x` without `-C` extract into the cwd,
    which is now checked as a directory target. `lane audit` fails when the lane's base was
    rewritten to its own branch or to a ref that is not a commit.
  - Still open (declared in `checks.toml`): targets from stdin via `xargs`, `stdbuf` and other
    unmodelled wrappers, symlinks, `lane-base` rewritten to another real branch and `lane-owns`
    widened, hand-written evidence files, and prose matching any occurrence of the number.
- **Edit/Write only.** `CLAUDE.md`, every write-mode agent body and the lane-lifecycle skill say
  to change files with Edit/Write, never `sed -i`, redirects or heredocs onto tracked files.
- **The gate's own tests are T3**: `scripts/test/*`, plus `scripts/bench.jl`, `scripts/lane`,
  `scripts/lane.jl`, `scripts/changelog.jl`, `scripts/check_claims.jl` and
  `scripts/evidence.jl`, in the template `risk.toml` and the coordinator overlay. The dod.jl and
  ratchet.jl CLI tests now assert the exact `[FAIL] <requirement>` / `FAIL <limit>` lines. With
  the changelog check of dod.jl mutated to always pass, the 0.2.3 tests still passed 29 of 30
  and the new ones fail 11. With the size-raise check of ratchet.jl mutated to stop at the first
  rule, the 0.2.3 tests passed 17 of 17 and the new ones fail 1.
- **CI skips declare their kind** (`ci.jl`): `not_applicable` (not a package: exit 0), `waiting`
  (no upstreams, no `benchmark/` directory: exit 0, a `NOT RUN (waiting) ... its exit 0 is not a
  pass` line and a GitHub `::warning`), `missing` (a file the package profile seeds or expects is
  gone: `test/jet/{Project.toml,runjet.jl}`, `docs/{Project.toml,make.jl}`,
  `test/contracts/{upstreams.toml,Project.toml,runtests.jl}`, `benchmark/benchmarks.jl` when
  `benchmark/` exists: exit 1). In 0.2.3, deleting any of these printed "skipped" and exited 0.
  `ci.jl` and `scripts/lane new` warn when `JULIA_PROJECT`, `JULIA_LOAD_PATH` or
  `JULIA_DEPOT_PATH` is inherited.
- **Lane scope audit** (`scripts/lane.jl`). `scripts/lane new <name> --owns '<globs>'` records the
  owned globs (plus `changelog.d/<name>.md`) in `git config branch.<branch>.lane-owns` and as a
  `lane-new` line in `.lanes/ledger.jsonl`. `scripts/lane audit <name> [--reported FILE]
  [--owns GLOBS]` fails when the lane's committed, uncommitted or untracked changes since the merge
  base touch a path outside the owned globs, when it has none recorded, or when they differ from
  the lane's reported file list. It is wired into `/change-review`, the reviewer body and the
  lane-lifecycle skill. Tested on real temporary git repos.
- **Changelog fragments.** `dod.jl` accepts a newly ADDED `changelog.d/<name>.md` as the
  `changelog` evidence (editing an old fragment, `README.md`, `.gitkeep` or a nested file does
  not count). The new `scripts/changelog.jl list|fold [--dry-run]` folds the fragments, in name
  order, under `## Unreleased` and deletes them; an empty fragment or one with a heading stops
  the fold. The release-check command and the release_manager body run it. `changelog.d/.gitkeep`
  is seeded.
- **Close by reproducer.** The reviewer, critic and contract_steward bodies and
  `/change-review` require a `Reproducer:` command on every blocker and every cross-repo request.
  Closing it needs that command's RED run (before the fix) and GREEN run (after), quoted.
  `/contract-check` drafts requests with a `- **Reproducer:**` line.
- **Numbers in docs** (`scripts/check_claims.jl`, in `ci.jl guards`). A `<!-- claim: key=value -->`
  marker on the line that states the number is checked against the derived value: `max_open`,
  `roles`, `factory_version`, `max_lines:<glob>` (ratchets.toml), and `tests_pass/fail/error/
  broken/total` from an evidence file. The value must also appear in the line's prose. Each file
  is checked against the nearest enclosing checkout with a registry, so a coordinator's
  `factory/template/CLAUDE.md` is checked against the template. `.agents/factory.toml
  [check_claims]` holds `files` (globs; default every tracked `*.md`) and `required` (keys that
  must have a marker). Missing evidence makes a claim UNVERIFIED: that is exit 0, and exit 1 with
  `--strict`. The template's CLAUDE.md lane-cap line carries a marker.
- **Evidence files** (`scripts/evidence.jl <kind> -- <cmd...>`, `latest <kind>`). It writes
  `.lanes/evidence/<kind>-<sha7>.txt` (gitignored) with the head sha, a dirty flag, the command,
  its exit code, the seconds, the date, the parsed test totals and the full output, and it exits
  with the command's code. `CLAUDE.md` says that test counts in docs cite one.
- **Fail closed on unreadable payloads** (an extra from the same study). bash_guard and
  write_guard deny a payload that is not a JSON object; write_guard also denies one with no
  target key, and it reads `tool_input.path` too. In 0.2.3 both cases gave rc 0. The test
  helper `json()` now escapes tabs: a raw tab is invalid JSON, so one heredoc case in 0.2.3 had
  passed only because the guard failed open.
- **Other extras done**: a critic gate-audit checklist (make each gate go red, NOT RUN vs found
  nothing, delete the gate and look for a red test, list the exemptions, "this is not
  verification"); the lane-lifecycle skill checks once more for a late message before recording
  `no_report`; env hygiene (above). **Skipped**: dated harness probes (their home is the
  coordinator's `research/`) and mutation specs for contract tests (L).
- **Hermetic tests in every profile.** Two tests failed in a coordinator checkout on 0.2.3,
  because they read the checkout's own `require_read_only_roots = true`: `test_gen.jl`'s
  `READ_ONLY_ROOTS_REQUIRED=0` and the "package profile seeds no roots" case. `hooks_with_roots`
  now writes its own `limits.env` (`required = false` by default; `src` selects the hooks to
  copy), and the new `gen_sandbox_noroots` writes its own `factory.toml`. A regression test builds
  a host with `require_read_only_roots = true`, checks that the host itself fails closed, and
  checks that the helpers do not inherit it. The new T3 tests use a fixture
  `protected-paths.txt`, and `ci.jl`'s not-applicable test uses an empty directory, not the
  checkout.
- **Exec bits restored.** 15280a8 (0.2.3) committed `.claude/hooks/bash_guard.sh`,
  `dispatch_limit.sh`, `scripts/_common.jl` and `scripts/gen.jl` as 644 (0.2.2: 755), and the
  `_bash_guard_cmd.sh` (new in 0.2.3) and `scripts/contract_usage.jl` had never been executable; sync copies template
  modes, so vendored repos got 644. Every hook, every `scripts/*.jl`, `scripts/lane` and
  `scripts/test/runtests.jl` is now 755. `test_sync_factory.jl` asserts it for the template and
  for a synced repo; on 0.2.3 that test fails 12 times. Sync already preserved modes, and a test
  already covered a mode-only repair.

### Evidence

- Template: `julia scripts/evidence.jl tests -- julia --startup-file=no scripts/test/runtests.jl`
  gives 1346/1346 on Julia 1.13.2 and 1.10.12 (evidence files named above).
- RED on 0.2.3: the final 0.2.4 test files run against the 0.2.3 scripts and hooks (a copy of the
  0.2.3 tree in a fresh git repo) give 1086 passed, 147 failed and 28 errored. By test set:
  bash_guard T3/payload/review 98 failed and 1 errored; hooks 7 failed and 1 errored (gate globs,
  `{}` payload); ci.jl 22 failed (skip kinds); sync_factory 13 failed (exec bits); dod.jl 2 failed
  and 2 errored (fragments); gen.jl 4 failed (new scripts not registered); lane audit 1 failed
  and 6 errored; changelog, check_claims and evidence errored (the scripts do not exist).
- Mutation check of the new reason-specific asserts: see the gate-tests item.
- Sync rehearsals:
  - Coordinator copy (`--profile coordinator`, `require_read_only_roots = true`, gen run):
    `ci.jl guards` OK with its tests at 1139/1139. The same copy on 0.2.3 gave 860/3. Still OK
    after the manual edits below, and check_claims fails a `max_open=4` marker in HANDOFF.md.
  - ChuiCore.jl copy (`--profile package`, 0.2.1 → 0.2.4, no conflicts): `ci.jl guards` OK with
    its tests at 1188/1188. `ci.jl test`, `jet` and `docs` are OK; `contracts` and `bench` print
    NOT RUN (waiting).

### Migration notes

- New managed files: `.claude/hooks/_bash_guard_write.sh` (bash_guard fails closed without it),
  `scripts/changelog.jl`, `scripts/check_claims.jl`, `scripts/evidence.jl` and their tests. Seeded
  when missing: `changelog.d/.gitkeep`. Sync writes them as a Julia process, which bash_guard does
  not model; after the manual `risk.toml` edit below, editing `scripts/test/*` needs
  `FACTORY_ALLOW_T3=1` like the other gate files.
- Seeded files are not updated by a sync. Make these edits by hand, as a T3 change with an ADR:
  - `risk.toml` T3 globs: add `scripts/bench.jl`, `scripts/lane`, `scripts/lane.jl`,
    `scripts/changelog.jl`, `scripts/check_claims.jl`, `scripts/evidence.jl` and `scripts/test/*`.
    A repo seeded before 0.2.2 also lacks the 0.2.2 gate list (`.agents/bodies/*`,
    `.agents/checks.toml`, `.claude/agents/*`, `.codex/agents/*`, `scripts/dod.jl` ...
    `scripts/_common.jl`, `.agents/factory.local*`), so copy the template's whole T3 block. Then
    run `julia scripts/gen.jl`.
  - `.agents/factory.toml`: add `[check_claims]` with `files = []` and `required = []`, or with
    the keys you want enforced. The table is optional: without it no key is required.
  - `.agents/agent-registry.toml`: the implementer's `file_scope` takes `changelog.d/**` instead
    of `CHANGELOG.md`; the release_manager's adds `changelog.d/**`. Run `julia scripts/gen.jl`.
  - `CLAUDE.md`: rule 5 (changelog fragments), the new rule 7 (Edit/Write only; evidence files),
    the lane line (`--owns`, `lane audit`) and the lane-cap claim marker, as in the template.
    `CHANGELOG.md`'s intro mentions fragments.
- `ci.jl jet`, `docs` and `contracts` now FAIL in a package that lacks their seeded files; restore
  them from the seed (a sync shows them).
- A command that wrote into a directory holding T3 paths through Bash, such as
  `find . -name '*.tmp' -delete`, is now denied: name a narrower start path (`find build ...`).
- The coordinator's `requests/README.md` (outside the factory) should add a `- **Reproducer:**`
  field to its request format, matching the contract_steward body and `/contract-check`.

## 0.2.3 (2026-10-19)

Security fixes from the second guard review (guard-rereview), plus three follow-ups from the L0
checkpoint: no private project names in the factory, AirspeedVelocity benchmarks and a seeded
LICENSE (ADR-0011). Template tests: 1006/1006 on Julia 1.13.2 and 1.10.12 (807 in 0.2.2).
guard-rereview's 270 payloads: 260/270 under both sh and dash (the 10 misses are listed below).
142 new payloads: 141/142 (the miss is a push dry-run, which needs `FACTORY_ALLOW_PUSH`).
**Stricter guard**: `rm -rf $TMPDIR/...` no longer passes, and `eval` is blocked. The CHANGELOG
rule says a stricter guard bumps the minor version; the lead chose 0.2.3. New T3 file and
manual edits: read the migration notes.

- **bash_guard M1: `rm -rf` accepts only LITERAL absolute scratch paths.** 0.2.2 trusted
  `$TMPDIR/...` unless the command contained `TMPDIR=`, so `unset TMPDIR`, `read TMPDIR`,
  `printf -v TMPDIR`, `for TMPDIR in /` (and `eval`, `source`, the user's profile) turned it into
  `rm -rf /opt`. The hook cannot know the command shell's TMPDIR, so no `$TMPDIR` form passes. A
  target ending in `/` or `/.`, or holding `{`, is refused too. `outside()` expands `$TMPDIR` to
  the hook's own value, so it is never read as a relative path.
- **bash_guard M2: the command name is found the way the shell finds it.** A new library,
  `.claude/hooks/_bash_guard_cmd.sh` (`check_cmd`), skips shell keywords
  (`if then else elif while until do ! { }`), assignments, leading redirections and wrappers
  with their options (`env sudo doas nice time timeout N xargs caffeinate exec nohup builtin
  command`). `find -exec/-execdir/-ok/-okdir CMD` is checked as CMD (every one of them). Quote
  characters and backslashes are dropped from words (`'rm'`, `"rm"`, `\rm`, `r\m` read `rm`).
  A command name containing `$` or a backtick (`$RM`, `` `echo rm` ``, `rm${IFS}-rf`) is
  blocked, and so is `eval`. `ls | xargs rm -rf` (no visible target) is blocked. A wrapper inside
  a read-only root is denied, as before.
- **bash_guard M3: heredocs are detected in the quote-aware splitter.** `<<WORD` counts only
  when it is unquoted, outside a comment, outside `$((...))`/`((...))` and not `<<<`.
  `echo 'see <<EOF'` NL `git reset --hard` hid every later line from every check in 0.2.2. A
  body that is never terminated is checked as commands after all, and a body starts only after
  the line's quotes close. The denylist now reads the splitter's output, so `"git" reset --hard`,
  `git push "--force"` and `"$(git reset --hard)"` are caught.
- **m1: more write tools are modelled**: `>|`, `>"$HOME"/x`, `sed -i`/`-i.bak`/`--in-place`,
  `perl -i`/`-pi`, `cp`/`ln`/`install -t`/`--target-directory`, `curl -o`, `wget -O/-P`,
  `tar -x ... -C`, `unzip -d`, `find -delete` and `-fprint`, `git init DIR`, `git clone URL DIR`
  and `git worktree add DIR`. Tools that are still not modelled are listed in
  `checks.toml`.
- **m2:** `git --git-dir DIR` / `--git-dir=DIR` / `--work-tree DIR` / `--work-tree=DIR` name the
  repository like `-C`, both for read-only roots and for mutating git outside the root. The
  denylist's git-options pattern also skips them.
- **m3:** backslash-newline is joined before any check (`git reset \` NL `--hard`).
- **m4: dispatch_limit no longer fails open on a malformed ledger.** It reads the ledger with
  `jq -R 'fromjson?'`, so a bad or truncated line is skipped instead of making the count 0. A
  jq error or a non-numeric count now blocks. precompact reads it the same way.
- Speed: one awk now does the splitting, the heredocs and the denylist input (0.2.2 used awk,
  sed and awk). 45 ms per call (70 ms in 0.2.2) and 63 ms with 3 roots and 6 segments
  (`hook start-up cost` test). A command over 64 KiB is refused: a 288 KB one took 6 s, close to
  the 10 s hook timeout, which fails OPEN; the worst case under the cap measured about 4 s
  (11k `mkdir` operands; one fork each). Hook sizes: bash_guard 79 lines, `_bash_guard_lib.sh` 147,
  `_bash_guard_cmd.sh` 150, `_read_only_roots.sh` 66; the 150-line ratchet holds.
- **No private project names (public repos).** Test payloads use fixture roots
  (`~/ro-fixture/ref-a`, `/tmp/ro-fixture/ref-b`, `~/ro-fixture/ref-c`), with the same cases.
  Read-only roots can also come from **`.agents/factory.local.toml`** (only
  `[bash_guard] read_only_roots`; T3 for agents through the `risk.toml` glob
  `.agents/factory.local*`). `gen.jl` merges and deduplicates it into
  `.claude/hooks/read-only-roots.txt`. Both files are gitignored by the seeded `.gitignore`, and
  `gen.jl --check` skips the rendered roots file when it is absent. The new key
  `require_read_only_roots` (rendered into `limits.env` as `READ_ONLY_ROOTS_REQUIRED`) makes
  bash_guard fail closed while no root is rendered. Only `julia scripts/gen.jl` (and
  `--check`) still run, so the file can be regenerated. The coordinator profile seeds
  `read_only_roots = []`, `require_read_only_roots = true` and a pointer to the local file.
- **Benchmark.yml uses AirspeedVelocity and is warning-only** (ADR-0011):
  `MilesCranmer/AirspeedVelocity.jl@action-v1` with `job-summary: 'true'` (no PR-comment
  permission), and `continue-on-error: true`. Inputs were read from the action's `action.yml` on
  2026-10-19. UNVERIFIED: whether the action fails on a slowdown, and whether the registry added
  by `ci.jl setup` survives the action's own setup-julia. To make it blocking later (a T3 edit
  recorded in the repo's CHANGELOG): drop `continue-on-error` and add
  `julia scripts/ci.jl bench -- --base origin/<default>`. `scripts/bench.jl` stays for that and
  as the local runner, since it enforces `ratchets.toml` `bench.time_tolerance`.
- **`LICENSE` is seeded** (MIT, both profiles) with `<YEAR>` and `<COPYRIGHT HOLDER>` to fill in at
  scaffold time. Seeded means a repo that already has a LICENSE keeps it.
- `checks.toml`: the bash_guard blind spots are rewritten. They cover variable write targets,
  the list of modelled write tools and wrappers, the heredoc rule, and symlinks and other
  projects' scratch dirs in the `rm -rf` rule.

Review: a first read-only reviewer stalled before running anything. That lane failed, and its
work was not counted. A second reviewer ran 70 attack payloads, all of which gave rc 0 or 2
under both sh and dash. It confirmed two denylist bypasses that were already there in 0.2.2,
both fixed here with tests: `git clean --force` (and a late `-f`, as in `git clean -x -d -f`),
and `git commit -n`/`-nm` (short for `--no-verify`). It held: wrapper options, quote and escape
desyncs, CR, CRLF and tabs, process substitution, case patterns, and name evasion. The 64 KiB
cap came from probing its untested fail-open class. Left open, outside the guard's stated
rules: `git reset --merge`/`--keep`, `git checkout -- .` and `git restore .`.

Not fixed, and why (guard-rereview harness misses): `echo x #'; rm -rf /opt/x` is a comment in
bash, so the harness expectation is wrong. The three `$TMPDIR` allow cases are blocked on
purpose (M1). `julia --project <space>DIR` makes DIR the script, not the project. Symlinked
targets (`ln -s / l && rm -rf l/opt`) and another project's scratch dir of the same uid are
documented blind spots. `git push --force-with-lease` needs `FACTORY_ALLOW_PUSH`, which the
harness does not set.

### Migration from 0.2.2

The sync writes these T3 files in every repo: `.claude/hooks/_bash_guard_cmd.sh` (new),
`_bash_guard_lib.sh`, `_read_only_roots.sh`, `bash_guard.sh`, `dispatch_limit.sh`,
`precompact.sh`, `.agents/checks.toml`, `.factory-version`, and in packages
`.github/workflows/Benchmark.yml`. It also writes `scripts/_common.jl`, `scripts/gen.jl` and
`scripts/check_docs.jl` (which treats `.agents/factory.local.toml` as external); these are T3
once 0.2.2's `risk.toml` edit is made. And it writes `scripts/test/{runtests,test_hooks,
test_bash_guard,test_gen,test_sync_factory}.jl`. It seeds `LICENSE` where missing. Then, by
hand (T3: the user, or `FACTORY_ALLOW_T3=1`), run `julia scripts/gen.jl` and:

- every repo, `.gitignore` (seeded): add `/.agents/factory.local.toml` and
  `/.claude/hooks/read-only-roots.txt`, then `git rm --cached .claude/hooks/read-only-roots.txt`.
- every repo, `risk.toml`: add `".agents/factory.local*"` to the T3 globs.
- the coordinator, `.agents/factory.toml`: move the `read_only_roots` entries into a new
  `.agents/factory.local.toml` (`[bash_guard] read_only_roots = [...]`), set
  `read_only_roots = []` and add `require_read_only_roots = true`. Then run `julia scripts/gen.jl`.
- a seeded `LICENSE`: replace `<YEAR>` and `<COPYRIGHT HOLDER>` (packages that already had one
  keep theirs).

## 0.2.2 (2026-10-19)

Fixes found by the three package scaffolds (ChuiCore, ChuiTypes, ChuiFrames) and the coordinator
review (S2). Template tests: 807/807 on Julia 1.13.2 and 1.10.12 (683 in 0.2.1); each new test
fails against the 0.2.1 code. New T3 paths and a new contract-test environment: read the
migration notes.

- **`ratchet.jl` passes again (it failed in every repo).** `bash_guard.sh` (210 lines) was over
  the seeded 150-line hook budget. Its helpers moved to two new sourced libraries,
  `.claude/hooks/_bash_guard_lib.sh` (command splitting, paths, `rm`) and `_read_only_roots.sh`
  (bash_guard 142 lines, the libraries 115 and 61, `_lib.sh` 103), instead of a per-file
  exception: a `.` source costs no fork, a per-file rule would be a raised limit, and the
  read-only-roots parsing now runs in bash_guard only, not on every write_guard/dispatch_limit/
  advisory call. The command splitter is one awk instead of sed + tr. New test: every profile's files, as sync renders
  them, pass the seeded `ratchets.toml`.
- **Guards fail closed when a sourced library is missing.** `. _lib.sh` on a missing file exits
  1, which Claude Code treats as non-blocking: bash_guard, write_guard and dispatch_limit now
  check their libraries and exit 2.
- **bash_guard: quoted text is one argument.** `sed -i '' -e 's/<Package>/X/g' f` was read as a
  redirect to `/X/g`, and `git commit -m "a; rm -rf x"` as a second command. Inside `'...'`,
  `"..."` and `$'...'` (and after a backslash) blanks, `; & | ( ) < >` no longer split or
  redirect. A `"$(...)"` or backtick substitution inside double quotes is still split and checked,
  and a `#` comment ends its line (an apostrophe in it is not a quote). Real redirects of quoted
  paths (`> "/opt/x"`) are still caught. A `sh -c '...'` string is not inspected (it was caught
  in 0.2.1 only by accident, since `;` split everywhere).
- **bash_guard: `rm -rf` on scratch paths** (lanes could not clean their scratchpads). Allowed only
  when every target is ABSOLUTE (or `$TMPDIR/...`, `"$TMPDIR"/...`) and lies strictly below
  `$TMPDIR` or at least three levels below this user's `/private/tmp/claude-<uid>/` (a
  `<project>/<session>/...` path, no glob in those two parts). Never a relative target (the
  tracked cwd can be wrong after a bare `cd`, `cd -`, a subshell or `popd`), never in the repo
  root, never `$TMPDIR/...` when the command assigns TMPDIR, never another uid.
- **`ci.jl docs`, `jet` and `contracts` never rewrite tracked files.** They developed the
  checkout into `docs/` and `test/jet/` in place; on Julia >= 1.11 that wrote
  `[sources] Pkg = {path = "/abs/..."}`, added the package to `[deps]` and dropped comments
  (reproduced on a ChuiCore copy). They now copy the env's `Project.toml` to a scratch directory
  (relative `[sources]` paths made absolute), develop there, run there and delete it. Test: a
  fixture package's tracked files are byte-identical and `git status` clean after all three jobs.
- **Contract tests run in their own environment** (the coordinator's `contracts/README.md`): new
  seeded `test/contracts/Project.toml` (Test, TestItemRunner; upstreams added per repo) and
  `test/contracts/runtests.jl` (`TestItemRunner.run_tests` over `test/contracts/`, `:contract`
  items only). `ci.jl contracts` resolves a scratch copy against the latest upstream release, or
  upstream main with `-- main`, so the old `--in-place` gate is gone. A repo without
  `test/contracts/Project.toml` is skipped with a message. The seeded `test/runtests.jl` never
  selects `:contract` items, even with `-- all`.
- **Package profile overlay** `profiles/package/.agents/factory.toml`: `[check_docs] exclude =
  ["docs/agent/*", "test/contracts/*.md"]` for the verbatim copies every package carries.
- **Seeded `.gitignore`** ignores `/test/jet/Manifest*.toml` and `/test/contracts/Manifest*.toml`
  (`/docs/Manifest*.toml` was already there). Test: every seeded env directory's Manifest is ignored.
- **Seeded `test/jet/Project.toml`** has `[compat]` for TOML and `julia = "1.12"` (ADR-0004 rule 3).
  Test: every seeded `Project.toml` has compat for `julia` and each dep.
- **CI.yml: no Codecov upload.** ADR-0011 wants a local floor and no external service; the
  existing `ci.jl coverage` step (`ratchet.jl --lcov`, floor in `ratchets.toml`) is the check.
  ADR-0011 (Proposed) names a coverage-floor.txt file read by a coverage_floor.jl script; the
  factory keeps the floor in `ratchets.toml` (same one-way rule, one file). The ADR text should
  follow at its ★.
- **Protected paths (S2).** The seeded `risk.toml` makes `.agents/bodies/*`, `.agents/checks.toml`,
  `.claude/agents/*`, `.codex/agents/*` and the gate scripts (`scripts/dod.jl`, `ratchet.jl`,
  `gen.jl`, `check_docs.jl`, `contract_usage.jl`, `ci.jl`, `_common.jl`) T3. New coordinator
  overlay `profiles/coordinator/risk.toml`: the coordinator's current `risk.toml` plus the same
  globs. Its `adr` comment is profile-neutral (it named `docs/adr/`).
- `checks.toml`: bash_guard blind spots updated (quoting, the scratch `rm -rf` rule, edited
  libraries are trusted).

Review (one read-only reviewer over this diff) found three bash_guard bypasses that the first
draft of this release introduced, all fixed above with tests: a `"$(...)"` substitution was masked
as quoted text, an apostrophe in a `#` comment masked every later line, and the scratch `rm -rf`
rule trusted the tracked cwd and `$TMPDIR` (`cd /scratch/x && cd && rm -rf *` passed). Also
fixed from it: `$'...'` quoting, the rule naming every session's scratch, `"$TMPDIR"/x` blocked,
the test now proves the scratch envs are deleted, and `ci.jl test -- contract` says where
contract items run.

### Migration from 0.2.1 (seeded files are not updated by sync)

The sync writes these T3 files: `.claude/hooks/_bash_guard_lib.sh` and `_read_only_roots.sh` (new), `_lib.sh`,
`bash_guard.sh`, `dispatch_limit.sh`, `write_guard.sh`, `.factory-version`, and in packages
`.github/workflows/CI.yml`; plus `.agents/checks.toml` and `scripts/ci.jl`, which are T3 once
the `risk.toml` edit below is made. It seeds `test/contracts/Project.toml` and
`test/contracts/runtests.jl` in packages (T2). Then make these edits by hand (T3: the user, or
a session with `FACTORY_ALLOW_T3=1`), and run `julia scripts/gen.jl`:

- every repo, `risk.toml`: add the 11 globs above to the T3 `[[protected]]` list and reword the
  `adr` comment. The coordinator can take `factory/profiles/coordinator/risk.toml` as is (it is
  its current file plus these lines); an untailored package `risk.toml` can take
  `factory/template/risk.toml` as is.
- packages, `.gitignore`: add `/test/contracts/Manifest*.toml` (and `/test/jet/Manifest*.toml`
  if missing).
- packages, `test/jet/Project.toml`: under `[compat]` add `TOML = "1"` and `julia = "1.12"`.
- packages, `test/runtests.jl`: first line of the filter, `:contract in ti.tags && return false`.
- packages, `test/contracts/Project.toml`: add each upstream of `upstreams.toml` to `[deps]` with
  a `[compat]` bound before its contract tests are written.
- packages synced from 0.2.1 whose `.agents/factory.toml` lacks
  `exclude = ["docs/agent/*", "test/contracts/*.md"]`: add it (ChuiCore, ChuiTypes and
  ChuiFrames already have it).

## 0.2.1 (2026-10-19)

Fixes found running the 0.2.0 tests in the coordinator checkout (540 passed, 2 failed,
2 errored, 1 broken there; 665/665 in `factory/template`), plus the first review of the 0.2.0
contract-usage check (S6). No hook, `settings.json` or workflow changes: the only T3 file a
0.2.0 → 0.2.1 sync writes is the sync record `.factory-version` (every sync does).

- **Tests are hermetic across profiles.** The "package profile seeds no roots" hook test uses its
  own empty roots file instead of the checkout's generated `read-only-roots.txt` (the
  coordinator's lists a read-only reference repo). The repo-wide `check_docs.jl` run and the template's
  `test/contracts/` checks (seeded `USED.md` lists nothing, `upstreams.toml` has
  `[contract_files]`) run only in `factory/template`; a vendored repo already runs both
  scripts on itself in `ci.jl guards`, under its own settings.
- The sync tests no longer report a `@test_skip` ("Broken") in a vendored repo: not running
  there is by design (they test the factory's own copy, which the vendored one matches by hash),
  so an `@info` line says so.
- `check_docs.jl`: in a checkout holding the factory (`factory/MANIFEST.toml`), the backticked
  paths of `factory/*.md` also resolve against `factory/template/` (they name template paths
  such as the template's ADR directory). Removes 4 stale references in the coordinator without
  excluding the factory docs. New blind spot recorded in `.agents/checks.toml`.
- `sync_factory.jl`: a file recorded as managed that the factory now seeds is reported as
  `now-seeded` (it leaves the managed record) instead of `removed-upstream`. Like any seeded
  file it is not updated afterwards, even if the repo never edited it; its `seeded-differs`
  diff shows what the factory's version would change.
- `test_ci.jl`: a checkout without `.factory-version` takes its profile from its shape
  (`factory/MANIFEST.toml` present → coordinator) instead of always `package`.
- **`contract_usage.jl` (review of 0.2.0's S6; each was a false pass):** upstreams named only in
  `[contract_files]` (no URL yet) are grepped too; a commented-out `@testitem` (`#` or
  `#= =#`) is not a test; an ID-named test item without `tags = [:contract]` is an error
  (`ci.jl contracts` runs only those). Also: `Up.:(⨟)` and `using Up: (⨟)` are recognised;
  `#= =#` blocks in code are skipped; `status=stable-ish` is invalid; a fence closes only on its
  own character; a `# ` heading ends an entry; an ID with two entries is an error.
- `check_docs.jl`'s second root applies to backticked paths only, not to Markdown links.
- `/contract-check` names `--contracts`, the upstreams grepped, and a fix for every error the
  script reports; new blind spots (module aliases, docstring mentions, tags on a later line).
  The `contract_steward` body mentions `USED.md` and `contract_usage.jl`, and drafts request
  text instead of writing to the coordinator's `requests/`.

Coordinator follow-ups outside the factory (repo-owned): `.agents/bodies/coord_architect.md`
and `adr/README.md` named the package ADR directory as a repo path; reworded and regenerated.

## 0.2.0 (2026-10-19)

Fixes found while vendoring the coordinator profile.

- **Read-only roots (stricter guard).** `bash_guard.sh` denies any command that would RUN in a
  directory listed in `.agents/factory.toml [bash_guard] read_only_roots`, except cat, head,
  tail, less, grep, rg, find (no -exec/-delete), ls, wc, stat, file, cd/pwd and git
  log/show/diff/status/blame/ls-files. The run directory is the payload cwd, a tracked
  `cd`/`pushd`, `git -C`, `make -C/--directory`, `uv --directory/--project`, or
  `julia --project=`. Catches the 2026-10-19 incident
  (`cd <a read-only reference repo> && uv run ...`). The package profile seeds no roots; the
  coordinator seeds its three read-only reference repos.
- Review fixes (in the same release): `2>&1`/`>&2`/`&>` are no longer split as command
  separators; `git -c a=b -C dir ...` and `git --no-pager -C dir ...` are seen by both the
  read-only and the outside-root checks, and the denylist sees through git global options
  (`git -c x=y reset --hard` is blocked); `cd -P/-L dir`, `env -C dir` / `env --chdir=dir` are
  followed; read-only roots match case-insensitively (APFS); an indented closing fence closes in
  check_docs; `.agents/factory.toml` value types are validated; `dod.jl --adr-dir` works even
  with an unreadable `.factory-version`; sync repairs a mode-only difference.
- `cd` is now tracked across segments for the outside-the-root write check too
  (`cd /outside && touch f` is blocked), and `git -C dir --no-pager log` is recognised as
  read-only. `normpath` in `_lib.sh` no longer turns globbing back on inside the guard.
- **Guards fail closed** when their script is missing: `settings.json` wraps bash_guard,
  write_guard and dispatch_limit in `sh -c '...'` that exits 2 with a message.
- New seeded, T3-protected `.agents/factory.toml` (per-profile defaults) and generated
  `.claude/hooks/read-only-roots.txt`.
- `check_docs.jl` reads `[check_docs]` from `.agents/factory.toml`: `exclude` globs,
  `external` globs of references allowed to be missing, `ignore_fenced`; plus `--config FILE`.
  The coordinator defaults exclude `research/**`, `reference/**`, `prompts/**`, numbered ADRs
  (`adr/0*`) and `factory/template/**`, allow package paths (`docs/agent/*`, `test/*`, `src/*`,
  `ext/*`, `benchmark/*`) and `.claude/worktrees/*`, and ignore fenced blocks (172 stale
  references on the coordinator before, 0 after).
- MANIFEST profiles gain `overlay` and `adr_dir`. The coordinator profile uses
  `profiles/coordinator/` and `adr_dir = "adr"`, and no longer takes `docs/adr/*` (its `adr/`
  is their source). `.factory-version` records `adr_dir`; `dod.jl` checks ADRs there
  (`--adr-dir` overrides).
- `scripts/test/test_ci.jl` is profile-aware: the template and package profile still require
  every ci.jl job to be called; a coordinator checkout requires the workflows it was given to
  exist and call ci.jl, and `guards` to be called.
- **Contract usage by ID (S6), in the format of contracts/README.md.** New
  `scripts/contract_usage.jl [--contracts DIR] [--strict]`, run by `ci.jl guards`; seeded
  `test/contracts/USED.md` (`- <ID> [— note]` lines; package profile); `upstreams.toml` gains
  `[contract_files]` (vendored copies of the upstream contract files, so a fresh clone checks
  itself). Errors: a listed ID without exactly one `@testitem "<ID> ..."`, a contract test item
  for an unlisted ID, `@test_skip`/`@test_broken` in a contract test, an ID missing from the
  contract files or `status=retired`, a used upstream name whose `names:` line maps to an
  unlisted ID, a used upstream without a contract file. Warnings: `status=deprecated`, a used
  name no stable/deprecated `names:` line covers (an error with `--strict`). `/contract-check`
  refreshes the contract files and runs it with `--strict`. Skipped without USED.md (coordinator).
- Denials from a session rooted in `factory/template` say that the template's hooks apply.
  README: profiles, "start sessions and dispatch lanes from the repo root", and how a first
  vendoring writes T3 files.

Migrating from 0.1.0: the sync seeds `.agents/factory.toml`. Seeded files are never updated,
so an existing `risk.toml` does not gain the new T3 glob `.agents/factory.toml`; add it by hand
(T3 edit). In the coordinator, the 0.1.0 copies under `docs/adr/` are reported as
removed-upstream and are not deleted; remove them by hand.

## 0.1.0 (2026-10-19)

- First version, built in Phase L0 from the study in `research/reference-projects.md`.
- Agent registry with 12 roles, prose bodies, `scripts/gen.jl` (`--check`) generating
  Claude and Codex agent files, `AGENTS.md`, the PR template, protected paths, lane limits and
  `docs/CHECK_COVERAGE.md`.
- Hooks (POSIX sh + jq): bash_guard, write_guard, dispatch_limit, lane_ledger,
  teammate_idle, precompact, session_start; wiring in `.claude/settings.json`.
- Commands: intake, lanes, change-review, contract-check, release-check, test-changed; skill
  lane-lifecycle.
- Scripts: lane (worktrees at `<repo>/.worktrees/<lane>`), dod, ratchet, check_docs, ci, bench,
  sync_factory; tests for every script and hook in `scripts/test/`.
- Workflows: CI (lts/stable/pre matrix, coverage, quality, Runic), Docs, Contracts
  (release blocks, main warns), Benchmark, Guards (generated files, ratchets, doc references,
  factory tests, definition of done), CompatHelper, TagBot.
- JET in its own `test/jet/` environment (stable only); doctest/snapshot items stable only.
