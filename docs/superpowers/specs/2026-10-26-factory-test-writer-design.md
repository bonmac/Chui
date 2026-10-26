# Factory 0.3.0: a `test-writer` role and test-first lanes

- **Date:** 2026-10-26 (revision 2: the critic's findings on `6b1c4f1` are addressed; the table is in §10)
- **Lane:** testwriter-spec (coordinator; this spec and its plan only)
- **Asked by the user:** "plan the test-writer role. It should follow proper TDD principles. Write
  any missing tests once done."
- **Tier:** T3 in every repo that takes it, because the registry, the agent bodies, the gate
  scripts, their tests and `risk.toml` all change. Implementing it needs the user's
  `FACTORY_ALLOW_T3=1` and ADR-0015, which plan Task 0 asks for before any code is written (§7.3).
- **Plan:** `docs/superpowers/plans/2026-10-26-factory-test-writer.md`
- **Status:** design only; nothing is implemented. A fact not yet checked is marked UNVERIFIED.
  The critic's probes are taken as measured ground truth (TestItemRunner 1.3.2, Julia 1.13.2 and
  1.10.12, scratch package `TddScratch`; the output is in
  `.lanes/scratch/tw-critic/TddScratch/*.txt` of the main checkout, which is gitignored).

## 0. Problem

Today the `implementer` writes both the test and the code:

- its `file_scope` is `["src/**", "test/**", "ext/**", "changelog.d/**"]`;
- its rule is "Test first: write the failing test, run it, see it fail, then implement".

Nothing checks that rule:

- `dod.jl`'s `tests` requirement passes when `test/` changed at all, in any order. The register
  says the check cannot tell "that the changed tests test the changed code".
- No evidence records that a test was ever red, or why.
- The author of the code also picks the test, so the test tends to restate the code instead of
  the spec.

The law, property and differential testers already prove that their tests can fail. Unit and
example tests have no such rule. Every package's `coverage.floor` is `0.0` (the `ratchets.toml` of
ChuiCore.jl, ChuiTypes.jl and ChuiFrames.jl, read 2026-10-26).

## 1. Decision summary

| # | Question | Decision (recommended) |
|---|---|---|
| D1 | The role | A 13th template role, `test_writer` / `test-writer`, in `write` mode, for unit and example tests only. The implementer's commits may not touch `test/**`, and the history check enforces that (§4.2 rule H4). |
| D2 | TDD protocol | Per behaviour: STUB (only for new names) → RED → GREEN → REFACTOR, plus `test-fix` and `test-refactor` for changing tests. Each commit carries a `TDD:` trailer, and the history has to follow the order in §3.1. |
| D3 | Right-reason red | `tdd.jl red` parses only the failure *headers* and classifies each one. An assertion failure counts, and so does any exception raised inside an item, `MethodError` included. Rejected: `UndefVarError`, parse or load errors, a load error caught by `@test_throws`, a run with no summary, a test that passes, and a run that matched no items. |
| D4 | Enforcement | `tdd.jl audit` runs the history rules H1–H8 plus the evidence rules E1–E4. `dod.jl` gets the history rules as requirement `tdd`. The lead runs both locally before every merge, since Chui merges locally. The lane mode has one source, a `TDD-Mode:` trailer. TDD lanes merge `main` in and never rebase. |
| D5 | Backfill | Characterization items are committed first (`TDD: backfill`). Then `tdd.jl mutate` runs each one against a mutated persistent scratch copy and writes evidence `mutate-<slug>`; a wrong-expectation fallback writes `mutexp-<slug>`. `tdd.jl gaps` finds the gaps. Order: ChuiCore, then ChuiTypes, then ChuiFrames. Bugs found become `@test_broken` and are reported. Mutation has a time cap. |
| D6 | Version | 0.3.0, a minor bump: a guard becomes stricter and a role's scope narrows. |
| D7 | Coordinator | Its registry does not take the role. The body arrives unused, as `implementer.md` does today. |
| D8 | Cost and skips | 2–4 more handoffs per task. The lead picks the lane mode in the brief, and the lane's first commit records it. A lane that changes no `src/`/`ext/` needs no mode. |

## 2. The role (D1)

### 2.1 Registry entry (template `.agents/agent-registry.toml`)

```toml
[[agents]]
slug = "test_writer"
name = "test-writer"
role = "Writes unit and example tests from the spec, plan and public API, before the code exists (RED), and characterization tests for untested code."
description = "Use in a test-first lane before the implementer writes code, to write the failing tests for one planned behaviour; or to backfill missing tests in an existing package."
model = "inherit"
color = "yellow"
default_mode = "write"
file_scope = ["test/**", "changelog.d/**"]
scorecard = ["each test derived from the spec or public docs, cited", "RED evidence: every new item fails for the right reason (tdd.jl red)", "one behaviour per test item, no implementation details asserted", "backfill: every characterization item killed a mutant (tdd.jl mutate)", "stays out of src/ and the specialist test files"]
output_format = "behaviours and their sources, test items written, tdd.jl red or mutate output, disputes and bugs found, checks not run and why, scorecard"
```

