# Factory 0.3.0 test-writer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the `test-writer` role and mechanically checked test-first lanes (scripts/tdd.jl)
to the factory template, release it as 0.3.0, then backfill missing tests in the three packages.

**Architecture:** A pure classifier (scripts/_tdd_classify.jl) turns test output plus the
`@testitem` spans of a RED commit into per-item classes. scripts/tdd.jl wraps it in
`red`/`green`/`audit`/`mutate`/`gaps` subcommands and runs tests through `evidence.jl`. `dod.jl`
gains a history-only `tdd` requirement, so CI checks commit order and files without evidence. The
registry, bodies and register get the role and its rules.

**Tech Stack:** Julia 1.13.2 and 1.10.12 (juliaup `julia`, `julia +lts`); TestItemRunner ≥ 1.3.2;
git trailers; the existing factory scripts (`_common.jl`, `evidence.jl`, `dod.jl`, `lane.jl`,
`gen.jl`).

**Spec:** `docs/superpowers/specs/2026-10-26-factory-test-writer-design.md`

## Global Constraints

- Every path below is under `factory/template/` unless it starts with `factory/` or `adr/`.
- Run the tests from the coordinator root, never with a session cwd inside `factory/template`:
  `cd factory/template && julia --startup-file=no scripts/gen.jl --check && julia --startup-file=no scripts/test/runtests.jl`,
  on both `julia` and `julia +lts`.
- `scripts/*.jl` ≤ 400 lines each (`ratchets.toml` size rule).
- Trailer grammar: a line `TDD: <phase>` with phase in
  `stub | red | green | refactor | test-fix | backfill | skip`. A `skip` line must carry a reason
  after the phase.
- Evidence kinds: `red`, `green`, `mutate` (the `evidence.jl` KIND regex already allows them).
- Exit codes, as in the other gate scripts: 0 OK, 1 NOT OK, 2 could not evaluate.
- Edit/Write only on tracked files: no `sed -i`, redirects or heredocs.
- Needs the user's `FACTORY_ALLOW_T3=1` and ADR-0015 before Task 9 writes coordinator T3 paths.
- Reference repos: read only, run nothing there.
- **Dogfood:** for every task, a separate subagent briefed with the draft `test_writer.md` body
  writes the step-1 tests and commits them `TDD: red`. The factory-maintainer then implements.
  Until `tdd.jl red` exists (Task 4), paste the raw failing output instead of its classification.

## Review Focus

1. **A typo'd function name in a red test** (`UndefVarError`) must be WRONG-REASON, never red.
   Task 3 test `"UndefVarError is wrong-reason"`.
2. **A red item that errors in a shared helper file**, outside its span, must be WRONG-REASON, and
   the message must name the helper file and line. Task 3 test `"failure outside any item span"`.
3. **A run killed by the timeout or a signal** (evidence `termsignal` ≠ 0, or no `Test Summary:`)
   must never count as red. Task 4 test `"killed run is not red"`.
4. **A GREEN commit that edits only whitespace in a red test file** still FAILS audit rule 3.
   Task 5 test `"whitespace edit to red test fails"`.
5. **A mutation that breaks parsing** must be WRONG-REASON and not a killed mutant, and the
   scratch copy must be removed even when the run throws. Task 6 tests `"load-breaking mutation"`
   and `"scratch removed on error"`.

---

### Task 1: Record TestItemRunner failure output as fixtures

**Files:**
- Create: scripts/test/fixtures/tdd/ with `assertion-1.13.txt`, `assertion-1.10.txt`,
  `behaviour-methoderror-*.txt`, `undefvar-*.txt`, `loaderror-*.txt`, `parseerror-*.txt`,
  `passed-*.txt`, `helper-failure-*.txt`, plus `scratchpkg/` (the package that produced them)
- Test: none yet. These are inputs for Task 3.

**Interfaces:**
- Produces: fixture files named `<class>-<julia minor>.txt`, each holding the full stdout+stderr
  of `julia scripts/ci.jl test -- item=<name>` from `scratchpkg`. Task 3 reads them.

- [ ] **Step 1:** Build `scratchpkg` (module `TddScratch`, one `function f end` and one
  implemented `g(x) = x + 1`, a `test/helpers.jl` with a failing `@test` in a helper function).
  Give it one `@testitem` per class.
