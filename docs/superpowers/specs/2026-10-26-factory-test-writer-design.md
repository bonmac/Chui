# Factory 0.3.0: a `test-writer` role and test-first lanes

- **Date:** 2026-10-26
- **Lane:** testwriter-spec (coordinator; this spec and its plan only)
- **Asked by the user:** "plan the test-writer role. It should follow proper TDD principles. Write
  any missing tests once done."
- **Tier:** T3 in every repo that takes it: the registry, agent bodies, gate scripts, their tests
  and `risk.toml` change. Implementing it needs the user's `FACTORY_ALLOW_T3=1` (§7) and an ADR
  (ADR-0015, §7.3).
- **Plan:** `docs/superpowers/plans/2026-10-26-factory-test-writer.md`
- **Status:** design only. Nothing here is implemented. Facts not yet checked are marked UNVERIFIED.

## 0. Problem

Today the `implementer` role writes both the test and the code (`file_scope = ["src/**",
"test/**", "ext/**", "changelog.d/**"]`, rule "Test first: write the failing test, run it, see it
fail, then implement"). Nothing checks that rule:

- `dod.jl`'s `tests` requirement passes when `test/` changed at all, in any commit, in any order
  (`docs/CHECK_COVERAGE.md`: "that the changed tests test the changed code").
- No evidence records that a test was ever red, or why it was red.
- An agent that wrote the code also chooses the test, so its tests tend to restate the code it
  wrote instead of the spec.

The specialist testers (law, property, differential) already prove that their tests can fail
("plant a violation locally, show the failure"). Ordinary unit and example tests have no such
rule. The packages also have gaps: every package's `coverage.floor` is `0.0`
(`ratchets.toml` in ChuiCore.jl, ChuiTypes.jl and ChuiFrames.jl, read 2026-10-26).

## 1. Decision summary

| # | Question | Decision (recommended) |
|---|---|---|
| D1 | The role | A 13th template role `test_writer` / `test-writer`, `write` mode, unit and example tests only. The implementer loses `test/**`. |
| D2 | TDD protocol | Per behaviour: optional STUB (implementer) → RED (test-writer) → GREEN (implementer) → REFACTOR (implementer, tests unchanged). Commits carry a `TDD:` trailer. |
| D3 | Right-reason red | A new script scripts/tdd.jl runs the RED commit's new test items and classifies every failure. Only an assertion failure or a behaviour exception counts. Load errors, `UndefVarError`, parse errors, missing files and a test that passes are all rejected. |
| D4 | Enforcement | `tdd.jl audit` (local, reads evidence) and a `tdd` requirement in `dod.jl` (CI, history only) check order and that GREEN/REFACTOR commits do not touch the RED tests. Reviewer checklist. A new row in `.agents/checks.toml`. |
| D5 | Backfill | Characterization tests in `TDD: backfill` commits. Each one is proved able to fail by `tdd.jl mutate`, which runs it against a mutated scratch copy. Gaps come from `tdd.jl gaps` (public names with no test, and uncovered lines from lcov). One lane per package: ChuiCore first, the others after their running branches merge. Bugs are reported as `@test_broken`, not fixed. |
| D6 | Version | 0.3.0, a minor bump, because a guard gets stricter and a role's scope narrows (factory CHANGELOG rule). |
| D7 | Coordinator | The coordinator registry does not take the role. The body file arrives anyway (bodies are managed) and stays unused, like `implementer.md` today. |
| D8 | Cost and skips | 2 to 4 extra handoffs per task. The lead decides a skip in the brief and records it with `lane new --tdd`. T0 and lanes that touch no `src/`/`ext/` skip without being asked. |

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
scorecard = ["each test derived from the spec or public docs, cited", "RED evidence: every new item fails for the right reason (tdd.jl red)", "one behaviour per test item, no implementation details asserted", "backfill: every characterization test killed a mutant (tdd.jl mutate)", "stays out of src/ and the specialist test files"]
output_format = "behaviours and their sources, test items written, tdd.jl red or mutate output, disputes and bugs found, checks not run and why, scorecard"
```

`file_scope` cannot express "test/** except the specialist files". Lane `--owns` globs have no
negation, and adding negation to `lane.jl` and `risk.toml` globbing is not worth the change. The
exclusions go in the body instead, and the lead's per-lane `--owns` narrows the scope to real
files (for example `test/stream_unit_tests.jl`).

- The test-writer does **not** edit:
  - `test/laws/**`, `test/property/**`, `test/differential/**`, `test/contracts/**`, `test/jet/**`;
  - test items tagged `:laws`, `:property`, `:differential`, `:contract` or `:quality`, wherever
    they live. ChuiCore keeps its law tests flat (`test/*_laws_tests.jl`, `*_planted_tests.jl`),
    so a path rule alone would be wrong there.
  - seeded runners (`test/runtests.jl`, `test/Project.toml`).
- The test-writer **does** own fixtures and helpers that only its own items use.

Why a 13th role, against ADR-0001's "12 roles; prune by unused for N phases" and the registry's
"never add a 13th without asking whether an existing role covers it":

- **implementer:** no. The whole point is that the author of the code is not the author of its
  test.
- **law-tester and property-tester:** no. They test algebraic laws and invariants with
  generators. A behaviour such as "`select` on a missing column throws `ArgumentError` naming the
  column" is neither.
- **differential-tester:** no. It needs a reference implementation.
- **critic and reviewer:** they are read-only.

So no existing role covers this. The user asked for the role, which is the "asking" the registry
comment requires. ADR-0015 records it (§7.3).

### 2.2 Body (.agents/bodies/test_writer.md, managed)

Operating rules, in this order:

1. Derive each test from a stated source: a spec or plan line, a docstring, `docs/src/`, a
   contract entry, or an ADR. Cite it in the test item's name or a one-line comment. In a TDD lane
   you read no `src/` beyond the STUB commit's diff. You never test code you wrote yourself.
2. One behaviour per `@testitem`. Name the behaviour, not the function, for example
   `"select: unknown column throws ArgumentError naming it"`. Use few assertions, all about that
   behaviour.
3. Test through the public API only.
   - Never assert private fields, internal function names, call counts, allocations (that is the
     benchmarker's job, or a `:quality` item) or exact `show` output (a `:snapshot` item).
   - Tests may call names that are `export`ed or `public` (Julia ≥ 1.11), and names the spec
     marks as API.
4. RED: commit the tests alone, with the `TDD: red` trailer, then run
   `tdd.jl red` and paste its output. If any item is `WRONG-REASON` or `PASSED`,
   fix the test, `git commit --amend`, and run it again. Report only a clean red.
5. Never edit `src/`, `ext/` or `Project.toml`. Name a missing stub in your report; the
   implementer adds it (§3.2).
6. If the implementer disputes a test, answer in one of two ways:
   - a `TDD: test-fix` commit that changes the test and re-runs `tdd.jl red` on it; or
   - a written reason why the test stands.

   The lead decides when you disagree.
7. Backfill mode (§5): `TDD: backfill` commits, `tdd.jl mutate` evidence for each item, and a
   bug becomes `@test_broken` plus a report line. Never fix it yourself.
8. The shared rules: Edit/Write only, a changelog fragment, report the changed files as a list,
   and say which checks did not run.

### 2.3 What changes for the other roles

| Role | Change |
|---|---|
| implementer | `file_scope = ["src/**", "ext/**", "changelog.d/**"]`. Role line: "Implements one planned task against the test-writer's red tests: minimal code to green, then refactor with tests unchanged." Rules: never edit a test, and send a disputed test back to the test-writer; STUB commits declare and never implement; GREEN is the minimal code that passes the red items; REFACTOR keeps every test file unchanged. Scorecard: "failing test written first" becomes "RED commit precedes code; tdd.jl audit OK". |
| law-tester, property-tester, differential-tester | Unchanged scope. One added line: "In a test-first lane, commit your new items with `TDD: red` before the code; `tdd.jl red` checks them like any other." Their "plant a violation" rule stays: it is the backfill-style proof for tests of existing code. |
| reviewer | Checklist items in §4.4. |
| contract-steward | Unchanged. `:contract` items are its own. |

## 3. TDD protocol inside one lane (D2, D3)

### 3.1 Cycle

A lane covers one planned task, which holds one or more behaviours. For each behaviour, or each
small group the plan names, the cycle is:

```
[STUB]   implementer  declarations only            TDD: stub      (only when new names are needed)
RED      test-writer  failing tests only           TDD: red       + tdd.jl red evidence
GREEN    implementer  minimal src/ext change       TDD: green     + tdd.jl green evidence
REFACTOR implementer  src/ext only, tests same     TDD: refactor  + tdd.jl green evidence
```

- The lane is one worktree and one branch. The two agents take turns; they never run at the same
  time, since they share a working tree. The lead dispatches them in order (or runs them as a
  two-member team with a strict handoff). Each agent commits before it hands over.
- Small steps: a RED commit holds at most a few items for one behaviour. A plan task with five
  behaviours runs five cycles, not one big red.
- The commit trailer, a git trailer on its own line in the message, is `TDD: <phase>`, where the
  phase is one of `stub | red | green | refactor | test-fix | backfill | skip`. `skip` takes a
  reason (`TDD: skip — docs only`).

### 3.2 Stubs, signatures and "the right reason"

A test for a name that does not exist yet fails with `UndefVarError`. That is a load-style
failure: it also catches a typo in the test, so it proves nothing about behaviour. So when new
public names are needed, the implementer first commits a STUB:

- `function f end` for a new generic function (no methods);
- the new `struct`s with their fields as the spec gives them, plus the `export`/`public` lines and
  docstrings;
- no method bodies, no logic, no default values beyond what the spec pins.

A RED item then fails with `MethodError` on the stubbed function. That is the right reason: the
behaviour is missing. A changed behaviour of an existing function needs no stub.

`tdd.jl red` classifies each failure it attributes to a new item:

| Class | Output it matches | Counts as red? |
|---|---|---|
| `ASSERTION` | `Test Failed at <file>:<line>` | yes |
| `BEHAVIOUR` | `Error During Test at <file>:<line>` whose exception is not in the rejected list, such as a `MethodError` for a function the STUB commit declared, `ArgumentError` or `KeyError` | yes |
| `WRONG-REASON` | `UndefVarError`, `LoadError`, `ParseError`/`syntax:`, `could not open file`, `Package … not found`, `MethodError` for a function not declared in the lane's STUB commits and not exported upstream, a failure outside any test item, or a run that ended before its `Test Summary:` | no |
| `PASSED` | the item ran with no failure | no |
| `COLLATERAL` | a failure in an item the RED commit did not add or change | no (the run fails) |

The `MethodError` rule is mechanical. tdd.jl reads the names declared by `function NAME end` in
the lane's STUB diffs, and a `MethodError` on any other name is `WRONG-REASON`. A `MethodError`
from wrong argument order on a stubbed name still passes; the reviewer covers that (blind spot,
§4.5).

An item counts as RED only when it has at least one `ASSERTION` or `BEHAVIOUR` failure and no
`WRONG-REASON` failure. The run passes only when every new or changed item is RED and nothing is
`COLLATERAL`.

**Attribution.** tdd.jl finds the RED commit's added or changed `@testitem` blocks: their name,
file and line span, taken from the diff and a scan of the files. It maps each `at <file>:<line>`
in the output to the item whose span contains that line. TestItemRunner's exact failure output on
1.13.2 and 1.10.12 is UNVERIFIED. Plan Task 1 records it as fixtures before the classifier is
written.

**Running only the new items.** The seeded `test/runtests.jl` selects by tag only. 0.3.0 adds an
`item=<name>` argument form, so `ci.jl test -- item=NAME …` runs the named items whatever their
tags. That is a seeded-file change (hand edit in each package, as in 0.2.7). Rejected alternative:
run the whole suite and attribute failures. That is slower, and on a red branch it mixes the new
failures with the full run.

**Evidence.** `tdd.jl red` runs at the RED commit (committed first, so the evidence names its
sha) through `evidence.jl`. The kind is `red`, giving `.lanes/evidence/red-<sha7>.txt`. tdd.jl
appends its classification table to the output, so the file holds both. `tdd.jl green` writes
kind `green`: the same items, now all passing, plus the default suite.

### 3.3 GREEN and REFACTOR rules

- GREEN changes only `src/`, `ext/`, `changelog.d/` and, when the plan needs a dependency,
  `Project.toml` (T2). The red items pass and the default suite passes (`tdd.jl green`).
  "Minimal" is checked by the reviewer, not a script: no branch, option or method the red tests do
  not exercise.
- REFACTOR: the same file rule, the suite green before and after, and no test file changed.
- A test the implementer thinks is wrong goes back to the test-writer (rule 6 in §2.2). The
  implementer never edits it, even to fix a typo.

## 4. Enforcement (D4)

### 4.1 scripts/tdd.jl (new, managed, T3)

```
julia scripts/tdd.jl red    [--root DIR] [--commit REV]  classify the RED commit's new items (default HEAD)
julia scripts/tdd.jl green  [--root DIR]                 the lane's red items pass, plus the default suite
julia scripts/tdd.jl audit  [--root DIR] [--base B]      order + no-red-edit + evidence present, for the lane
julia scripts/tdd.jl mutate [--root DIR] --item NAME --file F --line N --from S --to S
julia scripts/tdd.jl gaps   [--root DIR] [--lcov FILE]   public names with no test; uncovered lines
```

It must stay under the `scripts/*.jl` 400-line budget. Split it, for example into
scripts/_tdd_classify.jl, before it grows past that.

### 4.2 `tdd.jl audit` (local; reads evidence)

For the commits `merge-base(base, HEAD)..HEAD`, oldest first:

1. Every commit that touches `src/` or `ext/` has a `TDD:` trailer. A missing trailer FAILS.
2. Every `green` commit has an earlier `red` (or `test-fix`) commit in the lane. A `red` commit
   touches only `test/**` and `changelog.d/**`. A `stub` commit touches only `src/**`/`ext/**`
   (reviewed for "declarations only").
3. No `green` or `refactor` commit modifies a file under `test/` that any `red`, `test-fix` or
   `backfill` commit of the lane touched. **Recommendation:** FAIL, not a reviewer flag. A shared
   helper the implementer must change goes through `test-fix` as well.
4. Every `red` and `test-fix` commit has a `red-<sha7>` evidence file with a passing
   classification. Every `green` commit has `green-<sha7>`. Every `backfill` commit has one
   `mutate` evidence file per item it added.
5. A `skip` trailer needs a reason. It is accepted only when the lane was created with
   `--tdd skip` (§6), or when no commit touches `src/`/`ext/`.

`/change-review` runs it with `lane audit`, and the reviewer pastes both.

### 4.3 `dod.jl` requirement `tdd` (CI; history only)

CI has no evidence files: they are gitignored, by design. So `dod.jl` checks rules 1, 2, 3 and 5
from the commit range alone and leaves rule 4 to `tdd.jl audit`. The tiers in the seeded
`risk.toml` gain `tdd` in T1, T2 and T3 (a hand edit in each package). The check lives in
`dod.jl`'s pure `evaluate` and takes a list of `(sha, trailer, changed paths)`.

A squash merge would erase the order. Chui lanes land as `--no-ff` merges (see `git log` on
coordinator `main`), and `dod.jl` runs on the PR range before the merge. The register says so.

### 4.4 Reviewer checklist (body additions)

- `tdd.jl audit` output pasted and OK, or the skip reason recorded in the lane config.
- RED items cite their source and assert behaviour, not implementation (no private names, no
  internals).
- The STUB diff declares only. GREEN is minimal: nothing the red items do not exercise.
- For every `BEHAVIOUR`-class `MethodError` in the red evidence, the arguments match the spec's
  signature.
- Backfill: each mutation is meaningful (it changes behaviour the item claims to test), not a
  syntax break.

### 4.5 Register row (`.agents/checks.toml`, rendered into `CHECK_COVERAGE.md`)

```toml
[[checks]]
id = "tdd"
rule = "In a test-first lane, every src/ext change follows a RED commit whose new test items fail for the right reason (assertion or behaviour, never a load error or a pass), GREEN/REFACTOR commits leave the red tests unchanged, and characterization tests each kill a mutant"
prevented_by = "scripts/tdd.jl"
runs_in = ["local /change-review (tdd.jl audit)", "ci Guards (dod.jl requirement `tdd`, history only)"]
test = "scripts/test/test_tdd.jl"
blind_spots = [
  "`TDD:` trailers are self-declared: one git identity serves every agent, so who wrote a commit is not checked (the lane ledger records which agents ran, not which commit each made)",
  "CI sees only the order and the files of commits, never the evidence (gitignored, .lanes/evidence/); a red that was never run passes CI and fails only `tdd.jl audit` on the machine that has the files",
  "that a test is derived from the spec and not from the code; that a test asserts behaviour, not implementation; that GREEN is minimal; that a STUB only declares",
  "a MethodError on a stubbed name with wrong arguments is classed BEHAVIOUR",
  "attribution is by file:line inside an item's span; a failure raised in a helper file outside the item is WRONG-REASON (a false negative the test-writer fixes by asserting in the item)",
  "a squash or rebase merge that rewrites the lane's commits loses the order; dod.jl checks the PR range before the merge",
  "mutate proves the test can fail for ONE mutation; it does not measure how strong the test is",
  "gaps: a public name mentioned in any test file counts as tested, even in a comment"
]
```

## 5. Backfilling missing tests (D5)

### 5.1 Finding the gaps: `tdd.jl gaps`

1. **Public names with no test:** names exported or `public` in the package module (read by
   loading the package in the test env), each searched for as a whole word in `test/**/*.jl`.
   Cheap, crude, and the first list to work from.
2. **Uncovered lines:** with `--lcov FILE`, from `CI_COVERAGE=true julia scripts/ci.jl test`
   plus `julia-processcoverage` (as CI.yml does), lines with zero hits grouped by function.
   Running coverage locally needs CoverageTools in a scratch env. That is UNVERIFIED here, and
   Task 6 of the plan checks it.
3. The current floor is `coverage.floor = 0.0` in all three packages. After a package's backfill
   merges, the lane reports the measured line coverage. The lead proposes to the user a floor 1
   point under it. `ratchets.toml` is T3, so the user decides.

The test-writer ranks the gaps: public API with no test first, then error paths (throws), then
edge cases the docs name (empty, `missing`, singleton), then uncovered internals reached through
public API.

### 5.2 Proving a characterization test can fail: `tdd.jl mutate`

A characterization test passes at once, so `tdd.jl red` does not apply. Instead:

1. tdd.jl copies the checkout to `.lanes/scratch/mutate-<item>/`, which is gitignored and inside
   the root, with `git worktree add --detach` or a plain copy. Plan Task 6 picks one.
2. It applies one textual mutation to `--file` at `--line`: replace `--from` with `--to`. Typical
   mutations flip a comparison, drop a branch, return the wrong value, or swap arguments.
3. It runs the item there (`item=NAME`) and records the evidence kind `mutate`. The item must FAIL
   with `ASSERTION` or `BEHAVIOUR`. A `WRONG-REASON` result means the mutation broke loading:
   pick another one.
4. It runs the item on the real tree, which must PASS.

**Recommendation:** use a mutation in `src/`, in a scratch copy, as the main proof. It shows the
test depends on the code. Fall back to a deliberately wrong expectation (mutate the test's
expected value in the scratch copy) only where no meaningful source mutation exists, such as a
constant or an error message, and say so in the report. The real `src/` is never edited; the
scratch copy is removed after the run.

### 5.3 Bugs found

When the documented behaviour and the observed behaviour disagree:

- The test-writer writes the item for the documented behaviour, with `@test_broken` on the
  failing assertion and a comment `BUG: <one line>; reported <date>`.
- It lists the bug in its report. The suite stays green, and the item becomes an "Unexpected Pass"
  error once someone fixes the code, which flags the stale `@test_broken`.
- The fix is an ordinary test-first lane. Its RED commit turns `@test_broken` into `@test`
  (`TDD: test-fix`).
- When the docs are silent, the test-writer does not guess. It asks, and the lead routes the
  question to the package's architect.

### 5.4 Lanes and order

One backfill lane per package, in that package's repo, file scope `test/**` (minus the specialist
paths, §2.1) plus its fragment:

| Order | Package | When | Why |
|---|---|---|---|
| 1 | ChuiCore.jl | as soon as 0.3.0 is synced there | no lane is running; its 0.3.0 sync itself waits for the v0.0.1 tag (§7.2) |
| 2 | ChuiTypes.jl | after `feat/phase5` (and `feat/p5-*`) merge | those branches edit `test/**` now |
| 3 | ChuiFrames.jl | after its phase-4 branches (`feat/p4-*`) merge | same |

A backfill lane may split by area, for example `backfill-optics` and `backfill-schemes`, as long
as the file scopes are disjoint and the repo's lane cap allows it.

## 6. Cost and skips (D8)

**Cost.** Today's single implementer turn per task becomes:

- STUB (implementer), when needed;
- RED (test-writer);
- GREEN and REFACTOR (implementer);
- a dispute round, sometimes.

That is 2 to 4 more agent handoffs per task, each with a fresh context that has to read the spec
and plan. Tests and code are written in sequence, not in parallel. Expect roughly 1.5 to 2 times
the wall-clock per task. This is an estimate, not measured; the plan's dogfood task (Task 8)
measures it once.

**Skips.** The lead decides in the brief, and records the decision with
`scripts/lane new <name> --tdd required|refactor|skip --why "<reason>"`. That sets
`branch.<b>.lane-tdd`, and `tdd.jl audit` honours it.

| Case | Mode | Who decides |
|---|---|---|
| T0 change, or no `src/`/`ext/` touched (docs, benchmarks, CI-only, test-only) | `skip`, automatic | nobody: `tdd` passes when nothing in `src/`/`ext/` changed |
| Pure refactor, behaviour unchanged | `refactor`: implementer only, suite green before and after, no test file changed | the lead, in the brief |
| Spike, prototype or research code that will not merge | `skip` | the lead; the branch never lands |
| Urgent fix | `required` still. The RED item is the reproducer, so the cycle costs one handoff | — |
| Anything else that touches `src/`/`ext/` | `required` (default) | — |

A `skip` on a lane that changes `src/` also needs a `TDD: skip — <reason>` trailer on the commit,
so CI's `dod.jl` sees it. The reviewer checks that the reason holds.

## 7. Rollout (D6, D7)

### 7.1 Version: 0.3.0

The factory CHANGELOG rule: "A breaking change (a renamed file, a new required field, a stricter
guard) bumps the minor version while below 1.0." 0.3.0 has:

- a stricter guard (the `dod.jl` `tdd` requirement fails lanes that pass today);
- a narrowed role (the implementer loses `test/**`);
- a new required seeded edit (runtests `item=`).

The lead chose patch bumps for 0.2.6 and 0.2.7, where the stricter rule only blocked what was
always meant to be blocked. Here the workflow of every code lane changes, so a patch would hide
that. **Recommendation: 0.3.0.**

### 7.2 What each repo needs

| Repo | Sync brings (managed) | Hand edits (seeded; T3 in that repo) |
|---|---|---|
| ChuiCore.jl | `tdd.jl`, `_tdd_classify.jl`, `test_tdd.jl`, `test_writer.md` and the changed bodies, `checks.toml`, `dod.jl`, `lane.jl`, `/change-review` | the registry gets the `test_writer` entry and the implementer's scope; `risk.toml` gets `tdd` in T1–T3 and the new scripts in the T3 globs; `test/runtests.jl` gets `item=`. **Waits** until v0.0.1 is tagged (HANDOFF: "ChuiCore's 0.2.7 sync waits until after the tag"). |
| ChuiTypes.jl | same | same; after its phase-5 branches merge, so the sync does not change the rules mid-phase |
| ChuiFrames.jl | same | same; after its phase-4 branches merge |
| coordinator | same managed files (body unused) | `risk.toml`: the new script paths in its T3 globs. The registry is unchanged (D7). |

**D7, the coordinator.** The coordinator has no `test/` tree; the coordinator profile excludes
`test/*`. Its tests are the factory's own `scripts/test/*`, which `coord_factory_maintainer`
writes as part of each T3 factory change. **Recommendation:** do not add a coordinator test-writer.
`tdd` in the coordinator's `risk.toml` would pass anyway (no `src/`/`ext/`), so leave it out there.
Revisit if factory script changes keep landing with tests written after the code.

### 7.3 Approvals the user must give

1. `FACTORY_ALLOW_T3=1` for the implementation lane (`factory/**` is T2 in the coordinator, but
   the coordinator sync writes `.agents/bodies/*`, `scripts/*` and `.agents/checks.toml`, which
   are T3).
2. ADR-0015 "Test-first lanes with a separate test-writer" (coordinator `adr/`), accepted by the
   user. It records D1 (13th role), D3 and D6.
3. Per package: the hand edits in §7.2 (T3 there) and later the `coverage.floor` raise (§5.1).
4. The decisions marked "open" in §9.

### 7.4 Template tests to add

- scripts/test/test_tdd.jl:
  - the classifier on recorded fixtures (each class, both Julia versions);
  - `audit` on scratch repos with good and bad histories (green before red, a green commit editing
    a red test, a missing trailer, missing evidence, skip without a lane mode);
  - `mutate` on a scratch package (a killed mutant; a surviving mutant fails; a load-breaking
    mutation is WRONG-REASON);
  - `gaps` on a scratch package with one tested and one untested export.
- `test_dod.jl`: the `tdd` requirement, with pass, fail and skip cases on synthetic commit lists.
- `test_gen.jl`: the registry has 13 agents, `test-writer` is generated, the implementer has no
  `test/**`.
- `test_lane.jl`: `--tdd` and `--why` are recorded, and a bad mode is rejected.
- `test_runtests_template.jl`: `item=` selects by name, and works next to tags.

## 8. Not in scope

- Implementing any of this. It needs T3 approval; the plan's tasks run in a factory-maintainer
  lane.
- Mutation testing as a coverage metric, such as running every mutant over the suite. `mutate` is
  a single proof per item.
- Changing how law, property and differential tests are written.
- Adding negation to `lane --owns` or `risk.toml` globs.

## 9. Open questions for the user (each with a recommendation)

1. **13th role, or fold it into an existing one?** Recommendation: a 13th role (§2.1). No existing
   role can write black-box tests for code it did not write.
2. **Rule 3 of the audit, an implementer edit to a red test: FAIL or reviewer flag?**
   Recommendation: FAIL. A flag lets the GREEN agent weaken the test that judges it, and
   `test-fix` costs one handoff.
3. **Stubs: implementer STUB commits, or let RED fail with `UndefVarError`?** Recommendation: STUB
   commits. `UndefVarError` cannot tell a missing feature from a typo in the test.
4. **Version 0.3.0 or 0.2.8?** Recommendation: 0.3.0 (§7.1).
5. **Backfill proof: a source mutation in a scratch copy (default) or a wrong expectation?**
   Recommendation: a source mutation, with a wrong expectation as a reported fallback (§5.2).
6. **Raise `coverage.floor` after each backfill?** Recommendation: yes, to 1 point under the
   measured value, set by the user (T3).
7. **A coordinator test-writer?** Recommendation: no (D7).