`file_scope` cannot say "test/** except the specialist files": lane `--owns` globs have no
negation, and adding negation is not worth the change. The exclusions are in the body. The test
writer does **not** edit:

- `test/laws/**`, `test/property/**`, `test/differential/**`, `test/contracts/**` or `test/jet/**`;
- items tagged `:laws`, `:property`, `:differential`, `:contract` or `:quality`, wherever they live.
  ChuiCore keeps its law tests flat (`test/*_laws_tests.jl`, `*_planted_tests.jl`), so a path rule
  alone would be wrong there;
- the seeded runners (`test/runtests.jl`, `test/Project.toml`).

It may write the fixtures, `@testmodule`s and `@testsnippet`s its own items use. Who touches a
file is checked from the history (§4.2); the body governs which test files within `test/**`.

**Why a 13th role.** The registry comment says "never add a 13th without asking whether an
existing role covers it", and ADR-0001 says "12 roles". No existing role covers this:

- the implementer cannot be the black-box author of tests for its own code;
- law and property testers test laws and invariants with generators;
- the differential tester needs a reference implementation;
- the critic and the reviewer are read-only.

The user asked for the role. ADR-0015 records the decision before anything is built (plan Task 0).

### 2.2 Body (new .agents/bodies/test_writer.md, managed)

1. **Derive each test from a stated source.** A source is a spec or plan line, a docstring,
   `docs/src/`, a contract entry or an ADR; cite it in the item name or a one-line comment.
   - In a TDD lane, read no `src/` beyond the STUB diff.
   - Never test code you wrote.
2. **One behaviour per `@testitem`.** Name the behaviour, for example
   `"select: unknown column throws ArgumentError naming it"`, and keep the assertions few and about
   that behaviour.
3. **Test the public API only.** That means names that are exported, declared `public`, or marked
   API in the spec. Never assert:
   - private fields or internal function names;
   - call counts or allocations (the benchmarker or a `:quality` item covers those);
   - exact `show` output (a `:snapshot` item covers that).
4. **RED.** Commit the tests alone with `TDD: red`, run `tdd.jl red` and paste its output.
   - On any `WRONG-REASON`, `PASSED`, `COLLATERAL` or `NOT-RUN`, fix the test and amend the commit
     (still unmerged, so this is safe), then re-run.
   - Report only a clean red.
   - Never wrap an expression in `@test_throws` to make it fail. `tdd.jl` rejects a load error
     caught that way, but it cannot see one caught inside a law or property kit (§4.5).
5. **Stay out of the code.** Never edit `src/`, `ext/` or `Project.toml`. If a stub is missing,
   name it in your report; the implementer adds it (§3.2).
6. **Disputes.** When the implementer disputes a test, answer with either:
   - a `TDD: test-fix` commit, re-checked by `tdd.jl red`; or
   - a written reason why the test stands.

   The lead decides if you two disagree.
7. **`test-refactor`.** Restructure tests, for example extract a shared `@testsnippet`, only after
   a green. Commit with `TDD: test-refactor` and run `tdd.jl green`. No assertion may be removed or
   weakened; the reviewer checks this.
8. **Backfill** (§5). Commit items with `TDD: backfill`, then run `tdd.jl mutate` for each one
   against that commit. A bug becomes `@test_broken` plus a report line; never fix it yourself.
9. **Shared rules.** Edit/Write only; add a changelog fragment; report the changed files as a list;
   say which checks did not run.

### 2.3 What changes for the other roles

| Role | Change |
|---|---|
| implementer | `file_scope = ["src/**", "ext/**", "changelog.d/**"]`. New role line: "Implements one planned task against the test-writer's red tests: minimal code to green, then refactor with tests unchanged." New rules: never touch `test/**` (rule H4 fails the lane); a test you dispute goes back to the test-writer; STUB declares only (rule H5 checks it); GREEN is the minimal code that passes the red items; REFACTOR only after a green. Scorecard: "failing test written first" becomes "tdd.jl audit OK". |
| law-tester, property-tester, differential-tester | Scope unchanged. One added line: "In a test-first lane, commit new items with `TDD: red` before the code; `tdd.jl red` checks them." Their "plant a violation" rule stays. |
| reviewer | The checklist in §4.4. |
| contract-steward | No change. |

## 3. TDD protocol inside one lane (D2, D3)

### 3.1 Phases and the order the history must follow

```
STUB          implementer  src/ext only, declarations only         TDD: stub
RED           test-writer  test/** only, the new items fail        TDD: red           + red evidence
GREEN         implementer  src/ext only, minimal                   TDD: green         + green evidence
REFACTOR      implementer  src/ext only, behaviour unchanged       TDD: refactor      + green evidence
TEST-FIX      test-writer  test/** only, a disputed test changed   TDD: test-fix      + red evidence
TEST-REFACTOR test-writer  test/** only, after a green             TDD: test-refactor + green evidence
BACKFILL      test-writer  test/** only, characterization items    TDD: backfill      + mutate evidence per item
```