- [ ] **Step 2:** Run each item on `julia` (1.13.2) and `julia +lts` (1.10.12) through
  `evidence.jl` and save the output files. Record the versions of TestItemRunner and Julia at the
  top of each fixture, as a comment line the classifier skips.
- [ ] **Step 3:** Write the format into the spec's UNVERIFIED note: how a failure's `at file:line`
  line is printed and whether the item name appears. Send that as a note to the lead; this lane
  does not edit the spec.
- [ ] **Step 4:** Commit: `test(factory): TestItemRunner failure fixtures for tdd.jl`.

### Task 2: `item=<name>` selection in the seeded runner

**Files:**
- Modify: `test/runtests.jl` (seeded): the filter block
- Test: `scripts/test/test_runtests_template.jl`

**Interfaces:**
- Produces: `select_item(ti_name::AbstractString, ti_tags, args::Vector{String})::Union{Bool,Nothing}`
  between new markers `# --- item selection ---` and `# --- end item selection ---`. It returns
  `true`/`false` when any arg starts with `item=`, else `nothing` (tags decide). Item args and tag
  args may be mixed: the result is the union.

- [ ] **Step 1: Failing tests** (`@testset "item= selection"`):
  `select_item("a b", [:unit], ["item=a b"]) === true`;
  `select_item("c", [:unit], ["item=a b"]) === false`;
  `select_item("c", [:unit], ["unit"]) === nothing`;
  an `item=` match runs even when tagged `:slow`; `:contract` items are never selected (the
  existing rule wins).
- [ ] **Step 2:** The implementer commits a STUB (`function select_item end` in the marked block,
  `TDD: stub`). Run the tests and see 5 `MethodError` failures on `select_item`, which is the
  right reason per spec §3.2. An `UndefVarError` means the stub is missing: fix it first.
- [ ] **Step 3:** Implement the block and call it first in the `@run_package_tests` filter.
  Update the header comment's usage lines.
- [ ] **Step 4:** Run the template tests on both Julia versions: green.
- [ ] **Step 5:** Commit: `feat(factory): runtests item= selection`.

### Task 3: The classifier scripts/_tdd_classify.jl

**Files:**
- Create: scripts/_tdd_classify.jl (module-free include, like `_common.jl`)
- Test: scripts/test/test_tdd.jl (new; add it to `scripts/test/runtests.jl`)

**Interfaces:**
- Produces:
  - `struct ItemSpan; name::String; file::String; first::Int; last::Int; end`
  - `item_spans(text::AbstractString, file::AbstractString)::Vector{ItemSpan}`: every
    `@testitem "name" … begin … end` block, found by `Meta.parseall` with line numbers, never by
    regex on `end`.
  - `changed_items(root, rev)::Vector{ItemSpan}`: items in files changed by `rev` whose span
    intersects a changed hunk of `git diff rev^ rev -U0`.
  - `stub_names(root, revs)::Set{String}`: names from `function NAME end` lines added by the given
    STUB commits.
  - `classify(output::AbstractString, items::Vector{ItemSpan}, stubs::Set{String})::Vector{Pair{String,Symbol}}`:
    item name → `:assertion | :behaviour | :wrong_reason | :passed`, plus `"<file>:<line>" => :collateral`
    entries for failures outside every new item.
  - `red_ok(result)::Bool`: every item is `:assertion` or `:behaviour`, and nothing is
    `:wrong_reason`, `:passed` or `:collateral`.
  - `report(io, result)`: a table with one line per item, `CLASS name (file:line)`.

- [ ] **Step 1: Failing tests**, one `@testset` each, using the Task 1 fixtures and both versions:
  `"assertion is red"`, `"stubbed MethodError is behaviour"`,
  `"MethodError on an undeclared name is wrong-reason"`, `"UndefVarError is wrong-reason"`,
  `"LoadError and ParseError are wrong-reason"`, `"passing item is passed"`,
  `"failure outside any item span"` (helper fixture → `:collateral`, or `:wrong_reason` when it is
  inside no item at all), `"no Test Summary is wrong-reason for every item"`,
  `"item_spans finds nested begin/end correctly"`, `"changed_items ignores untouched items"` (scratch git repo),
  `"stub_names reads only stub commits"`.
- [ ] **Step 2:** Run them and see each fail.
- [ ] **Step 3:** Implement. The rejected-exception list lives in one `const` tuple of regexes.
- [ ] **Step 4:** Tests green on both versions. Check the file is ≤ 400 lines.
- [ ] **Step 5:** Commit: `feat(factory): tdd red-reason classifier`.

