# Factory 0.3.0 test-writer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the `test-writer` role and mechanically checked test-first lanes (scripts/tdd.jl) to
the factory template, release them as 0.3.0, then backfill the missing tests in the three packages.

**Architecture:** The work is split into four files:

- a pure classifier (scripts/_tdd_classify.jl) turns test output plus the requested `@testitem`
  spans into per-item classes;
- pure history rules (scripts/_tdd_history.jl) check commit order and paths; `dod.jl` includes it
  too;
- scripts/_tdd_backfill.jl holds `mutate` and `gaps`;
- scripts/tdd.jl wires them into subcommands and runs tests through `evidence.jl`.

The seeded runner gains `item=` selection and a `TDD_MATCHED` record of what it actually ran.

**Tech Stack:** Julia 1.13.2 and 1.10.12 (juliaup `julia` and `julia +lts`), TestItemRunner ≥ 1.3.2,
git trailers, and the existing factory scripts (`_common.jl`, `evidence.jl`, `dod.jl`, `gen.jl`).

**Spec:** `docs/superpowers/specs/2026-10-26-factory-test-writer-design.md` (revision 2)

## Global Constraints

- Paths are under `factory/template/` unless they start with `factory/` or `adr/`.
- Run the tests from the coordinator root, never with a session cwd inside `factory/template`:
  `cd factory/template && julia --startup-file=no scripts/gen.jl --check && julia --startup-file=no scripts/test/runtests.jl`,
  on both `julia` and `julia +lts`. Paste both.
- `scripts/*.jl` ≤ 400 lines each.
- Phases: `stub | red | green | refactor | test-fix | test-refactor | backfill`.
  - A phase is set by a `TDD: <phase>` trailer.
  - The mode is set by a `TDD-Mode: required|refactor|skip — <reason>` trailer on the lane's oldest
    non-merge commit. Absent means `required`.
  - The reason is required for `refactor` and `skip`.
- Evidence kinds:
  - `red` and `green`;
  - `mutate-<slug>` and `mutexp-<slug>`, where slug = lowercase name, runs of non-`[a-z0-9]`
    replaced by `-`, cut to 24 characters, then `-` and 8 hex digits of the name's SHA-1. The whole
    kind is at most 40 characters.
- Classes: `ASSERTION | BEHAVIOUR | WRONG-REASON | PASSED | NOT-RUN | COLLATERAL`, with the
  `HELPER` flag (spec §3.3, verbatim).
- Exit codes: 0 OK, 1 NOT OK, 2 could not evaluate (also used for a dirty tree, a bad argument, or
  no `@testitem` in a red commit).
- Edit/Write only on tracked files. No `sed -i`, redirects or heredocs.
- TDD lanes merge `main` in and never rebase.
- Reference repos are read only: run nothing there.
- **Dogfood (spec §7.4):** for each task, a separate subagent briefed with the draft `test_writer`
  body writes the step-1 tests. Paste the raw failing output. The factory's tests are `@testset`s
  and the factory has no `src/`, so `tdd.jl red`/`audit` cannot check this lane. Say so in the
  report.

## Review Focus

1. **A typo under `@test_throws`** (`@test_throws ArgumentError gg(1)`, which prints
   `Thrown: UndefVarError`) must be WRONG-REASON. Task 3: `"test_throws hiding UndefVarError is wrong-reason"`.
2. **A vacuous run** (a misspelt `item=` name, which gives `Total 0` and exit 0) must fail green and
   mutate. Tasks 2 and 4: `"TDD_MATCHED records selected names"`, `"green with an unmatched name is NOT-RUN"`.
3. **A STUB commit that hides an implementation** inside a `struct` (an inner constructor, or
   `Base.@kwdef`) must fail H5. Task 5: `"stub with inner constructor fails H5"`,
   `"stub with @kwdef fails H5"`.
4. **Two characterization items mutated at one sha** must give two evidence files. Task 6:
   `"two items at one sha give two files"`.
5. **A `test-fix` commit that also touches `src/`** must fail H3, even though `test-fix` is a
   test-writer phase. Task 5: `"test-fix touching src fails H3"`.

---

### Task 0: ADR-0015 and the user's answers (lead and user, before any code)