- **One worktree, turn-taking.** A lane is one worktree and one branch. The two agents take turns
  and never run at once. Each agent commits before it hands over. The lead dispatches them in order.
- **Small steps.** A RED commit covers one behaviour, or a small group the plan names, in a few
  items. A plan task with five behaviours runs five cycles.
- **Trailers.** `TDD: <phase>` is a git trailer. The lane's oldest non-merge commit also carries
  `TDD-Mode: <mode>` (§6), the single source of the mode.

### 3.2 New names: stubs; changed behaviour: none needed

- **A new name needs a stub.** A test for a name that does not exist fails with `UndefVarError`,
  which a typo in the test also causes, so such a failure proves nothing. Before the RED, the
  implementer commits a STUB: `function f end`, new `struct`s with their spec'd fields and no inner
  constructors, `export`/`public` lines, and docstrings. A STUB has no method bodies.
- **A new method on an existing function, or a changed behaviour, needs no stub.** Its natural red
  is a `MethodError` (on the function itself, or on a Base function it calls: measured,
  `MethodError: no method matching +(::String, ::Int64)` for `g("a")` with `g(x) = x + 1`, on both
  1.13.2 and 1.10.12), or a wrong value. Both count (B2, §3.3).

  Rejected alternative: throwing method stubs (`g(::String) = error("TDD stub")`). They add a
  method to an existing generic, which changes dispatch and can create ambiguities. They put code
  in a STUB commit, so rule H5 could not stay a pure declaration check. And they still would not
  cover a red raised inside a Base function the new code calls.

### 3.3 Classification (measured output format)

TestItemRunner prints every failure as a header line, the same on 1.10.12 and 1.13.2:

```
<innermost testset name>: Test Failed at <absolute file>:<line>
<innermost testset name>: Error During Test at <absolute file>:<line>
```

- The prefix is the innermost `@testset`, not always the item name.
- The line is the line of the failing statement. It is reliable for the item's own file.
- **Stacktrace line numbers for the item file are wrong** (measured: `items_tests.jl:539` in a
  37-line file). tdd.jl therefore uses only the headers. A header is attributed to the `@testitem`
  whose span in that file contains the line.
- The block under a header runs up to the next header or the `Test Summary:`. Its *exception
  line* is the first line after `Test threw exception` / `Expression: …` or after
  `Got exception outside of a @test`, with one leading `LoadError: ` stripped (measured:
  `y = f(1)` outside `@test` gives `LoadError: MethodError: …`).
- A `Pkg.test` line `ERROR: LoadError: Some tests did not pass: …` is the run's own summary and is
  ignored.

| Class | Rule | Red? |
|---|---|---|
| `ASSERTION` | `Test Failed` header, and the block has no `Thrown: (UndefVarError\|LoadError\|ParseError\|ArgumentError: Package)` | yes |
| `BEHAVIOUR` | `Error During Test` header whose exception line is not on the rejected list, such as `MethodError`, `ArgumentError`, `KeyError` or `AssertionError` | yes |
| `WRONG-REASON` | an exception line of `UndefVarError`, `ParseError`/`syntax:`, `LoadError` (after stripping one prefix), `SystemError: opening file`, `ArgumentError: Package … not found`; an `ASSERTION` whose `Thrown:` is one of those (a typo under `@test_throws`, measured: `Thrown: UndefVarError`, M2); a header inside no item span; no `Test Summary:` in the output; a killed run (`termsignal ≠ 0`) | no |
| `PASSED` | a requested item with no header | no |
| `NOT-RUN` | a requested item that the runner did not select (§3.4) | no |
| `COLLATERAL` | a header inside the span of an item that was not requested | no (the run fails) |

- **An item is red** when it has at least one `ASSERTION` or `BEHAVIOUR` header and no
  `WRONG-REASON` header. **The run passes** when every requested item is red and nothing is
  `COLLATERAL`.
- **HELPER flag** (report only, never a fail). The first stacktrace frame of a `BEHAVIOUR` block may
  be a file under `test/` other than the item's file (measured: `helpers.jl:1`, whose line numbers
  are right because helpers are included, not evaluated). tdd.jl then appends `HELPER <file>:<line>`,
  so the reviewer can tell whether the helper itself is broken (M1). Failing such blocks is rejected:
  a helper that calls code which throws is a legitimate red. A reviewer flag is the honest limit of
  what the output shows.
- **Which items are requested.** These are the `@testitem`s whose span a RED or TEST-FIX commit
  touched, plus those it added. When the commit also adds or changes a `@testmodule` or
  `@testsnippet`, tdd.jl also runs every item that names it in `setup = [...]`. Those items must
  *pass*: a failure is `COLLATERAL` (m1). A RED commit must touch at least one `@testitem`,
  otherwise exit 2.

### 3.4 Running only the requested items (seeded `test/runtests.jl`)