### Task 4: `tdd.jl red` and `tdd.jl green`

**Files:**
- Create: scripts/tdd.jl (`module Tdd`, `main(args; io)`, the same shape as `evidence.jl`)
- Test: scripts/test/test_tdd.jl

**Interfaces:**
- Consumes: Task 3's functions; `Evidence.run_evidence(root, kind, cmd; io)`; Task 2's `item=`.
- Produces:
  - `red(root; rev = "HEAD", io)::Int` runs
    `julia scripts/ci.jl test -- item=<n>…` for `changed_items(root, rev)` as evidence kind `red`.
    It appends `report` to the evidence file after the `--- output ---` body, under a line
    `--- tdd ---`, and returns 0 iff `red_ok`.
  - `green(root; io)::Int` takes every item touched by the lane's `red`/`test-fix` commits, runs
    them (all must pass) and then the default suite, as kind `green`.
  - `lane_commits(root, base)::Vector{NamedTuple{(:sha,:phase,:reason,:paths)}}`, oldest first.
    Task 5 and dod.jl use it.
  - `trailer(msg)::Union{Nothing,Tuple{String,String}}`: the phase and reason.

- [ ] **Step 1: Failing tests** on a scratch package built in a temp dir, with a planted timeout
  for one case: `"red on a clean red commit exits 0 and writes red-<sha7>"`,
  `"red with a passing item exits 1 and names it"`, `"red on a commit with no test items exits 2"`,
  `"killed run is not red"` (evidence `termsignal` ≠ 0), `"green after the fix exits 0"`,
  `"trailer parses each phase; skip needs a reason"`, `"lane_commits order and paths"`.
- [ ] **Step 2:** See them fail.
- [ ] **Step 3:** Implement. Reuse `parse_args`, `git`, `merge_base`, `base_ref` and `base_note`
  from `_common.jl`. Do not shell out except through `git()` and `run_evidence`.
- [ ] **Step 4:** Green on both versions.
- [ ] **Step 5:** Commit: `feat(factory): tdd.jl red and green`.

### Task 5: `tdd.jl audit` and `lane new --tdd`

**Files:**
- Modify: scripts/tdd.jl, `scripts/lane.jl` (`cmd_new`: `--tdd`, `--why`)
- Test: scripts/test/test_tdd.jl, `scripts/test/test_lane.jl`

**Interfaces:**
- Produces:
  - `audit_rules(commits, mode::String; evidence::Function)::Vector{String}`, which is pure. It
    returns the problems for spec §4.2 rules 1–5. `evidence(kind, sha)::Bool` is injected, and
    dod.jl passes `(_, _) -> true` and skips rule 4.
  - `audit(root; base, io)::Int` prints one line per problem, then `tdd audit: OK` or
    `tdd audit: NOT OK`.
  - Lane config `branch.<b>.lane-tdd` ∈ `required | refactor | skip` (default `required`) and
    `branch.<b>.lane-tdd-why`. `lane new` rejects another mode, and rejects `skip`/`refactor`
    without `--why`.

- [ ] **Step 1: Failing tests:** `"green before red fails"`, `"green editing a red test fails"`,
  `"whitespace edit to red test fails"`, `"src commit without trailer fails"`,
  `"red commit touching src fails"`, `"missing red evidence fails; dod mode skips rule 4"`,
  `"backfill without mutate evidence fails"`, `"skip trailer without lane mode fails"`,
  `"refactor mode: test change fails, src-only passes"`, `"no src change passes with no trailers"`;
  in `test_lane.jl`: `"--tdd recorded"`, `"bad --tdd mode rejected"`, `"skip without --why rejected"`.
- [ ] **Step 2:** See them fail.
- [ ] **Step 3:** Implement. Rule 3 compares paths, not content, so a whitespace edit fails too.
- [ ] **Step 4:** Green on both versions.
- [ ] **Step 5:** Commit: `feat(factory): tdd audit and lane --tdd`.

### Task 6: `tdd.jl mutate` and `tdd.jl gaps`

**Files:**
- Modify: scripts/tdd.jl (split into scripts/_tdd_backfill.jl if it passes 400 lines)
- Test: scripts/test/test_tdd.jl

