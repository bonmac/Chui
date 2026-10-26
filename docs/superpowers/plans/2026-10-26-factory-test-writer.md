# Factory 0.3.0 test-writer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate the tester's context from the implementer's, so that TDD tests come from the spec
and not from the code. The parts:

- two role subagents whose tools are limited by frontmatter;
- a multi-checkout `tdd_boundary` hook (path allowlists, Bash allowlist, commit guard);
- per-role git authors;
- as the evidence: tdd.jl's red classifier, history rules and audit.

Release it as factory 0.3.0, then backfill missing tests in the three packages under the same
separation.

**Architecture:**

- A pure classifier (scripts/_tdd_classify.jl) turns test output plus the requested `@testitem`
  spans into per-item classes.
- Pure history rules (scripts/_tdd_history.jl, which dod.jl includes too) check order, paths,
  modes and authors.
- scripts/_tdd_backfill.jl holds `mutate` and `gaps`.
- scripts/tdd.jl wires the subcommands, plus `api` and `brief`.
- The seeded runner gains `item=` selection and a `TDD_MATCHED` record.
- Three managed hook files (.claude/hooks/tdd_boundary.sh, .claude/hooks/_tdd_commit_guard.sh and
  .claude/hooks/tdd_commit_post.sh) enforce the boundary for subagents in package worktrees under
  the coordinator session (topology (a)).

**Tech Stack:** Julia 1.13.2 and 1.10.12 (juliaup `julia`, `julia +lts`); TestItemRunner ≥ 1.3.2;
POSIX sh + jq hooks; git trailers; the existing factory scripts.

**Spec:** `docs/superpowers/specs/2026-10-26-factory-test-writer-design.md` (revision 6)

## Global Constraints

- Paths are under `factory/template/` unless they start with `factory/`, `adr/` or `<root>`.
- Run the tests from the coordinator root, never with the session cwd in `factory/template`:
  `cd factory/template && julia --startup-file=no scripts/gen.jl --check && julia --startup-file=no scripts/test/runtests.jl`
  on `julia` and `julia +lts`. Paste both.
- Size limits: `scripts/*.jl` ≤ 400 lines; `.claude/hooks/*.sh` ≤ 150 lines.
- Phases are `stub | red | green | refactor | test-fix | test-refactor | backfill`, written as the
  trailer `TDD: <phase>`. The mode trailer `TDD-Mode: required|refactor|skip — <reason>` goes only
  on a lead-authored commit.
- Authors:
  - `test-writer <test-writer@factory.invalid>`;
  - `implementer <implementer@factory.invalid>`;
  - `lead <lead@factory.invalid>`: only the main session, the caller with no `agent_type`, may use
    it.
- **The dispatcher is the lead.** "The brief is the only channel." `mutate` runs in a separate
  general-purpose `mutator` subagent.
- **Dispatch form:** an Agent call with `subagent_type` test-writer or implementer, no `team_name`
  and no fork. A `name` (`tw-<lane>-<task>`/`impl-<lane>-<task>`) is added only if Task 0 allows
  it.
- **Brief header:**
  `<!-- tdd-brief role=<role> lane=<lane> checkout=<abs path> head=<sha> -->`. Briefs are saved
  under the owning repo's main `.lanes/briefs/<lane>/`.
- Evidence kinds: `red`, `green`, `mutate-<slug>` and `mutexp-<slug>`. The slug is the lowercased
  name with runs of non-`[a-z0-9]` replaced by `-`, cut to 24 characters, then `-` and 8 hex digits
  of the name's SHA-1.
- Classes: `ASSERTION | BEHAVIOUR | WRONG-REASON | PASSED | NOT-RUN | COLLATERAL`, plus the flag
  `HELPER` (spec §3.3). `BOUNDARY` is deferred (spec §11).
- Exit codes: 0 OK, 1 NOT OK, 2 could not evaluate (also a dirty tree, a bad argument, or a red
  commit with no `@testitem`).
- Edit/Write only on tracked files. TDD lanes merge `main` in and never rebase. Reference repos are
  read only.
- **Dogfood:** the factory's tests are `@testset`s and the factory has no `src/`, so tdd.jl cannot
  check this lane. For Tasks 2–8:
  - a fresh subagent briefed only with the task text, the spec and the Interfaces block writes the
    step-1 tests;
  - the factory-maintainer implements;
  - paste the raw failing output.

  This is process discipline, not a mechanical check.

## Review Focus

1. **A stub that adds `export g` and `function g end` inside the `module` block** must pass H5.
   It failed in the critic's probe. Task 5: `"stub adding export + function-end inside the module block passes H5"`.
2. **The lead committing as `test-writer` through `GIT_AUTHOR_NAME=…` or `git config user.*`**
   must be denied. Task 8: `"lead commit with env role author denied"`, `"lead commit after git config role identity denied"`.
3. **A test-writer reading a transcript or the depot copy** must be denied by the allowlist. Task 8:
   `"test-writer Read ~/.claude/projects transcript denied"`, `"test-writer Read ~/.julia/packages denied"`.
4. **A vacuous run** (a misspelt `item=`; `Total 0`) must fail green and mutate. Tasks 2 and 4:
   `"TDD_MATCHED records selected names"`, `"green with an unmatched name is NOT-RUN"`.