- **Selection.** The seeded runner gains an `item=<name>` argument; it worked through
  `Pkg.test(test_args=ARGS)` with names that contain spaces, measured. The order of the filter is:
  1. `:contract` items are never selected;
  2. the stable-only exclusion (`:doctest`/`:snapshot` below `STABLE_MIN`) still applies to named
     items (m9);
  3. then the `item=` names;
  4. otherwise the tags, as today.
- **Vacuous runs** (M3). `item=nosuch` exits 0 with `Total 0`, measured. So when the environment
  variable `TDD_MATCHED` names a file, the seeded filter appends each name it selects to that file.
  This works whether or not control returns after `@run_package_tests` (UNVERIFIED, so not relied
  on). tdd.jl sets the variable to a temp file, then reads it:
  - every requested name must be in it, otherwise it is `NOT-RUN` and the run fails, in red, green
    and mutate alike;
  - for `green` and `mutate` it also requires a `Test Summary:` total of at least the number of
    requested items.

### 3.5 Evidence

- **The run.** `tdd.jl red|green` runs at a committed HEAD through `evidence.jl`, with kind `red`
  or `green`; on a dirty tree it exits 2. tdd.jl appends its classification table to the file,
  under `--- tdd ---`.
- **`green`** runs the requested items of every RED and TEST-FIX commit in the lane, all of which
  must pass and be matched, and then the default suite.

### 3.6 GREEN, REFACTOR and disputes

- **GREEN** changes only `src/`, `ext/`, `changelog.d/` and, when the plan names a new dependency,
  `Project.toml` (T2). "Minimal" is the reviewer's call: no branch, option or method that the red
  items do not exercise.
- **REFACTOR** follows the same path rule. The suite must be green at the commit, recorded as
  `green` evidence.
- **Disputes.** The implementer never edits a test, not even a typo. A disputed test goes back to
  the test-writer (§2.2 rule 6).

## 4. Enforcement (D4)

### 4.1 scripts/tdd.jl (new, managed, T3)

```
julia scripts/tdd.jl red    [--root DIR] [--rev REV]   classify the RED/TEST-FIX commit's requested items
julia scripts/tdd.jl green  [--root DIR]               the lane's red items pass (matched), then the default suite
julia scripts/tdd.jl audit  [--root DIR] [--base B]    history rules H1-H8 + evidence rules E1-E4
julia scripts/tdd.jl mutate [--root DIR] --item NAME (--src F:LINE | --expect F:LINE) --from S --to S
julia scripts/tdd.jl gaps   [--root DIR] [--lcov FILE] public names with no test; uncovered lines (Julia >= 1.11)
```

- Each file stays under the 400-line `scripts/*.jl` budget. The classifier goes in
  scripts/_tdd_classify.jl, the history rules in scripts/_tdd_history.jl (which `dod.jl` includes
  as well), and mutate and gaps in scripts/_tdd_backfill.jl.
- The new phase vocabulary: `stub | red | green | refactor | test-fix | test-refactor | backfill`.
- The modes: `required | refactor | skip`.

### 4.2 History rules (`_tdd_history.jl`; used by both `tdd.jl audit` and `dod.jl`)

The rules read the commits in `git rev-list --no-merges --reverse <mb>..HEAD`, with each commit's
`TDD:` phase and its changed paths. The mode comes from the `TDD-Mode:` trailer of the oldest such
commit; when it is absent, the mode is `required`. Let *code* mean `src/**` or `ext/**`.

| Rule | Check (mode `required` unless stated) |
|---|---|
| H1 | If no commit changes code, PASS: rules H2–H8 do not apply. Otherwise every commit that changes code has a phase trailer. |
| H2 | At least one `red` commit exists (B1: a lane of only `stub`/`refactor` commits FAILS). |
| H3 | Paths by phase. `stub`, `green` and `refactor` change no `test/**`. `red`, `test-fix`, `test-refactor` and `backfill` change no code and no `Project.toml`. |
| H4 | The implementer's test ban: no commit without a test-writer phase (`red`, `test-fix`, `test-refactor`, `backfill`) touches `test/**` (M4; this is H3 seen from the other side, listed for the register). |
| H5 | A `stub` adds only declarations. tdd.jl parses each changed `src`/`ext` file at the commit and at its parent (`Meta.parseall`) and compares the top-level expressions. The new ones may only be `function NAME end`; a `struct`/`mutable struct`/`abstract type`/`primitive type` whose body holds only field declarations (no inner constructors, no methods); `export`/`public`; a docstring attached to one of these; or `using`/`import`. Any other new or changed top-level expression FAILS. |
| H6 | Order. A `stub` is followed by a `red` before any `green`. Each `green` comes after a `red`/`test-fix` with no other `green` since that red (one green per red: squash small steps). A `refactor` or `test-refactor` comes after a `green`, with no `red` waiting for its green in between. |
| H7 | The last code-changing phase in the lane is `green` or `refactor`, so a lane does not end on a red. |
| H8 | Mode `refactor`: no `red`/`green`/`stub`; every code commit is `refactor`; no commit touches `test/**`. Mode `skip`: the `TDD-Mode:` line carries a reason, and no other rule applies. |