**Files:** Create (lead, coordinator): `adr/0015-test-first-lanes-and-test-writer.md`

- [ ] **Step 1:** The lead drafts ADR-0015 from spec D1, D3, D4 and D6, and lists the 8 questions
  from spec §9 with their recommendations.
- [ ] **Step 2:** The critic reviews the ADR.
- [ ] **Step 3:** ★ The user answers §9 and accepts ADR-0015. Record the answers in the ADR. Any
  answer that differs from the spec's recommendation goes back to this spec lane first.
- [ ] **Step 4:** The user sets `FACTORY_ALLOW_T3=1` for the session that runs Task 9. Tasks 1–8
  write only `factory/**`, which is T2 in the coordinator.

### Task 1: Failure-output fixtures

**Files:**
- Create: scripts/test/fixtures/tdd/ holding:
  - `scratchpkg/`: the critic's `TddScratch` items, extended;
  - `<case>-1.13.txt` and `<case>-1.10.txt` for each case.

**Interfaces:**
- Produces: the fixture files Task 3 reads. Each starts with a comment line naming the Julia and
  TestItemRunner versions. The cases are:
  - `assert`, `stub in test`, `stub outside test`, `typo`, `typo outside`, `helper`, `passes`,
    `throws wrong`, `throws typo`, `new method on existing g`, `nested` (the critic's);
  - plus `parse error` (an item file that does not parse), `setup module` (an item using a
    `@testmodule` that a commit changes), `none` (`item=nosuch`), and `killed` (an evidence file
    with `termsignal: 15`).

- [ ] **Step 1:** Copy the critic's `.lanes/scratch/tw-critic/TddScratch` from the main checkout
  into the fixture directory and add the four new cases.
- [ ] **Step 2:** Run each case on 1.13.2 and on 1.10.12
  (`JULIA_PKG_OFFLINE=true julia --project=. -e 'using Pkg; Pkg.test(test_args=ARGS)' -- "item=<case>"`)
  and save the outputs.
- [ ] **Step 3:** Check the fixtures against spec §3.3: the header regex
  `^(.+): (Test Failed|Error During Test) at (.+):(\d+)$` must match every failure header, and only
  those. Report any difference to the lead; this lane does not edit the spec.
- [ ] **Step 4:** Commit: `test(factory): TestItemRunner failure fixtures for tdd.jl`.

### Task 2: `item=` selection and `TDD_MATCHED` in the seeded runner

**Files:** Modify `test/runtests.jl` (seeded; a new marked block). Test: `scripts/test/test_runtests_template.jl`.

**Interfaces:**
- Produces:
  - `select_item(name::AbstractString, tags, args::Vector{String}; stable::Bool)::Union{Bool,Nothing}`.
    `:contract` gives false; with `stable == false`, `:doctest`/`:snapshot` give false; else an
    `item=` match gives true; else a non-match when any `item=` arg exists gives false; else
    `nothing`, and the tags decide.
  - `record_match(name, env = ENV)`, which appends `name * "\n"` to `env["TDD_MATCHED"]` when that
    variable is set.
  - Both sit between `# --- item selection ---` and `# --- end item selection ---`.

- [ ] **Step 1: Failing tests:**
  - `"item= selects by name with spaces"`
  - `"non-matching item is not selected"`
  - `"no item= args defer to tags"`
  - `"contract never selected by name"`
  - `"doctest by name skipped when not stable"`
  - `"TDD_MATCHED records selected names"`
  - `"TDD_MATCHED unset writes nothing"`
- [ ] **Step 2:** The implementer commits a STUB (`function select_item end`,
  `function record_match end`). Run the tests: there should be 7 `MethodError` failures.
- [ ] **Step 3:** Implement, and call both first in the `@run_package_tests` filter. Update the
  header usage lines.
- [ ] **Step 4:** Tests green on both versions.
- [ ] **Step 5:** Commit: `feat(factory): runtests item= selection and TDD_MATCHED`.

### Task 3: The classifier (scripts/_tdd_classify.jl)

**Files:** Create scripts/_tdd_classify.jl. Test: scripts/test/test_tdd.jl (new; registered in
`scripts/test/runtests.jl`).

**Interfaces:**
- Produces:
  - `struct ItemSpan; name::String; file::String; first::Int; last::Int; setup::Vector{String}; end`.
  - `item_spans(text, file)::Vector{ItemSpan}`. It finds every `@testitem` through `Meta.parseall`
    line info, with `setup` read from `setup = [...]`.
  - `module_names(text)::Vector{String}`: the `@testmodule` and `@testsnippet` names.
  - `requested(root, rev)::NamedTuple{(:red, :must_pass), Tuple{Vector{ItemSpan}, Vector{ItemSpan}}}`.
    `red` holds the items whose span `rev` touched or added (`git diff -U0 rev^ rev`). `must_pass`
    holds the unchanged items whose `setup` names a module that `rev` changed.
  - `headers(output)::Vector{NamedTuple{(:prefix, :kind, :file, :line, :exc, :thrown, :helper)}}`.
    Only header lines are read. `exc` is the exception line with one `LoadError: ` prefix stripped;
    `thrown` is the `Thrown:` line if there is one; `helper` is the first stacktrace frame under
    `test/` when it is outside the header's file.
  - `classify(output, red::Vector{ItemSpan}, must_pass::Vector{ItemSpan}, matched::Set{String}; termsignal = 0)::Vector{Pair{String, Symbol}}`.
    It uses the spec §3.3 table and returns `Symbol`s: `:assertion`, `:behaviour`, `:wrong_reason`,
    `:passed`, `:not_run`, `:collateral`.
  - `red_ok(result)::Bool`.
  - `report(io, result, hdrs)` prints one line per item, and `HELPER file:line` where it applies.

- [ ] **Step 1: Failing tests** (fixtures from Task 1, both versions):
  - `"assert is ASSERTION"`
  - `"stub in test is BEHAVIOUR"`
  - `"stub outside test is BEHAVIOUR (LoadError prefix stripped)"`
  - `"new method on existing g is BEHAVIOUR"`
  - `"typo and typo outside are WRONG-REASON"`
  - `"test_throws hiding UndefVarError is wrong-reason"`
  - `"throws wrong with Thrown: MethodError is ASSERTION"`
  - `"helper is BEHAVIOUR with HELPER flag"`
  - `"nested testset prefix still attributed by span"`
  - `"Some tests did not pass line ignored"`
  - `"parse error is WRONG-REASON"`
  - `"passes is PASSED"`
  - `"unmatched requested item is NOT-RUN"`
  - `"failure in a must_pass item is COLLATERAL"`
  - `"header outside every span is WRONG-REASON"`
  - `"no Test Summary is WRONG-REASON"`
  - `"termsignal 15 is WRONG-REASON for all"`
  - `"item_spans finds nested begin/end"`
  - `"requested: setup-module change adds must_pass items"` (on a scratch git repo)
- [ ] **Step 2:** STUB commit (the names above as `function … end`, plus the struct). Run the
  tests: they should fail with `MethodError` or `ASSERTION`.
- [ ] **Step 3:** Implement. The rejected exception and thrown patterns are one `const` tuple.
- [ ] **Step 4:** Green on both versions; file ≤ 400 lines.
- [ ] **Step 5:** Commit: `feat(factory): tdd classifier`.

### Task 4: `tdd.jl red` and `tdd.jl green`

**Files:** Create scripts/tdd.jl (`module Tdd`, `main(args; io)`). Test: scripts/test/test_tdd.jl.

**Interfaces:**
- Consumes:
  - Task 3;
  - `Evidence.run_evidence(root, kind, cmd; io)`;
  - Task 2's `item=` and `TDD_MATCHED`.
- Produces:
  - `red(root; rev = "HEAD", io)::Int`. It exits 2 on a dirty tree, or when `rev`'s phase is not
    `red`/`test-fix`, or when `rev` touched no item. It runs `ci.jl test -- item=…` for
    `red ∪ must_pass` with `TDD_MATCHED` set, as kind `red`. It appends `--- tdd ---` and the
    report, and returns 0 iff `red_ok`.
  - `green(root; base = "main", io)::Int`. It runs the `red` items of every `red`/`test-fix` lane
    commit. All of them must be matched and pass, with a total of at least their count. Then it
    runs the default suite. The kind is `green`.

- [ ] **Step 1: Failing tests** (scratch package in a temp dir):
  - `"red on a clean red commit exits 0 and writes red-<sha7>"`
  - `"red with a passing item exits 1 and names it"`
  - `"red on a dirty tree exits 2"`
  - `"red on a commit with no items exits 2"`
  - `"red on a green commit exits 2"`
  - `"killed run is not red"`
  - `"green after the fix exits 0"`
  - `"green with an unmatched name is NOT-RUN"`
  - `"green fails when the default suite fails"`
- [ ] **Step 2:** STUB, then see the tests fail.
- [ ] **Step 3:** Implement with `_common.jl` (`parse_args`, `git`, `merge_base`, `base_ref`,
  `base_note`).
- [ ] **Step 4:** Green on both versions.
- [ ] **Step 5:** Commit: `feat(factory): tdd.jl red and green`.

### Task 5: History rules and `tdd.jl audit`

**Files:** Create scripts/_tdd_history.jl. Modify scripts/tdd.jl. Test: scripts/test/test_tdd.jl.

**Interfaces:**
- Produces:
  - `struct LaneCommit; sha::String; phase::Union{Nothing, String}; mode::Union{Nothing, Tuple{String, String}}; paths::Vector{String}; end`.
  - `lane_commits(root, base)::Vector{LaneCommit}`, from `git rev-list --no-merges --reverse`.
  - `trailers(msg)::NamedTuple{(:phase, :mode)}`.
  - `history_rules(commits; stub_ok::Function)::Vector{String}`. It is pure and checks spec §4.2
    H1–H8. `stub_ok(sha)::Bool` runs H5; the callers inject it.
  - `stub_declares_only(root, sha)::Bool`, which compares the top-level expressions of the parent
    and the commit for each changed src/ext file.
  - `evidence_rules(root, commits)::Vector{String}`, for E1–E4.
  - `audit(root; base, io)::Int`, which prints the problems, then `tdd audit: OK` or `NOT OK`.

- [ ] **Step 1: Failing tests** (synthetic `LaneCommit` lists unless noted):
  - `"no code change passes with no trailers"`
  - `"code commit without trailer fails H1"`
  - `"required lane with only refactor/stub src commits fails"` (H2, the critic's B1 reproducer)
  - `"stub editing test fails H3"`
  - `"green editing any test file fails H4"`
  - `"test-fix touching src fails H3"`
  - `"stub with a method body fails H5"`
  - `"stub with inner constructor fails H5"`
  - `"stub with @kwdef fails H5"`
  - `"function-end + struct fields + export passes H5"` (the H5 cases run on a scratch git repo)
  - `"green before red fails H6"`
  - `"two greens for one red fail H6"`
  - `"refactor before any green fails H6"`
  - `"lane ending on red fails H7"`
  - `"refactor mode: red commit fails H8"`
  - `"skip mode without reason fails H8"`
  - `"skip mode with reason passes"`
  - `"merge commits ignored"` (scratch repo with `git merge main`)
  - `"missing red evidence fails E1"`
  - `"refactor mode needs green at merge base (E2)"`
  - `"backfill item without mutate evidence fails E3"`
  - `"@test_broken-only item exempt from E3"`
  - `"dirty evidence fails E4"`
- [ ] **Step 2:** STUB, then see the tests fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Green on both versions.
- [ ] **Step 5:** Commit: `feat(factory): tdd history rules and audit`.

### Task 6: `mutate` and `gaps` (scripts/_tdd_backfill.jl)

**Files:** Create scripts/_tdd_backfill.jl. Modify scripts/tdd.jl. Test: scripts/test/test_tdd.jl.

**Interfaces:**
- Produces:
  - `slug(name)::String`, following the Global Constraints rule.
  - `scratch(root)::String`. It creates `.lanes/scratch/mutate/` once (`git worktree add --detach`),
    checks out HEAD's sha there, and copies `Manifest.toml` and `Manifest-v1.10.toml` in when they
    exist.
  - `mutate(root; item, src = nothing, expect = nothing, from, to, io)::Int`. Exactly one of `src`
    or `expect` (`"F:LINE"`) is given. It exits 2 if the tree is dirty or `from` is not on the line.
    It runs the mutant in the scratch copy, restoring the file in `finally`, then runs the real
    tree. The kind is `mutate-<slug>` or `mutexp-<slug>`, and it returns 0 iff the mutant is
    matched with an `ASSERTION`/`BEHAVIOUR` failure not under `@test_broken`, and the real run is
    matched and passes.
  - `gaps(root; lcov = nothing, io)::Int`. It prints `UNTESTED name` lines and, with lcov,
    `UNCOVERED file:fn lines a-b`. It always returns 0, and on Julia < 1.11 it prints `NOT RUN:
    needs Base.ispublic (Julia >= 1.11)` and returns 2.

- [ ] **Step 1: Failing tests:**
  - `"slug is <=33 chars and stable"`
  - `"two items at one sha give two files"`
  - `"killed mutant exits 0"`
  - `"surviving mutant exits 1"`
  - `"load-breaking mutation is wrong-reason, exits 1"`
  - `"from not on line exits 2"`
  - `"dirty tree exits 2"`
  - `"scratch file restored after a throw"`
  - `"real tree untouched (git status clean)"`
  - `"mutexp writes its own kind"`
  - `"unmatched item name is NOT-RUN"`
  - `"gaps lists the untested public name only"`
  - `"gaps reads lcov zero-hit lines"`
  - `"gaps on 1.10 exits 2 NOT RUN"`
- [ ] **Step 2:** STUB, then see the tests fail.
- [ ] **Step 3:** Implement. Then try local coverage on the scratch package
  (`CI_COVERAGE=true julia scripts/ci.jl test`, then CoverageTools LCOV in a temp env). Write the
  working commands, or "use the CI artifact", into tdd.jl's header.
- [ ] **Step 4:** Green on both versions. Time one mutant on the scratch package (cold and warm)
  and paste the numbers.
- [ ] **Step 5:** Commit: `feat(factory): tdd mutate and gaps`.

### Task 7: `dod.jl` requirement `tdd` and the seeded `risk.toml`

**Files:**
- Modify `scripts/dod.jl`: `evaluate` gains `commits = nothing` and `stub_ok`; `main` builds them
  with `lane_commits` and `stub_declares_only`.
- Modify `risk.toml` (seeded): add `tdd` to the T1, T2 and T3 `requires`; add the four tdd scripts
  to the T3 globs; add the comment for `tdd`.
- Test: `scripts/test/test_dod.jl`.

**Interfaces:**
- Consumes: `history_rules`. Produces requirement `tdd`: `:pass` "no src/ext change" or
  "tdd history OK (N commits, mode M)", else `:fail` with the first problem.

- [ ] **Step 1: Failing tests:**
  - `"tdd passes with no src change"`
  - `"tdd passes on stub-red-green-refactor"`
  - `"tdd fails on refactor-only required lane"`
  - `"tdd fails on green editing a test"`
  - `"tdd reads mode from the first commit's trailer"`
  - `"unknown requirement still fails"`
- [ ] **Step 2:** See the tests fail.
- [ ] **Step 3:** Implement. `evaluate` stays pure.
- [ ] **Step 4:** Green on both versions, then run `julia scripts/dod.jl --base main` in the
  factory lane and paste it.
- [ ] **Step 5:** Commit: `feat(factory): dod tdd requirement`.

### Task 8: Registry, bodies, register, skill, docs; VERSION 0.3.0

**Files:**
- `.agents/agent-registry.toml` (seeded): the spec §2.1 entry; the implementer's role,
  file_scope and scorecard; the header "12" becomes "13" with a citation of ADR-0015.
- .agents/bodies/test_writer.md (new): spec §2.2 rules 1–9.
- `.agents/bodies/{implementer,reviewer,law_tester,property_tester,differential_tester}.md`:
  spec §2.3 and §4.5.
- `.agents/checks.toml`: the spec §4.6 row, verbatim.
- `.claude/commands/change-review.md`: run `tdd.jl audit --base <base>` and `dod.jl --base <base>`
  next to `lane audit`.
- `.claude/skills/lane-lifecycle/`: TDD lanes take turns (one agent at a time; commit before
  handover); they merge `main` and never rebase.
- `CLAUDE.md` (seeded): the `tdd.jl` command lines.
- `factory/VERSION`: `0.3.0`.
- `factory/CHANGELOG.md`: the `## 0.3.0` entry with the spec §7.2 migration list.
- `factory/README.md`: the roles row (12 becomes 13) and the scripts row (add `tdd`).
- Test: `scripts/test/test_gen.jl`.

- [ ] **Step 1: Failing tests:**
  - `"registry has 13 agents including test-writer"`
  - `"implementer file_scope has no test/**"`
  - `"tdd check row registered and its test exists"`
- [ ] **Step 2:** See the tests fail.
- [ ] **Step 3:** Make the edits, then run `julia scripts/gen.jl` in `factory/template`.
- [ ] **Step 4:** Run the full template suite and `gen.jl --check` on both versions, through
  `evidence.jl`, and paste the totals.
- [ ] **Step 5:** Measure the dogfood cost: count the handoffs and the wall-clock per task for
  Tasks 2–7 from the lane ledger, and put the numbers in the CHANGELOG entry.
- [ ] **Step 6:** Commit: `feat(factory): test-writer role, factory 0.3.0`.

### Task 9: Review and coordinator sync

- [ ] **Step 1:** The critic, then the reviewer, on the factory branch. The report says that
  `tdd.jl audit` on this lane is vacuous (spec §7.4), and that the dogfood reds were pasted raw.
- [ ] **Step 2:** Dry run, and paste it:
  `julia factory/template/scripts/sync_factory.jl --from factory --to . --profile coordinator`.
  A conflict goes to the lead; never `--force`.
- [ ] **Step 3:** `--apply` (with the user's `FACTORY_ALLOW_T3=1` from Task 0). Hand-edit the
  coordinator `risk.toml` T3 globs (add the four tdd scripts). Run `julia scripts/gen.jl`,
  `julia scripts/test/runtests.jl` and `julia scripts/check_docs.jl`: all must be OK.
- [ ] **Step 4:** Commit, review, merge.

### Task 10: Package syncs (one lane per package, in that repo)

- [ ] **ChuiCore.jl**, after v0.0.1 is tagged:
  - sync 0.3.0 (dry run first);
  - make the hand edits from spec §7.2: the registry, `risk.toml`, and the `test/runtests.jl`
    selection block from Task 2;
  - run `ci.jl guards`, and `ci.jl test` on both versions;
  - run `tdd.jl gaps` on 1.13.
- [ ] **ChuiTypes.jl**: the same, after `feat/phase5`, `feat/p5-perf` and `feat/p5-ttfx` merge.
- [ ] **ChuiFrames.jl**: the same, after the `feat/p4-*` branches merge.

### Task 11: Backfill missing tests (the user's second request)

One `test-writer` lane per package, in this order: ChuiCore.jl, ChuiTypes.jl, ChuiFrames.jl, each
after its Task 10 lane merges. Create it with `scripts/lane new backfill --prefix test --owns '<test files>'`.
No `TDD-Mode:` is needed, because the lane changes no code (H1). E3 still applies.

- [ ] **Step 1:** Run `tdd.jl gaps` on 1.13 (and with `--lcov` if Task 6 made that work locally).
  Paste the output, ranked per spec §5.1.
- [ ] **Step 2: Measure first.** Take one area of about 10 items:
  - write the items and commit them with `TDD: backfill`;
  - run `tdd.jl mutate` for each, against that commit;
  - time the runs, and project the total for the package.

  If the projection is over 2 h, stop at a ★ checkpoint: the lead splits the work into area lanes,
  or the user accepts the cost.
- [ ] **Step 3:** For the rest, repeat: commit a few items, then mutate each one. Use `--src` by
  default, and `--expect` only with a reason in the report.
- [ ] **Step 4:** Docs and behaviour disagree: use `@test_broken` with a `BUG:` comment, and add a
  report line.
- [ ] **Step 5:** Run `tdd.jl audit --base main` and the full suite on both versions, and report
  the measured line coverage.
- [ ] **Step 6:** Reviewer, then merge. The lead proposes the coverage floor (measured − 1 point)
  to the user.