5. **A skip-mode lane** must fail dod unless its mode commit is authored `lead <lead@factory.invalid>`
   and has a reason. Task 7: `"skip by a role-authored mode commit fails"` and
   `"skip by a general-purpose-authored mode commit fails"`.
6. **`git add test/x && git commit --amend --no-edit` by the implementer or the lead** must not
   yield a test-writer commit that passes. Task 8: `"amend keeps source author: denied"`, `"-C HEAD denied"`,
   `"post-commit violation recorded"`. Task 5: `"role commit without tdd-commit record fails E5"`.
7. **A stub that adds a name to `@compat public …`** must pass H5. Task 5:
   `"stub adding a name to @compat public passes H5"`.

---

### Task 0: ADR-0015, the user's answers, and the `agent_type` probe in topology (a)

**Files:** `adr/0015-test-writer-role-and-test-first-lanes.md`, drafted as Proposed in the spec
lane. Temporary (removed in step 6): a `tw-probe` entry in `<root>/.agents/agent-registry.toml`
(with its body `<root>/.agents/bodies/tw_probe.md`), the `<root>/.claude/agents/tw-probe.md` that
`julia scripts/gen.jl` renders from it (never hand-written: CLAUDE.md), and a logging hook entry in
`<root>/.claude/settings.json`. All are T3.

**Prerequisite:** factory 0.2.8 (the dispatch_limit fix, spec §13) is merged in `factory/`.

- [x] **Step 1:** ADR-0015 drafted from spec D0, D1, D3, D4, D6, D7 and §8 (spec lane, 2026-10-26).
- [x] **Step 2:** The user answered spec §8 on 2026-10-26, all six questions, recorded in spec §8
  and the ADR.
- [x] **Step 3:** ★ The user accepts ADR-0015 at the spec branch's merge, and sets
  `FACTORY_ALLOW_T3=1` for the probe and Task 10.
- [x] **Step 4: The probe, in the real topology.**
  - Add the temporary `tw-probe` agent (tools: Read, Bash) as an `[[agents]]` entry in
    `<root>/.agents/agent-registry.toml` plus its body `<root>/.agents/bodies/tw_probe.md`, then
    run `julia scripts/gen.jl` in `<root>` to render `<root>/.claude/agents/tw-probe.md`.
  - Add to `<root>/.claude/settings.json` a PreToolUse hook on `Read|Bash|Agent|Task`, plus
    SubagentStart and SubagentStop hooks, that append their JSON input to
    `<root>/.lanes/scratch/probe.jsonl`.
  - From the lead's coordinator session, which today runs its agents as in-process teammates,
    dispatch **twice**, each with a brief telling the agent to `Read`
    `<root>/ChuiCore.jl/.worktrees/<probe-lane>/test/runtests.jl` and run
    `git -C <that worktree> status`. Create the probe lane with ChuiCore's `scripts/lane new probe`.
    1. an **unnamed** Agent call: `subagent_type: tw-probe`, no `name`, no `team_name`;
    2. a **named** Agent call: the same, with `name: tw-probe-named`.
- [x] **Step 5:** Paste the log lines and record, for each dispatch, whether its PreToolUse
  payloads carry `agent_type: "tw-probe"` and an `agent_id`.
  - **Pass** when the unnamed dispatch carries `agent_type: "tw-probe"` and `tool_input.file_path`
    is the worktree path. This rests on PreToolUse alone.
  - The named result decides whether TDD dispatches may use `name`: only if it carries
    `agent_type` too.
  - Report missing or mismatched SubagentStart/Stop events, but do not stop on them (spec §13).
  - If the unnamed dispatch lacks `agent_type`, stop at a ★: Task 8 needs another source for the
    role.
- [x] **Step 6:** Remove the `tw-probe` registry entry and its body, run `julia scripts/gen.jl` in
  `<root>`, remove the hook entries from `<root>/.claude/settings.json`, and delete the probe lane.
  Check, and paste the output of:
  - `ls <root>/.claude/agents/tw-probe.md` must fail ("No such file or directory"). gen.jl's
    orphan check flags only files carrying the GENERATED marker, so `gen.jl --check` alone does
    not prove the cleanup;
  - `grep -n tw.probe <root>/.agents/agent-registry.toml <root>/.claude/settings.json` must print
    nothing;
  - `julia scripts/gen.jl --check` in `<root>` must be OK.