### 4.3 Evidence rules (`tdd.jl audit` only; the files are local and gitignored)

| Rule | Check |
|---|---|
| E1 | Every `red` and `test-fix` commit has `red-<sha7>` with a passing classification. |
| E2 | Every `green`, `refactor` and `test-refactor` commit has `green-<sha7>` that passed. In mode `refactor`, the merge base also needs a passing `green-<sha7>` (green before the change). |
| E3 | Every item a `backfill` commit adds has a `mutate-<slug>` or `mutexp-<slug>` file, at that commit or a later lane commit, that passed (§5.2). The exception: an item whose only assertions are `@test_broken` (m4) is listed, not proved. |
| E4 | No evidence file is `dirty: true` or has `termsignal ≠ 0`. |

### 4.4 Where it runs, merges and rebases

- **Local runs (M5).** Chui lanes merge locally with `--no-ff` and the user pushes `main`, so there
  is no pull request and the CI `dod.jl` job (Guards on `pull_request`) does not run. Before every
  merge, the lead runs `julia scripts/dod.jl --base main` (history rules) and
  `tdd.jl audit --base main` (both rule sets), in the lane, through `/change-review`,
  and the reviewer pastes both. CI runs `dod.jl` only on a PR, and Chui has none today.
- **Merge, never rebase (M6).** Evidence is named by sha, so a rebase orphans all of it. A TDD lane
  takes `main` in with `git merge main`. The history rules skip merge commits (`--no-merges`,
  m3). Keying evidence by `git patch-id` was rejected: evidence records a tree that was run, and a
  rebased tree was never run. A lane that was rebased anyway re-runs `tdd.jl green` at its tip. The
  E1 red evidence cannot be recreated, since the code now exists, so audit reports the rebase and
  the lead decides.
- **Squash merges** would also erase the order; the history rules run on the lane before its merge.

### 4.5 Reviewer checklist (body additions)

- `tdd.jl audit` and `dod.jl` outputs pasted and OK; the `TDD-Mode:` reason holds.
- RED items cite their source and assert behaviour, not implementation.
- For each `BEHAVIOUR` red caused by a `MethodError`: the call's arguments match the spec's
  signature. A wrong argument order would also be a `MethodError` (B2).
- Each `HELPER` flag: the helper is correct, and the failure comes from the code under test.
- GREEN is minimal. A `test-refactor` removes or weakens no assertion.
- Merge commits: `git show --cc` holds no test edit made while resolving a conflict.
- Backfill: each mutation changes behaviour the item claims to test; every `mutexp` fallback is
  justified.

### 4.6 Register row (`.agents/checks.toml`)

```toml
[[checks]]
id = "tdd"
rule = "In a required-mode lane that changes src/ext, at least one RED commit exists, each GREEN follows its RED, REFACTOR follows a GREEN, STUB commits only declare, implementer phases never touch test/**, test-writer phases never touch src/ext, each red item fails with an assertion or an in-item exception (never UndefVarError, a parse or load error, a typo caught by @test_throws, a pass, or no run), and each characterization item kills a mutant"
prevented_by = "scripts/tdd.jl"
runs_in = ["local /change-review: tdd.jl audit (history + evidence) and dod.jl requirement `tdd` (history) before every merge", "ci Guards dod.jl on pull_request only (Chui merges locally: none today)"]
test = "scripts/test/test_tdd.jl"
blind_spots = [
  "`TDD:` trailers are self-declared: one git identity serves every agent, so an implementer commit labelled `test-fix` passes H3/H4; the lane ledger records which agents ran, not which commit each made",
  "evidence is gitignored (.lanes/evidence/): rules E1-E4 run only on the machine that made it; dod.jl checks history only",
  "that a test is derived from the spec and not the code, asserts behaviour rather than implementation, that GREEN is minimal, that a test-refactor weakens nothing",
  "a MethodError from wrong arguments is classed BEHAVIOUR (reviewer checks the signature)",
  "exceptions caught inside property and law kits (Supposition @check, law_capture-style helpers) or by a deliberate try/catch are classed ASSERTION; a load error hidden that way stays red until `tdd.jl green` fails one handoff later",
  "a broken helper raising inside an item is classed BEHAVIOUR; only flagged (HELPER file:line) when its own frame is first in the stacktrace",
  "a rebase or squash orphans sha-keyed evidence and the order; merge commits are skipped, so a test edit made while resolving a conflict is seen only by the reviewer (`git show --cc`)",
  "H5 compares top-level expressions: a declaration-only struct can still hide behaviour in a field type or a `Base.@kwdef` default (a macro call is not a declaration, so @kwdef fails H5)",
  "mutate proves the item fails for ONE mutation, not how strong it is; `mutexp` (wrong expectation) proves only that the assertion runs",
  "gaps: a public name counts as tested if it appears as a whole word anywhere in test/ (short names like `map` give false positives); needs Julia >= 1.11 for Base.ispublic"
]
```