**Interfaces:**
- Produces:
  - `mutate(root; item, file, line::Int, from, to, io)::Int`. It makes a scratch copy under
    `.lanes/scratch/mutate-<slug>/`, choosing between `git worktree add --detach` and `cp -R`; the
    test decides, and **worktree is the default if it passes the "scratch removed on error"
    test**. It requires `from` to occur on `line` (else exit 2), runs the item there as evidence
    kind `mutate`, then runs the item on the real tree. It returns 0 iff the mutant run is
    `:assertion`/`:behaviour` and the real run passes. It removes the scratch copy in `finally`.
    The evidence header's `cmd:` line records the mutation.
  - `gaps(root; lcov = nothing, io)::Int` prints `UNTESTED name` for each public name not found as
    a whole word under `test/`, and with lcov, `UNCOVERED file:fn lines a-b`. It always returns 0;
    it is a report, not a gate.

- [ ] **Step 1: Failing tests:** `"killed mutant exits 0"`, `"surviving mutant exits 1"`,
  `"load-breaking mutation is wrong-reason, exits 1"`, `"from not on line exits 2"`,
  `"real tree untouched (git status clean)"`, `"scratch removed on error"`,
  `"gaps lists the untested export only"`, `"gaps reads lcov zero-hit lines"`.
- [ ] **Step 2:** See them fail.
- [ ] **Step 3:** Implement. Also check that local coverage works:
  `CI_COVERAGE=true julia scripts/ci.jl test` on the scratch package, then LCOV through
  CoverageTools in a temp env (`julia --project=<tmp> -e 'using Pkg; Pkg.add("CoverageTools")'`).
  Record the exact commands in tdd.jl's header. If it does not work, `gaps --lcov` takes a CI
  artifact instead, and the header says so.
- [ ] **Step 4:** Green on both versions.
- [ ] **Step 5:** Commit: `feat(factory): tdd mutate and gaps`.

### Task 7: `dod.jl` requirement `tdd` and the seeded `risk.toml`

**Files:**
- Modify: `scripts/dod.jl` (`evaluate` gains `commits = nothing`; `main` builds it with
  `Tdd.lane_commits`), `risk.toml` (seeded: `tdd` in T1, T2, T3 `requires`; scripts/tdd.jl,
  scripts/_tdd_classify.jl, scripts/_tdd_backfill.jl in the T3 globs; the comment block lists
  `tdd`)
- Test: `scripts/test/test_dod.jl`

**Interfaces:**
- Consumes: `Tdd.audit_rules(commits, mode; evidence = (_, _) -> true)`. The mode comes from a
  `TDD-Mode: refactor|skip` line in the PR body if present, else `required`.
- Produces: the requirement `tdd`: `:pass` "no src/ext change", `:pass` "tdd order OK (N
  commits)", or `:fail` with the first problem.

- [ ] **Step 1: Failing tests:** `"tdd passes with no src change"`,
  `"tdd passes on stub-red-green-refactor"`, `"tdd fails on green before red"`,
  `"tdd fails on src commit without trailer"`, `"tdd skip needs a reason"`,
  `"unknown requirement still fails"` (existing behaviour kept).
- [ ] **Step 2:** See them fail.
- [ ] **Step 3:** Implement. Keep `evaluate` pure: commits are passed in, never read inside it.
- [ ] **Step 4:** Green on both versions, and run `julia scripts/dod.jl --base main` on the
  factory lane itself and paste it.
- [ ] **Step 5:** Commit: `feat(factory): dod tdd requirement`.

### Task 8: Registry, bodies, register, docs; VERSION 0.3.0