**Task 0 result (2026-10-27, the lead, after the user's T3 restart; steps 3–6 done):**
- **Deviation:** an agent type added mid-session is not loaded ("Agent type 'tw-probe' not found"),
  so the probe used the existing custom read-only agent `reviewer`. The question is the same: does
  a custom subagent's PreToolUse payload carry its `agent_type`? The tw-probe stanza was still added
  and removed. Consequence for Tasks 9–10: the new test-writer/implementer agents become
  dispatchable only after a session restart.
- **Unnamed** (`subagent_type: reviewer`, no name): Read and Bash payloads carry
  `agent_type: "reviewer"` and `agent_id`. `tool_input.file_path` is the worktree path. **PASS.**
- **Named** (`name: tw-probe-named`, an in-process teammate): the payloads carry
  `agent_type: "reviewer"` but **no `agent_id`**, and their own `session_id`. So TDD dispatches **may**
  use `name`, but Task 8 must key the role on `agent_type` only, never on `agent_id`.
- **Main session (the lead):** no `agent_type` and no `agent_id`. That confirms "the caller with no
  `agent_type`" as the lead's identity.
- **SubagentStart/SubagentStop:** 0 events for either dispatch, so they are not usable here. Reported per
  spec §13; nothing relies on them.
- **Step 6 checks:** the `ls` of the rendered tw-probe agent file gave "No such file or directory"; the grep printed
  nothing (exit 1); `gen.jl --check` was OK (26 files); the probe lane and branch were deleted.
- **Evidence:** the log is kept at `<root>/.lanes/archive/tw-task0/probe.jsonl`.
- **Follow-up found on the way (0.3.0 item):** the factory hook tests inherit `FACTORY_ALLOW_T3` from
  the caller's env and fail (101 failures) when it is set. The test runner must unset
  `FACTORY_ALLOW_T3` and `FACTORY_ALLOW_PUSH` for its children.

### Task 1: Failure-output fixtures

**Files:** Create scripts/test/fixtures/tdd/, holding `scratchpkg/` (the critic's `TddScratch`,
extended) and `<case>-1.13.txt` and `<case>-1.10.txt` for each case.

**Interfaces:**
- Produces fixture files, each with a header comment naming the Julia and TestItemRunner versions.
  The cases:
  - the critic's: `assert`, `stub in test`, `stub outside test`, `typo`, `typo outside`, `helper`,
    `passes`, `throws wrong`, `throws typo`, `new method on existing g`, `nested`;
  - new: `parse error`, `setup module`, `none` (`item=nosuch`), `killed` (`termsignal: 15`).

- [ ] **Step 1:** Copy `<root>/.lanes/scratch/tw-critic/TddScratch` into the fixture directory and add
  the four new cases.
- [ ] **Step 1b: Parse-level fixtures**, used by named RED tests in Tasks 5 and 8. They are copied
  verbatim; the critic measured each one on 1.13.2 and 1.10.12.
  - **H5 pairs** into scripts/test/fixtures/tdd/h5/:
    - `p2.jl`/`c2.jl` (`@compat public` grows), `p3.jl`/`c3.jl` and `p5.jl`/`c5.jl` (deletions),
      `p4.jl`/`c4.jl` (stub above a documented method), `p6.jl`/`c6.jl` (stub above an
      undocumented method), from `<root>/.lanes/scratch/tw-critic4/`;
    - `parent.jl`/`child.jl` (exports inside the module block), from the same place;
    - `names-p.jl`/`names-c.jl`. `names-p.jl` holds three verbatim lines of
      `ChuiCore.jl/src/names.jl` (`@compat public neutral, curry, fmap, pure, ap, traverse, sequence`,
      `@compat public Law, ExactEq, default_eq`,
      `@compat public init, partial, combine, final, iscommutative, combineall, default_monoid`)
      inside `module M … end`. `names-c.jl` is the same with `, newname` appended to the second
      line and `function newname end` added.
  - **Git scenarios** into scripts/test/fixtures/tdd/git/, as small shell scripts that build a
    scratch repo, one per case:
    - `amend.sh` (an implementer HEAD, then `git add test/t.jl && git commit --amend --no-edit`);
    - `C-HEAD.sh` (`git commit -C HEAD`);
    - `amend-author.sh` (`--amend --no-edit --author "test-writer <…>"`);
    - `C-reset-author.sh` (`--allow-empty -C <green> --reset-author`, which prints the green
      subject).
- [ ] **Step 2:** Run each case on 1.13.2 and 1.10.12
  (`JULIA_PKG_OFFLINE=true julia --project=. -e 'using Pkg; Pkg.test(test_args=ARGS)' -- "item=<case>"`).
  Save the outputs.
- [ ] **Step 3:** Check that the header regex `^(.+): (Test Failed|Error During Test) at (.+):(\d+)$`
  matches every failure header and nothing else. Report any difference to the lead.
- [ ] **Step 4:** Commit: `test(factory): TestItemRunner failure fixtures for tdd.jl`.

### Task 2: `item=` selection and `TDD_MATCHED` in the seeded runner

**Files:** Modify `test/runtests.jl` (seeded; a new block between `# --- item selection ---` and
`# --- end item selection ---`). Test: `scripts/test/test_runtests_template.jl`.

**Interfaces:**
- Produces:
  - `select_item(name::AbstractString, tags, args::Vector{String}; stable::Bool)::Union{Bool,Nothing}`.
    `:contract` → false. `!stable` and `:doctest`/`:snapshot` → false. An `item=` match → true. Any
    `item=` argument present but no match → false. Otherwise `nothing` (the tags decide).
  - `record_match(name, env = ENV)`, which appends `name * "\n"` to `env["TDD_MATCHED"]` when it is
    set.

- [ ] **Step 1: Failing tests:**
  - `"item= selects by name with spaces"`
  - `"non-matching item is not selected"`
  - `"no item= args defer to tags"`
  - `"contract never selected by name"`
  - `"doctest by name skipped when not stable"`
  - `"TDD_MATCHED records selected names"`
  - `"TDD_MATCHED unset writes nothing"`
  - `"TDD_MATCHED reaches the Pkg.test child"` (a scratch package; checks the UNVERIFIED claim)
- [ ] **Step 2:** STUB (`function select_item end`, `function record_match end`). Expect 8
  `MethodError`/assertion failures.
- [ ] **Step 3:** Implement, and call both first in the filter.
- [ ] **Step 4:** Green on both versions.
- [ ] **Step 5:** Commit: `feat(factory): runtests item= selection and TDD_MATCHED`.

### Task 3: The classifier (scripts/_tdd_classify.jl)

**Files:** Create scripts/_tdd_classify.jl. Test: scripts/test/test_tdd.jl (new; registered in
`scripts/test/runtests.jl`).

**Interfaces:**
- Produces:
  - `struct ItemSpan; name::String; file::String; first::Int; last::Int; setup::Vector{String}; end`;
  - `item_spans(text, file)::Vector{ItemSpan}` (from `Meta.parseall` line info);
  - `module_names(text)::Vector{String}` (the `@testmodule` and `@testsnippet` names);
  - `requested(root, rev)::NamedTuple{(:red, :must_pass)}`;
  - `headers(output)::Vector{NamedTuple{(:prefix, :kind, :file, :line, :exc, :thrown, :helper)}}`;
  - `classify(output, red, must_pass, matched::Set{String}; termsignal = 0)::Vector{Pair{String, Symbol}}`;
  - `red_ok(result)::Bool`;
  - `report(io, result, hdrs)`.

- [ ] **Step 1: Failing tests** (Task 1 fixtures, both versions):
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
  - `"requested: setup-module change adds must_pass items"`
- [ ] **Step 2:** STUB, then see the tests fail.
- [ ] **Step 3:** Implement. The rejected patterns live in one `const` tuple.
- [ ] **Step 4:** Green on both versions; ≤ 400 lines.
- [ ] **Step 5:** Commit: `feat(factory): tdd classifier`.

### Task 4: `tdd.jl red`, `green`, `api`, `brief`

**Files:** Create scripts/tdd.jl (`module Tdd`, `main(args; io)`). Test: scripts/test/test_tdd.jl.

**Interfaces:**
- Consumes: Task 3; `Evidence.run_evidence`; Task 2.
- Produces:
  - `red(root; rev = "HEAD", io)::Int`. Exit 2 when the tree is dirty, when `rev` is not
    `red`/`test-fix`, or when it touched no item. Otherwise it runs `ci.jl test -- item=…` with
    `TDD_MATCHED` as evidence kind `red`, appends `--- tdd ---` and the report, and returns 0 iff
    `red_ok`.
  - `green(root; base = "main", io)::Int`. All red items must be matched and pass, with a total of
    at least their count; then the default suite runs. Evidence kind `green`.
  - `api(root; io)::Int`. Julia ≥ 1.11, else exit 2 with `NOT RUN`. For each exported or `public`
    name it prints `## name` and its docstring, with no method bodies, from a subprocess in the
    test environment.
  - `brief(root; role, io)::Int`. Exit 2 on a dirty tree. It prints the header with `lane=`,
    `checkout=<abspath(root)>` and `head=`.
    - For a test-writer it adds the `## Public API` section (`api`) and the `## Stub diffs` (only if
      H5 passes for each stub, else exit 1 naming it).
    - For an implementer it adds `## Red tests` and `## Red evidence`.

    It saves the result to `<main>/.lanes/briefs/<lane>/<role>-<n>.md`, where `<main>` is the
    owning repo's main checkout, found from the worktree's `.git` file. It prints the path.

- [ ] **Step 1: Failing tests:**
  - `"red on a clean red commit exits 0 and writes red-<sha7>"`
  - `"red with a passing item exits 1 and names it"`
  - `"red on a dirty tree exits 2"`
  - `"red on a commit with no items exits 2"`
  - `"red on a green commit exits 2"`
  - `"killed run is not red"`
  - `"green after the fix exits 0"`
  - `"green with an unmatched name is NOT-RUN"`
  - `"green fails when the default suite fails"`
  - `"api prints docstrings, not bodies"`
  - `"api on 1.10 exits 2 NOT RUN"`
  - `"brief refuses a dirty tree"`
  - `"brief test-writer has header, api and stub diffs"`
  - `"brief refuses a stub that fails H5"`
  - `"brief header carries checkout= and saves under the owning repo's main .lanes"`
- [ ] **Step 2:** STUB, then see the tests fail.
- [ ] **Step 3:** Implement with `_common.jl`. `brief` needs `stub_declares_only` from Task 5, so
  write its test now and land `brief` after Task 5, or stub it.
- [ ] **Step 4:** Green on both versions (the `api` tests on 1.13 only).
- [ ] **Step 5:** Commit: `feat(factory): tdd.jl red, green, api, brief`.

### Task 5: History rules and `tdd.jl audit`

**Files:** Create scripts/_tdd_history.jl. Modify scripts/tdd.jl. Test: scripts/test/test_tdd.jl.

**Interfaces:**
- Produces:
  - `struct LaneCommit; sha::String; author::String; phase::Union{Nothing,String}; mode::Union{Nothing,Tuple{String,String}}; paths::Vector{String}; end`;
  - `lane_commits(root, base)` (from `git rev-list --no-merges --reverse`; the author from `%an <%ae>`);
  - `trailers(msg)`;
  - `history_rules(commits; stub_ok::Function)::Vector{String}` for H1–H9 (pure);
  - `strip_lines!(ex)`, which applies `remove_linenums!` and also sets each macrocall's `args[2]` to
    `nothing`;
  - `is_compat_decl(ex)::Bool`, true for `macrocall(@compat | Compat.@compat, _, :public, Symbol | tuple of Symbol)`
    and for `macrocall(@compat | Compat.@compat, _, Expr(:export, …))`;
  - `stub_declares_only(root, sha)::Bool`. It runs `strip_lines!` on both sides, descends into
    `module`/`baremodule` bodies, and compares multisets. Allowed additions: spec §4.2 H5,
    `is_compat_decl` included. Removals are allowed only when an export or public statement is
    replaced by a superset;
  - `evidence_rules(root, commits; ledger::String)` for E1–E5. `ledger` is the TDD ledger
    (spec §0.5), taken from `--ledger`. Its default is the outermost directory above `root` that holds
    `.lanes/ledger.jsonl`;
  - `audit(root; base, io)::Int`.

- [ ] **Step 1: Failing tests:**
  - `"no code change passes with no trailers"`
  - `"code commit without trailer fails H1"`
  - `"required lane with only refactor/stub src commits fails"` (H2)
  - `"stub editing test fails H3"`
  - `"green editing any test file fails H4"`
  - `"test-fix touching src fails H3"`
  - `"red touching changelog.d fails H3"`
  - `"stub with a method body fails H5"`
  - `"stub with inner constructor fails H5"`
  - `"stub with @kwdef fails H5"`
  - **`"stub adding export + function-end inside the module block passes H5"`** (NB2; the critic's
    pair `h5/parent.jl` → `h5/child.jl`)
  - `"stub adding include of a new declaration-only file passes H5"`
  - `"stub adding include of a file with a method fails H5"`
  - **`"stub adding a name to @compat public passes H5"`**, on fixtures `h5/names-p.jl` →
    `h5/names-c.jl` (the verbatim names.jl lines) and `h5/p2.jl` → `h5/c2.jl` (R4-B1). It must be
    seen RED (H5 FAIL) against a single-argument `@compat` matcher before `is_compat_decl` is
    written.
  - `"is_compat_decl: public with one name, a tuple, and export; rejects @compat with any other payload"`
  - `"stub adding @compat export passes H5"`
  - **`"stub inserted above a documented method passes H5"`**, on `h5/p4.jl` → `h5/c4.jl` (R4-M1).
    It must be seen RED with `remove_linenums!` alone.
  - `"stub inserted above an undocumented method passes H5"` (`h5/p6.jl` → `h5/c6.jl`)
  - `"stub that deletes a method fails H5"` (`h5/p3.jl` → `h5/c3.jl` and `h5/p5.jl` → `h5/c5.jl`)
  - `"stub replacing an export by a superset passes; by a subset fails"`
  - `"stub before its red passes H6; red before any stub with a later stub fails H6"`
  - `"red touching Project.toml fails H3"`
  - `"red touching test/runtests.jl fails H3"`
  - `"refactor mode: test/** change fails H8"`
  - `"mode trailer on a non-lead-authored commit is ignored (mode required)"`
  - `"green before red fails H6"`
  - `"two greens for one red fail H6"`
  - `"refactor before any green fails H6"`
  - `"lane ending on red fails H7"`
  - `"refactor mode: red commit fails H8"`
  - `"skip mode by a role-authored commit fails H8"`
  - `"skip mode by a lead-authored commit with reason passes"`
  - `"red authored implementer fails H9"`
  - `"phase-less commit with a role author fails H9"`
  - `"merge commits ignored"`
  - `"missing red evidence fails E1"`
  - `"refactor mode needs green at merge base (E2)"`
  - `"backfill item without mutate evidence fails E3"`
  - `"@test_broken-only item exempt from E3"`
  - `"dirty evidence fails E4"`
  - `"killed evidence fails E4"`
  - `"green without green evidence fails E2"`
  - `"role commit without tdd-commit record fails E5"`
  - `"E5 default ledger is the outermost .lanes/ledger.jsonl above the lane"` (a coordinator-style
    root holding a nested package with its own `.lanes`)
  - `"lead-authored non-phase commit to test/runtests.jl passes H4; to test/foo_tests.jl fails"` (R4-m4)
  - `"tdd-commit record with another agent_type fails E5"`
  - `"tdd-commit-violation for the lane fails E5"`

  The H5 cases run on a scratch git repo.
- [ ] **Step 2:** STUB, then see the tests fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Green on both versions.
- [ ] **Step 5:** Commit: `feat(factory): tdd history rules and audit`.

### Task 6: `mutate` (run by the mutator agent) and `gaps`

**Files:** Create scripts/_tdd_backfill.jl. Modify scripts/tdd.jl. Test: scripts/test/test_tdd.jl.

**Interfaces:**
- Produces:
  - `slug(name)::String`.
  - `scratch(root)::String`: `.lanes/scratch/mutate/` (a detached worktree, checked out at HEAD's
    sha, with the manifests copied in).
  - `mutate(root; item, src = nothing, expect = nothing, from, to, io)::Int`. Exit 2 on a dirty
    tree, or when `from` is not on the line. The mutant must fail as matched
    `ASSERTION`/`BEHAVIOUR` on a non-broken assertion. The file is restored in `finally`. The real
    run must be matched and pass. It writes kind `mutate-<slug>` or `mutexp-<slug>`.
  - `gaps(root; io)::Int`. It prints `UNTESTED name` lines and returns 0. On Julia < 1.11 it exits 2
    with `NOT RUN`.

- [ ] **Step 1: Failing tests:**
  - `"slug is <=33 chars and stable"`
  - `"two items at one sha give two files"`
  - `"killed mutant exits 0"`
  - `"surviving mutant exits 1"`
  - `"load-breaking mutation is wrong-reason, exits 1"`
  - `"from not on line exits 2"`
  - `"dirty tree exits 2"`
  - `"scratch file restored after a throw"`
  - `"real tree untouched"`
  - `"mutexp writes its own kind"`
  - `"unmatched item name is NOT-RUN"`
  - `"gaps lists the untested public name only"`
  - `"gaps on 1.10 exits 2 NOT RUN"`
- [ ] **Step 2:** STUB, then see the tests fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Green on both versions. Time one mutant cold and warm, and check whether
  alternating runs between the scratch copy and the real tree re-precompile each time (m-b). Paste
  the numbers.
- [ ] **Step 5:** Commit: `feat(factory): tdd mutate and gaps`.

### Task 7: `dod.jl` requirement `tdd` and the seeded `risk.toml`

**Files:**
- Modify `scripts/dod.jl`: `evaluate` gains `commits = nothing` and `stub_ok`, and `main` builds
  them.
- Modify `risk.toml` (seeded): `tdd` in the T1, T2 and T3 `requires`; tdd.jl, _tdd_classify.jl,
  _tdd_history.jl and _tdd_backfill.jl in the T3 globs; the comment.
- Test: `scripts/test/test_dod.jl`.

**Interfaces:** Consumes `history_rules`. Produces requirement `tdd`: `:pass` "no src/ext change" or
"tdd history OK (N commits, mode M)", else `:fail` with the first problem.

- [ ] **Step 1: Failing tests:**
  - `"tdd passes with no src change"`
  - `"tdd passes on stub-red-green-refactor"`
  - `"tdd fails on refactor-only required lane"`
  - `"tdd fails on green editing a test"`
  - `"tdd reads mode from the lead-authored trailer"`
  - `"skip by a role-authored mode commit fails"`
  - `"skip by a general-purpose-authored mode commit fails"`
  - `"skip by lead <lead@factory.invalid> with reason passes"`
  - `"unknown requirement still fails"`
- [ ] **Step 2:** See the tests fail.
- [ ] **Step 3:** Implement. `evaluate` stays pure.
- [ ] **Step 4:** Green on both versions. Run `julia scripts/dod.jl --base main` in the lane and
  paste the output.
- [ ] **Step 5:** Commit: `feat(factory): dod tdd requirement`.

### Task 8: The boundary hook and the commit guard

**Files:**
- Create, each ≤ 150 lines, all sourcing `_lib.sh` and `_bash_guard_lib.sh`:
  - .claude/hooks/tdd_boundary.sh, for paths, the Bash allowlist and dispatch;
  - .claude/hooks/_tdd_commit_guard.sh, the PreToolUse commit guard, sourced by tdd_boundary.sh;
  - .claude/hooks/tdd_commit_post.sh, the PostToolUse(Bash) and PostToolUseFailure(Bash) commit check.
- Modify `.claude/settings.json`: PreToolUse matchers
  `Read|Grep|Glob|Edit|Write|MultiEdit|NotebookEdit|Bash` and `Agent|Task` with the fail-closed
  wrapper; tdd_commit_post.sh on **both** PostToolUse `Bash` and PostToolUseFailure `Bash`.
- Modify `.agents/checks.toml`: the `tdd` and `tdd_boundary` rows (spec §4.6, verbatim).
- Test: scripts/test/test_hooks_tdd.jl (new).

**Interfaces:**
- Consumes `field`, `ledger`, `ROOT` and `MAIN`, and bash_guard's word splitter.
- Produces:
  - **PreToolUse:** exit 0 (allow), or exit 2 with the rule and spec §0.5/§0.6 named on stderr
    (deny). Each denial writes `tdd-boundary-denied {agent_type, tool, rule}` to the ledger. Before
    each `git commit` the guard records the checkout's HEAD in
    `<session root>/.lanes/tdd-pending/<tool_use_id>`.
  - **PostToolUse and PostToolUseFailure:** for every new commit since that HEAD
    (`git rev-list <before>..HEAD`), it writes `tdd-commit {agent_id, agent_type, checkout, sha}`
    to the TDD ledger, `<session root>/.lanes/ledger.jsonl` (`_lib.sh`'s `ledger`).
  - **Sweep:** every Pre and post call first processes stale `tdd-pending` entries, records their
    commits with `late: true`, and deletes them. On a violation it writes
    `tdd-commit-violation {…, rule}` and prints it.
  - **Dispatch:** prompts are saved to `<main>/.lanes/briefs/<lane>/dispatched/`.
- **Checkout resolution:** take the nearest ancestor of the target with a `.git` entry, at or under
  the session root, after resolving symlinks (`cd -P`/`pwd -P`).

- [ ] **Step 1: Failing tests** (one per rule in spec §0.5 and §0.6):
  - Reads:
    - `"test-writer Read lane test/ allowed"`
    - `"test-writer Read src denied"`
    - `"test-writer Read via test/ symlink to ../src denied"` (m2)
    - `"test-writer Read ~/.claude/projects transcript denied"`
    - `"test-writer Read ~/.julia/packages denied"`
    - `"test-writer Read .lanes/scratch/mutate denied"`
    - `"test-writer Read mutate-* evidence denied; red-* allowed"`
    - `"test-writer Grep without path denied"`
  - Writes:
    - `"test-writer Write src denied; Write test allowed"`
    - `"test-writer Write test/runtests.jl denied"` (m3)
    - `"test-writer NotebookEdit outside test denied"`
    - `"implementer Write test denied"`
    - `"implementer Bash redirect into test/ denied"`
  - Bash and git:
    - `"cd <lane> && julia tdd.jl red allowed"` (the command `cd <lane> && julia scripts/` + `tdd.jl red`)
    - `"julia -e denied; sh -c denied"`
    - `"evidence.jl direct denied; tdd.jl mutate denied"`
    - `"git log denied; git show denied; git show HEAD:src/a.jl -- test/ denied"` (R3-M3)
    - `"git diff -- test/ allowed; git diff -- src/ denied"`
  - Commit guard:
    - `"commit by test-writer with implementer author denied"`
    - `"lead commit with env role author denied"`
    - `"lead commit after git config role identity denied"`
    - `"amend keeps source author: implementer amending a test-writer commit denied"` (fixture
      `git/amend.sh`; R3-M2)
    - `"-C HEAD denied"` (fixture `git/C-HEAD.sh`)
    - `"amend --author role denied at Pre"` (fixture `git/amend-author.sh`; R4-m1 precedence)
    - `"amend --reset-author and -C --reset-author take caller identity"`
    - `"test-writer -C/-c/--reuse-message/--reedit-message/--fixup/--squash denied"` (fixture
      `git/C-reset-author.sh`; R4-m2)
    - `"test-writer --amend on an implementer HEAD denied; on its own HEAD allowed"`
    - `"commit followed by a failing command is recorded"` (a PostToolUseFailure payload; R4-M3)
    - `"run_in_background with git commit denied"`
    - `"stale tdd-pending entry swept and recorded late"`
    - `"session root differs from checkout: record lands in the session ledger and audit finds it"`
      (topology (a) layout; R4-M2)
    - `"git add test/x && git commit compound: commit checked"`
    - `"general-purpose caller with lead identity denied"` (R3-m1)
    - `"role commit with TDD-Mode trailer denied"`
    - `"test-writer commit with staged src denied"`
    - `"post-commit violation recorded"` (a commit made with the Pre half stubbed out)
    - `"tdd-commit record carries the resulting sha"`
  - Dispatch:
    - `"general-purpose dispatch of test-writer denied"` (R4-m3)
    - `"dispatch with stale head= denied"`
    - `"dispatch on a dirty checkout denied"`
    - `"two repos with the same lane name: checkout= picks the right one"` (R3-M5)
    - `"clean dispatch saved under the owning repo's main .lanes"`
  - Fail closed:
    - `"malformed payload fails closed"`
    - `"missing library fails closed"`
- [ ] **Step 2:** A skeleton that allows everything, then see the deny cases fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Green on both versions. Time each hook per call (target under 30 ms) and paste the
  timings. Check that each file is ≤ 150 lines.
- [ ] **Step 5:** Commit: `feat(factory): tdd boundary hook and commit guard`.

**Left to review on purpose (m4).** These rules are stated in the spec but have no mechanical test,
and the reviewer checks them (spec §4.5):

- that a test comes from the spec;
- that GREEN is minimal;
- that a refactor-mode lane adds no behaviour;
- that a test-refactor weakens nothing;
- that a brief carries no paraphrase of the implementation;
- that a mutation is meaningful;
- the `HELPER` flags;
- test edits made while resolving a merge conflict.

### Task 9: Registry, bodies, skill, docs; VERSION 0.3.0

**Required before the VERSION bump (lead ruling, 2026-10-26, tw-030 review):** a renamed red item
must not deadlock `green`. Today a red item that a later commit renames or deletes is NOT-RUN
("gone at HEAD") for good. The way out is a `TDD: test-fix` commit by the test-writer that renames
the item and records fresh red evidence under the new name, after which `green` proceeds. This
needs a test and an implementation before 0.3.0.

**Files:**
- `.agents/agent-registry.toml` (seeded): the spec §2.1 `test_writer` entry with `tools` and
  `disallowed_tools`; the implementer's role, `file_scope`, `tools`, `disallowed_tools` and
  scorecard; the header "12" becomes "13", citing ADR-0015.
- .agents/bodies/test_writer.md (new; spec §2.2).
- `.agents/bodies/{implementer,reviewer,law_tester,property_tester,differential_tester}.md`
  (spec §2.3, §4.5).
- `.claude/skills/lane-lifecycle/`: the two brief templates (spec §0.4); dispatch rules (fresh
  `subagent_type`, never a fork, subagents only, a clean lane); merge, never rebase; the mode on a
  lead-authored commit.
- `.claude/commands/change-review.md`: run `tdd.jl audit --ledger <root>/.lanes/ledger.jsonl` and
  `dod.jl`, and read the saved prompts.
- `CLAUDE.md` (seeded): the `tdd.jl` lines.
- `factory/VERSION` → `0.3.0`; `factory/CHANGELOG.md` (the spec §9.2 migration list);
  `factory/README.md` (13 roles; the tdd scripts and hook).
- Test: `scripts/test/test_gen.jl`.

- [ ] **Step 1: Failing tests:**
  - `"registry has 13 agents including test-writer"`
  - `"implementer file_scope has no test/**"`
  - `"test-writer tools frontmatter rendered without Agent/SendMessage"`
- [ ] **Step 2:** See the tests fail.
- [ ] **Step 3:** Make the edits, then run `julia scripts/gen.jl` in `factory/template`.
- [ ] **Step 4:** Run the full template suite and `gen.jl --check` on both versions through
  `evidence.jl`, and paste the totals.
- [ ] **Step 5: Dogfood numbers.** Handoffs and wall-clock per task for Tasks 2–8, taken from the
  ledger, go into the CHANGELOG entry (spec §6).
- [ ] **Step 6:** Commit: `feat(factory): test-writer role, factory 0.3.0`.

### Task 10: Review, coordinator sync, and the coordinator registry (D7 reversed)

- [ ] **Step 1:** The critic, then the reviewer, on the factory branch. The report states the
  dogfood limit (Global Constraints).
- [ ] **Step 2:** Dry run, and paste it:
  `julia factory/template/scripts/sync_factory.jl --from factory --to . --profile coordinator`. A
  conflict goes to the lead; never `--force`.
- [ ] **Step 3:** `--apply` (with `FACTORY_ALLOW_T3=1` from Task 0). Then the hand edits:
  - the coordinator registry gains the `test_writer` and `implementer` entries (spec §2.1);
  - the coordinator `risk.toml` T3 globs gain the 4 tdd scripts.

  Run `julia scripts/gen.jl`, `julia scripts/test/runtests.jl` and `julia scripts/check_docs.jl`;
  all must be OK.
- [ ] **Step 4:** Check that `ls .claude/agents/ | grep -c -E '^(implementer|test-writer)\.md$'`
  gives `2`. This is the critic's NB1 reproducer, `0` before the change.
- [ ] **Step 5:** Commit, review, merge.

### Task 11: Package syncs (one lane per package, in that repo)

- [ ] **ChuiCore.jl**, after v0.0.1 is tagged:
  - sync 0.3.0, dry run first;
  - the hand edits (spec §9.2): the registry, `risk.toml`, and the `test/runtests.jl` selection
    block;
  - `ci.jl guards`, and `ci.jl test` on both versions;
  - `tdd.jl gaps` on 1.13.
- [ ] **ChuiTypes.jl**: the same, after `feat/phase5`, `feat/p5-perf` and `feat/p5-ttfx` merge.
- [ ] **ChuiFrames.jl**: the same, after `feat/p4-*` merge.
- [ ] **The first real TDD lane** (any package): run `tdd.jl audit` and confirm that the ledger's
  `tdd-commit` lines show `agent_type` test-writer and implementer under separate `agent_id`s.

### Task 12: Backfill missing tests (the user's second request)

One lane per package, in this order: ChuiCore.jl, ChuiTypes.jl, ChuiFrames.jl, each after its
Task 11 lane merges.

- The lead dispatches a fresh test-writer subagent (the form from Task 0) with a `tdd.jl brief`:
  the gaps list, `api` and the docs.
- A separate general-purpose `mutator` subagent, also dispatched by the lead, runs `mutate`. Its
  report never goes into a test-writer brief.
- The lead writes the changelog fragment.
- No `TDD-Mode:` is needed (no code change); E3 applies.

- [ ] **Step 1:** Run `tdd.jl gaps` on 1.13 and paste it, ranked per spec §5.1.
- [ ] **Step 2: Measure first.** The test-writer commits about 10 items (`TDD: backfill`), and the
  mutator mutates each one against that commit and times it. If the projection is over 2 h, stop
  at a ★: split into area lanes, or the user accepts the cost.
- [ ] **Step 3:** For the rest: the test-writer commits a few items at a time, and the mutator
  mutates each one. A survivor goes back to the test-writer as "item X missed a change to its
  claimed behaviour", without the site (`--src` by default; `--expect` only with a reason).
- [ ] **Step 4:** Where the docs and the behaviour disagree: `@test_broken` with a `BUG:` comment,
  and a report line.
- [ ] **Step 5:** Run `tdd.jl audit --base main` and the full suite on both versions, and report the
  measured coverage.
- [ ] **Step 6:** Reviewer, then merge. The lead proposes the coverage floor (the measured value
  minus 1 point) to the user.