## 5. Backfilling missing tests (D5)

### 5.1 Finding the gaps: `tdd.jl gaps`

1. **Public names with no test.** For the names exported or `public` in the package module, gaps
   loads the package on Julia ≥ 1.11, since 1.10 has no `Base.ispublic` and ChuiCore's API is mostly
   `public` (ADR-0005) (m2). It searches for each name as a whole word in `test/**/*.jl`. The list is
   crude and is only the starting point.
2. **Uncovered lines.** With `--lcov FILE` (made from `CI_COVERAGE=true julia scripts/ci.jl test`
   plus CoverageTools in a scratch environment), gaps lists the zero-hit lines grouped by function.
   Whether local coverage works is UNVERIFIED; plan Task 6 checks it, and a CI artifact is the
   fallback.
3. **The floor.** Every package has `coverage.floor = 0.0` today. After a package's backfill merges,
   the lane reports the measured coverage, and the lead proposes a floor 1 point below it. The user
   decides, since the file is T3.

Rank the gaps in this order: public API with no test; error paths; the edge cases the docs name;
internals reached through the public API.

### 5.2 Proving a characterization item can fail: `tdd.jl mutate`

The order, which fixes B3:

1. The test-writer commits a few items with `TDD: backfill`.
2. For each item, against that committed HEAD (on a dirty tree mutate exits 2), it runs
   `tdd.jl mutate`.

Each mutate run:

1. **Scratch copy (M8).** Use one persistent scratch worktree per lane:
   `.lanes/scratch/mutate/`, created once with `git worktree add --detach`, then moved to HEAD with
   `git checkout --detach <sha>` before each run. tdd.jl copies the gitignored `Manifest.toml` and
   `Manifest-v1.10.toml` into it, so nothing re-resolves and nothing needs the network. Its
   precompile cache stays warm between mutants. A copy per mutant was rejected because each one is
   a fresh precompile, and on 1.10 a re-resolve.
2. **Mutation.** Apply one textual replacement, `--from` to `--to`, at `--src F:LINE` (in `src/`;
   the default proof) or `--expect F:LINE` (the item's expected value in `test/`; the fallback,
   m5). It is exit 2 if `--from` is not on that line.
3. **Run.** Run the item there (`item=NAME`, with `TDD_MATCHED` set). It must be matched and FAIL
   with an `ASSERTION` or `BEHAVIOUR` on a non-`@test_broken` assertion. A `WRONG-REASON` result
   means the mutation broke loading, so pick another.
4. **Restore.** Restore the file (`git checkout -- F` in the scratch copy) in a `finally` block.
5. **Real tree.** Run the item in the real tree too: it must be matched and pass, with a total of
   at least 1.
6. **Evidence.** Write `mutate-<slug>` (source) or `mutexp-<slug>` (expectation). The slug is the
   item name lowercased, with each run of non-`[a-z0-9]` characters replaced by `-`, cut to 24
   characters, then `-` and the first 8 hex digits of the name's SHA-1. That is 7 + 24 + 1 + 8 =
   40 characters at most, which fits evidence.jl's KIND rule, so items never share a file.

Only the default Julia (1.13) runs mutants. A characterization item is not version-specific, and
the full suite on `julia +lts` still runs at the end of the lane.

**Cost and cap (M8).** These are estimates, UNVERIFIED.

- **Per mutant:** a recompile of the mutated package with its test dependencies already warm, plus
  the item run. That is 30–120 s for ChuiCore-sized packages, so 60 items take about 0.5 to 2 hours
  of machine time.
- **Cap:** plan Task 11 measures one area first (about 10 items). When the projection for the
  package exceeds **2 hours per lane**, the lead splits the backfill into area lanes. Lanes in one
  repo run one at a time, because they share the depot's precompile locks. Or the user accepts the
  cost at a ★ checkpoint. Sampling items, with the rest left unproved, is not allowed.

### 5.3 Bugs found

- **When docs and behaviour disagree:** write the item for the documented behaviour, with
  `@test_broken` on the failing assertion and the comment `BUG: <one line>; reported <date>`. List
  the bug in the report. Fixing it is an ordinary TDD lane: its first commit is a `test-fix` that
  turns `@test_broken` into `@test`, which `tdd.jl red` checks.
- **When the docs are silent:** do not guess. The lead routes the question to the package's
  architect.

### 5.4 Lanes and order

One backfill lane per package, in that package's repo. File scope: `test/**` minus the specialist
paths, plus its fragment. Mode `required`; the lane changes no code, so H1 passes, and E3 still
applies.