**Files:**
- Modify: `.agents/agent-registry.toml` (seeded: the `test_writer` entry from spec §2.1, the
  implementer's new `role`/`file_scope`/`scorecard`, the header comment "12" → "13" with ADR-0015)
- Create: .agents/bodies/test_writer.md (spec §2.2 rules 1–8)
- Modify: `.agents/bodies/{implementer,reviewer,law_tester,property_tester,differential_tester}.md`
  (spec §2.3, §4.4)
- Modify: `.agents/checks.toml` (the `tdd` row, spec §4.5, verbatim)
- Modify: `.claude/commands/change-review.md` (run `tdd.jl audit` next to `lane audit`),
  `.claude/skills/lane-lifecycle/` (the turn-taking rule: one agent at a time per lane worktree;
  commit before handover), `CLAUDE.md` (seeded: the Commands lines for `tdd.jl`)
- Modify: `factory/VERSION` → `0.3.0`; `factory/CHANGELOG.md` (a `## 0.3.0` entry with the
  migration list from spec §7.2); `factory/README.md` (the layout row "12 roles" → "13", the
  scripts row gains `tdd`)
- Test: `scripts/test/test_gen.jl`

- [ ] **Step 1: Failing tests:** `"registry has 13 agents including test-writer"`,
  `"implementer file_scope has no test/**"`, `"tdd check row registered and its test exists"`
  (the existing "every guard script registered" test covers `tdd.jl` once it is listed as a guard
  script).
- [ ] **Step 2:** See them fail.
- [ ] **Step 3:** Make the edits. Run `julia scripts/gen.jl` in `factory/template`.
- [ ] **Step 4:** Run the full template suite on `julia` and `julia +lts`, plus `gen.jl --check`,
  and paste both totals through `evidence.jl`.
- [ ] **Step 5: Dogfood measurement.** Count the handoffs and the wall-clock of Tasks 2–7 from the
  lane ledger, and put the per-task numbers in the CHANGELOG entry (spec §6 asks for this).
- [ ] **Step 6:** Commit: `feat(factory): test-writer role, factory 0.3.0`.

### Task 9: Review, ADR, coordinator sync (lead and user)

**Files:**
- Create (lead, outside `factory/**`): `adr/0015-test-first-lanes-and-test-writer.md`, recording
  spec D1, D3, D6 and the open-question answers
- Modify (sync): coordinator managed files; coordinator `risk.toml` T3 globs gain the three tdd
  scripts (a hand edit)

- [ ] **Step 1:** Run the critic and then the reviewer on the factory branch; `tdd.jl audit` on
  the factory lane itself is part of the review.
- [ ] **Step 2:** The user accepts ADR-0015 and sets `FACTORY_ALLOW_T3=1` for the sync session.
- [ ] **Step 3:** Dry run, then paste it:
  `julia factory/template/scripts/sync_factory.jl --from factory --to . --profile coordinator`.
  A conflict goes to the lead, never `--force`.
- [ ] **Step 4:** `--apply`, `julia scripts/gen.jl`, `julia scripts/test/runtests.jl`,
  `julia scripts/check_docs.jl`: all OK.
- [ ] **Step 5:** Commit and merge (a reviewed merge).

### Task 10: Package syncs (one lane per package, in that repo)

- [ ] **ChuiCore.jl**, after v0.0.1 is tagged: sync 0.3.0 (dry run first). Make the hand edits
  from spec §7.2: the registry entry and the implementer scope, `risk.toml` (`tdd` in T1–T3 and
  the new T3 globs), `test/runtests.jl` (`item=` block from Task 2). Run `ci.jl guards`,
  `ci.jl test` on both versions, and `tdd.jl gaps`.
- [ ] **ChuiTypes.jl**: the same, after `feat/phase5` and `feat/p5-*` merge.
- [ ] **ChuiFrames.jl**: the same, after the `feat/p4-*` branches merge.

### Task 11: Backfill missing tests (the user's second request)

One `test-writer` lane per package, created with
`scripts/lane new backfill --prefix test --owns 'test/<new files>,…'`. Use the default
`--tdd required`: the lane touches no `src/`, so `tdd` passes without trailers, but audit rule 4
still requires mutate evidence for each `TDD: backfill` commit. Order: ChuiCore.jl, then ChuiTypes.jl, then ChuiFrames.jl, each only
after its Task 10 lane merged.

- [ ] **Step 1:** `tdd.jl gaps` (and `--lcov` if Task 6 made it work locally).
  Paste the output and rank it by spec §5.1.
- [ ] **Step 2:** For each gap: write the item (one behaviour, a cited source), then
  `tdd.jl mutate --item … --file src/… --line … --from … --to …` until a meaningful mutant is
  killed. Commit with `TDD: backfill` (a few items per commit).
- [ ] **Step 3:** A disagreement with the docs becomes `@test_broken` with a `BUG:` comment and a
  report line (spec §5.3).
- [ ] **Step 4:** Run `tdd.jl audit` (backfill commits each need their mutate evidence) and the
  full suite on both versions, and report the measured line coverage.
- [ ] **Step 5:** The reviewer, then the merge. The lead puts the coverage-floor proposal (measured
  − 1 point) to the user (T3 `ratchets.toml`).