| Order | Package | When |
|---|---|---|
| 1 | ChuiCore.jl | after its 0.3.0 sync lane merges. That sync waits for the v0.0.1 tag, and ChuiCore has no tag yet. |
| 2 | ChuiTypes.jl | after `feat/phase5`, `feat/p5-perf` and `feat/p5-ttfx` merge (they edit `test/**`) and its 0.3.0 sync merges. Its `chore/sync-027` branch is already merged (08e9468); it was only not deleted. |
| 3 | ChuiFrames.jl | after its `feat/p4-*` branches merge and its 0.3.0 sync merges. Its `chore/sync-027` is merged (bc8c97a). |

## 6. Cost and skips (D8)

**Cost.** Today's single implementer turn becomes:

- STUB (sometimes);
- RED;
- GREEN, then REFACTOR;
- a dispute round (sometimes).

That is 2–4 more agent handoffs per task, each with a fresh context, run in sequence. Expect
roughly 1.5–2× the wall-clock per task (an estimate; plan Task 8 measures it).

**Modes.** The lead decides in the brief. The lane's first commit carries
`TDD-Mode: <mode> — <reason>`; the reason is required for `refactor` and `skip`. That trailer is the
**only** source: `lane.jl` gets no TDD config (M5).

| Case | Mode |
|---|---|
| No `src/`/`ext/` change (docs, benchmarks, CI, tests only, backfill) | none needed (H1) |
| A pure refactor that keeps behaviour | `refactor` |
| A spike or prototype that will not merge | `skip` (it never lands) |
| An urgent fix | `required`: the red item is the reproducer |
| Anything else that touches `src/`/`ext/` | `required` (the default) |

## 7. Rollout (D6, D7)

### 7.1 Version: 0.3.0

The factory CHANGELOG rule says: "A breaking change (a renamed file, a new required field, a
stricter guard) bumps the minor version while below 1.0." This release has all three kinds of
change:

- a stricter guard: dod's `tdd` requirement;
- a narrowed role: the implementer loses `test/**`;
- a new required seeded edit: `item=` and `TDD_MATCHED`.

The lead chose patch bumps for 0.2.6 and 0.2.7, where the stricter rule only blocked what was always
meant to be blocked. Here every code lane's workflow changes. **Recommendation: 0.3.0.**

### 7.2 What each repo needs

| Repo | Sync brings (managed) | Hand edits (seeded; T3 there) |
|---|---|---|
| ChuiCore.jl | tdd.jl and its three helpers, test_tdd.jl, test_writer.md, the changed bodies, `checks.toml`, `dod.jl`, `/change-review`, the lane-lifecycle skill | the registry entry and the implementer scope; `risk.toml` (`tdd` added to T1–T3 `requires`, the 4 new scripts added to the T3 globs); `test/runtests.jl` (the selection block). Waits for v0.0.1. |
| ChuiTypes.jl | same | same; after its phase-5 branches merge |
| ChuiFrames.jl | same | same; after its `feat/p4-*` branches merge |
| coordinator | same managed files (the body is unused) | `risk.toml`: the 4 new scripts in its T3 globs. The registry is unchanged (D7). |

**D7.** The coordinator has no `test/` tree; the profile excludes `test/*`. Its tests are the
factory's `scripts/test/*`, which `coord_factory_maintainer` writes. **Recommendation:** no
coordinator test-writer, and no `tdd` in its tiers, because the coordinator has no code paths in
H1's sense. Revisit if factory changes keep landing with tests written after the code.

### 7.3 Approvals the user gives (plan Task 0, before any build)

1. **ADR-0015**, "Test-first lanes with a separate test-writer" (coordinator `adr/`). It records D1
   (the 13th role), D3, D4, D6 and the answers to §9. The user accepts it **before** plan Task 1
   (M7).
2. **`FACTORY_ALLOW_T3=1`** for the coordinator sync session (Task 9). The sync writes
   `.agents/bodies/*`, `scripts/*` and `.agents/checks.toml`.
3. **Per package:** the hand edits (§7.2), and later the `coverage.floor` raise (§5.1).

### 7.4 Template tests to add

- **scripts/test/test_tdd.jl (new):**
  - the classifier on the recorded fixtures: every class, on both versions, including the measured
    `stub outside test` → BEHAVIOUR, `typo outside` → WRONG-REASON,
    `@test_throws` + `Thrown: UndefVarError` → WRONG-REASON, `new method on existing g` → BEHAVIOUR,
    the helper → BEHAVIOUR + HELPER, the nested testset prefix, `ERROR: LoadError: Some tests did not pass` ignored,
    and `Total 0` → NOT-RUN;
  - each history rule H1–H8, on synthetic commit lists and on a scratch git repo for H5;
  - each evidence rule E1–E4;
  - mutate: a killed mutant, a surviving mutant, a load-breaking mutation, a dirty tree, an
    unmatched name, the scratch file restored after a throw, two items at one sha giving two files;
  - gaps.
- **`test_dod.jl`:** the `tdd` requirement, delegating to the history rules.
- **`test_gen.jl`:** 13 agents, and the implementer scope without `test/**`.
- **`test_runtests_template.jl`:** `item=` selection, `:contract` never selected, the stable-only
  exclusion kept for named items, and `TDD_MATCHED` recording.

**Dogfood limit (m7).** The factory's own tests are `@testset`s in `scripts/test/`, not
`@testitem`s, and the factory has no `src/`. So `tdd.jl red` cannot classify the factory's reds,
and `tdd.jl audit` on the factory lane passes vacuously through H1. Plan Tasks 1–8 use a separate
test-writer subagent and paste the raw failing output. That is process discipline, not a
mechanical check, and the report must say so.

## 8. Not in scope

- Implementing any of this.
- Mutation testing as a metric.
- Changing how law, property and differential tests are written.
- Negation in `--owns` or `risk.toml` globs.
- TDD config in `lane.jl`.

## 9. Open questions for the user (each with a recommendation)

1. **A 13th role?** Yes (§2.1).
2. **An implementer touching `test/**`: FAIL or a reviewer flag?** FAIL. It is history rule H4,
   checkable without evidence.
3. **New names: STUB commits, or accept a red with `UndefVarError`?** STUB commits (§3.2). New
   methods and changed behaviour need no stub, because `MethodError` counts as BEHAVIOUR.
4. **0.3.0 or 0.2.8?** 0.3.0 (§7.1).
5. **Backfill proof: a source mutation (default) or a wrong expectation?** A source mutation, with
   `mutexp` as a reported, justified fallback (§5.2).
6. **A cap on mutation cost?** 2 hours of machine time per backfill lane; above it, split into area
   lanes or accept the cost at a checkpoint, never sample (§5.2).
7. **Raise `coverage.floor` after each backfill?** Yes: 1 point below the measured value, set by the
   user.
8. **A coordinator test-writer?** No (D7).

## 10. Revision 2: critic findings → changes

| Finding | Change |
|---|---|
| B1: a lane with no red could pass | H2 (≥1 red), H6 (stub before red; one green per red; refactor and test-refactor after a green), H7 (do not end on red), E2 (refactor has its own green evidence), H5 (stub is declaration-only, a mechanical top-level expression check) |
| B2: no legal red for a new method | `MethodError` is BEHAVIOUR when it is under an in-item header (§3.3). Throwing method stubs were rejected, with reasons (§3.2). The reviewer checks the arguments (§4.5) |
| B3: mutate evidence overwritten; wrong order | Kinds `mutate-<slug>` and `mutexp-<slug>` (40 characters); commit first, mutate against the committed HEAD; dirty is exit 2 (§5.2) |
| M1: wrong output model | Headers only, with the measured format; one `LoadError: ` prefix stripped; the `Some tests did not pass` line ignored; a helper is BEHAVIOUR plus a HELPER flag, with the blind spot rewritten (§3.3, §4.6) |
| M2: `@test_throws` masking | `Thrown: UndefVarError\|LoadError\|ParseError` makes a block WRONG-REASON; a blind spot for law and property kits and try/catch; the claim narrowed (§3.3, §4.6) |
| M3: vacuous runs | `TDD_MATCHED` file plus NOT-RUN; a minimum total for green and mutate (§3.4) |
| M4: the test ban was not enforced | H3/H4 from history, also in dod (§4.2) |
| M5: CI does not run; two sources for the mode | Local dod and audit before every merge; the register's `runs_in` corrected; the `TDD-Mode:` trailer is the single source and `lane.jl` gets no TDD config (§4.4, §6) |
| M6: rebase | Merge, never rebase; `--no-merges`; patch-id was rejected; what happens after a rebase (§4.4) |
| M7: the ADR came late | ADR-0015 is plan Task 0, before Task 1 (§7.3) |
| M8: mutate cost | A persistent scratch worktree with the manifests copied in; mutants only on 1.13; an estimate and a 2 h cap (§5.2) |
| m1: setup modules | Items using a changed `@testmodule`/`@testsnippet` run and must pass (COLLATERAL); module files fall under H3/H4 like any `test/**` path (§3.3) |
| m2: gaps on 1.10, short names | Julia ≥ 1.11 only; the false positives are a blind spot (§5.1, §4.6) |
| m3: merge commits | `--no-merges` (§4.2) |
| m4: `@test_broken` | Items with only broken assertions are exempt from E3 and listed; a kill must come from a non-broken assertion (§4.3, §5.2) |
| m5: the wrong-expectation proof is weaker | A separate kind, `mutexp-` (§5.2) |
| m6: rollout order | Corrected (the lead's correction): `chore/sync-027` is merged in ChuiTypes (08e9468) and ChuiFrames (bc8c97a); ChuiTypes waits on `feat/phase5`, `p5-perf` and `p5-ttfx` (§5.4) |
| m7: dogfood audit is vacuous | Stated as a limit: the factory's reds are pasted raw and do not count as a mechanical review (§7.4) |
| m8: nobody refactors tests | A `test-refactor` phase for the test-writer, after a green, with green evidence; the reviewer checks no assertion is weakened (§2.2, §3.1) |
| m9: `item=` bypassed exclusions | `:contract` is excluded first and the stable-only exclusion is kept for named items (§3.4) |
