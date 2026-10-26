# Factory 0.3.0: a `test-writer` role and test-first lanes

- **Date:** 2026-10-26. Revision 2 addressed the critic's findings on `6b1c4f1`. Revision 3 makes
  context separation the goal, after the user clarified the purpose. Both tables are in §10.
- **Lane:** testwriter-spec (coordinator; this spec and its plan only)
- **Asked by the user:** "plan the test-writer role. It should follow proper TDD principles. Write
  any missing tests once done." Clarified purpose (relayed by the lead): "separate the tester
  from the implementer to have separate contexts and valid testing as per TDD."
- **Tier:** T3 in every repo that takes it, because the registry, the agent bodies, the gate
  scripts, their tests and `risk.toml` all change. Implementing it needs the user's
  `FACTORY_ALLOW_T3=1` and ADR-0015, which plan Task 0 asks for before any code is written (§7.3).
- **Plan:** `docs/superpowers/plans/2026-10-26-factory-test-writer.md`
- **Status:** design only; nothing is implemented. A fact not yet checked is marked UNVERIFIED.
  The critic's probes are taken as measured ground truth (TestItemRunner 1.3.2, Julia 1.13.2 and
  1.10.12, scratch package `TddScratch`; the output is in
  `.lanes/scratch/tw-critic/TddScratch/*.txt` of the main checkout, which is gitignored).

## 0. Goal and design principle: separate contexts

### 0.1 Goal

**Goal 1, the design principle:** the test is written in a context that has never seen the
implementation, and the code is written against tests its author cannot change. A test the
implementer wrote, or one written by an agent that has read the implementer's reasoning, tends to
restate the code instead of the spec. Then "red, then green" proves only that the code agrees with
itself. Valid TDD needs a test that comes from the spec, so its red means "the behaviour is
missing" and its green means "the behaviour now exists".

Everything else in this spec serves goal 1 or gives evidence for it:

- **Separation itself:** two agent instances, a defined boundary (§0.3–0.4), briefs built by a tool
  (§0.5), per-role git authors (§0.6), and guards (§0.7).
- **Evidence that the separation held, and that the tests are valid:**
  - the `TDD:` trailers and the history rules (§4.2) show who changed what, in which order;
  - the classifier (§3.3) shows each red failed for a behavioural reason;
  - the audit (§4.3) shows the evidence exists.

  None of these is the point on its own.
- **Goal 2:** backfill the missing tests in the existing packages, under the same separation (§5).

### 0.2 Problem

Today the `implementer` writes both the test and the code, in one context:

- its `file_scope` is `["src/**", "test/**", "ext/**", "changelog.d/**"]`;
- its rule is "Test first: write the failing test, run it, see it fail, then implement".

Nothing separates the two, and nothing checks the rule:

- `dod.jl`'s `tests` requirement passes when `test/` changed at all, in any order. The register
  says the check cannot tell "that the changed tests test the changed code".
- No evidence records that a test was ever red, or why.
- The author of the code also picks the test.

The law, property and differential testers already prove that their tests can fail. Unit and
example tests have no such rule. Every package's `coverage.floor` is `0.0` (the `ratchets.toml` of
ChuiCore.jl, ChuiTypes.jl and ChuiFrames.jl, read 2026-10-26).

### 0.3 Two distinct agent instances per task

For each plan task, the lead or sub-lead dispatches:

- **one test-writer instance**, spawned fresh with `subagent_type: test-writer` and named
  `tw-<lane>-<task>`;
- **one implementer instance**, spawned fresh with `subagent_type: implementer` and named
  `impl-<lane>-<task>`.

These rules hold for every task:

- **Never one agent switching roles.** No agent is told "now write the tests" after writing code, or
  the reverse.
- **Never a fork of the other.** A `fork` inherits its parent's whole context. Neither role is ever
  dispatched as a fork, and neither is dispatched by an agent that has seen the other side.
- **Never resumed with the other's transcript.** An agent may be continued with SendMessage *within
  its own task*, because its transcript then holds only its own side. A new task gets fresh
  instances.
- **Neither role dispatches agents**, so neither can launder context through a sub-agent.
- **Use subagents, not tmux-pane teammates, in TDD lanes.** In-process teammates are fine. The
  guards in §0.7 identify a role by the hook field `agent_type`. Claude Code documents that field
  for subagents and in-process teammates (code.claude.com/docs/en/hooks, "Common input fields",
  read through Context7 on 2026-10-26). For a pane teammate, which is a separate process, it is
  UNVERIFIED, and plan Task 0 probes it.

### 0.4 What crosses the boundary, and only that

| To | Receives | Never receives |
|---|---|---|
| test-writer | the plan task text; the spec (path); the public API docs: `docs/src/` plus docstrings of public names, rendered by `tdd.jl api`; the **STUB diffs** of the lane, which H5 checks are declarations only; the test files and red evidence it made itself; written test-fix requests that passed `brief-check` | anything under `src/`/`ext/` beyond the STUB diffs; any GREEN or REFACTOR diff; the implementer's messages, reports or reasoning; the lane's changelog fragment, HANDOFF and `.lanes/reports/` |
| implementer | the plan task text; the spec; the **red test files** (paths; it reads them itself); the **red evidence** files | the test-writer's messages, reports or reasoning. It reads the tests, not why they were chosen, and may not edit them (H3/H4) |

**Disputes go in writing, through the sub-lead.** The two roles never talk to each other. The
implementer writes a **test-fix request** to the sub-lead. It names:

- the item;
- what is wrong *relative to the spec*, citing the spec line;
- the expected behaviour it proposes.

A request holds no source code: `brief-check` fails a request with a `src/` or `ext/` path, or a
line copied from a GREEN or REFACTOR diff. The sub-lead passes it, unchanged, inside a
`tdd.jl brief` to the test-writer. The test-writer answers with a `test-fix` commit, or with a
reason, which goes back to the implementer the same way. The lead decides when the two disagree.

### 0.5 Brief templates (built by `tdd.jl brief`, checked by `tdd.jl brief-check`)

The dispatcher does not write a role's brief by hand. It runs
`tdd.jl brief --role test-writer|implementer --task FILE [--requests FILE...]` and dispatches with
the output, adding nothing. The tool writes the brief to
`.lanes/briefs/<lane>/<role>-<task>-<n>.md` (gitignored), headed by
`<!-- tdd-brief role=<role> lane=<lane> head=<sha> -->`.

**test-writer brief:**

- **Includes:**
  - `## Task`: the plan task text, from FILE;
  - `## Spec`: the spec path;
  - `## Public API`: `tdd.jl api` output (docstrings of exported or `public` names; signatures, no
    bodies; needs Julia ≥ 1.11) plus a list of `docs/src/` pages;
  - `## Stub diffs`: `git show` of each `stub` commit in the lane, inside
    `<!-- stub-diff -->…<!-- /stub-diff -->`. They are included only if H5 passes;
  - `## Test-fix requests`: each one that passed `brief-check`;
  - `## Boundary`: the rules in §0.3–0.4, and the read guard in force.
- **Excludes**, and `brief-check` fails on:
  - a `src/` or `ext/` path outside the stub-diff block;
  - any line of 30 or more characters that also appears in a `green`, `refactor` or stub-*body* diff
    of the lane;
  - a missing or wrong header.

**implementer brief:**

- **Includes:**
  - `## Task`;
  - `## Spec`;
  - `## Red tests`: the paths of the files touched by the `red`/`test-fix` commits it must turn
    green, and their sha;
  - `## Red evidence`: the paths of the `red-<sha7>` files;
  - `## Boundary`: you may not edit `test/**` (H4), and disputes go as a test-fix request.
- **Excludes:** the test-writer's report and messages. `brief-check` fails on text taken from
  `.lanes/reports/tw-*`.

**How the briefs are enforced.**

- **At dispatch.** The `tdd_boundary` hook (§0.7) checks every Agent call with
  `subagent_type: test-writer` or `implementer`. It denies the call when:
  - the prompt lacks the matching `tdd-brief` header;
  - the name does not follow `tw-*` / `impl-*`;
  - the prompt has a `src/`/`ext/` path outside the stub-diff block (test-writer only).

  The hook also saves each prompt to `.lanes/briefs/<lane>/dispatched/`. SendMessage to a `tw-*`
  agent gets the same path check and is saved the same way.
- **At audit.** `tdd.jl audit` rule E5 re-runs the full `brief-check`, including the copied-line
  check, on every saved prompt and message.
- **At review.** The reviewer reads the saved briefs (§4.5).

### 0.6 Identity: a git author per role

- **Authors.** Each role's commits carry their own author:
  - `test-writer <test-writer@factory.invalid>` for `red`, `test-fix`, `test-refactor` and
    `backfill`;
  - `implementer <implementer@factory.invalid>` for `stub`, `green` and `refactor`.

  The committer stays the machine's user, and merges are the lead's.
- **History rule H9 (§4.2).** Each phase commit's author must be its phase's role. dod checks this
  too.
- **The commit guard ties the author to the harness, not to the agent's word.** For a `git commit`
  run in a session or subagent whose hook `agent_type` is `test-writer` or `implementer`, the
  `tdd_boundary` hook requires `--author` to name exactly that role. It denies other ways of setting
  the identity (`-c user.*`, `GIT_AUTHOR_*`/`GIT_COMMITTER_*` in the command). It also denies, *for
  any caller*, a commit whose `--author` names a role the caller is not. So the lead cannot write a
  `test-writer` commit either.
- **Staged paths are checked before the commit.** The same hook denies a test-writer commit with
  staged `src/`/`ext/`/`Project.toml`/`changelog.d/` paths, and an implementer commit with staged
  `test/**` paths (`git diff --cached --name-only`; about 10 ms).

**What this proves, and what it does not.** It turns "the trailer says test-writer" into "the
harness reported `agent_type = test-writer` for the process that ran `git commit`, through a
modelled command". So it partly closes the critic's "one git identity" blind spot. The author is
still not strong identity:

- one machine and one user set both authors;
- a commit made through a path bash_guard does not model gets past the commit guard: julia or
  `sh -c` code, `git commit-tree`, a script, or an amend run outside the hooks;
- the author records *which role committed*, not *what that agent had read*. The read guard (§0.7)
  and the briefs (§0.5) cover what it read.

The register's blind spot says exactly this (§4.6).

### 0.7 Mechanical guards: the `tdd_boundary` hook

**Feasible with the current hooks: yes.** PreToolUse hooks already run for every tool call,
subagents included, and per the Claude Code docs their input carries `agent_type` inside a subagent
(UNVERIFIED on this machine's version; plan Task 0 probes it). A hook can deny a call.
`bash_guard.sh` already parses Bash commands into words, wrappers and targets, and keeps a
read-only command allowlist for the read-only roots. So a new managed hook,
.claude/hooks/tdd_boundary.sh, with a library `_tdd_boundary_lib.sh` to stay under the 150-line
hook budget, is registered on `Read|Grep|Glob|Bash|Agent|SendMessage`. It applies only when
`agent_type` is `test-writer` or `implementer`, or when the call dispatches or messages one.

| Caller | Tool | Rule |
|---|---|---|
| test-writer | Read | deny a `file_path` under `<root>/src/`, `<root>/ext/`, any lane worktree's `src/`/`ext/`, `.lanes/reports/`, `.lanes/briefs/` (except its own), `changelog.d/`, `HANDOFF.md` |
| test-writer | Grep, Glob | deny unless `path` is given and is under an allowed prefix: `test/`, `docs/`, the spec and plan paths, `Project.toml`, `.lanes/evidence/` |
| test-writer | Bash | **allowlist, default deny**: `julia scripts/{tdd,ci,evidence}.jl …`; `git status`, `git add <test paths>`, `git commit` (the commit guard); `git diff/log/show` only with a pathspec under `test/` and without `-p` for other paths; `ls`, `cat`, `head`, `tail`, `wc`, `grep`/`rg` with explicit allowed-prefix paths. Anything else is denied, including `julia -e`, `sh -c`, `git show <sha>` without a pathspec, and `git blame` |
| both | Agent | deny: neither role dispatches agents |
| both | SendMessage | deny unless `to` is a lead name (`[tdd] lead_names` in `.agents/factory.toml`, default `["main", "team-lead"]`) |
| any | Agent with `subagent_type` test-writer/implementer | the brief checks in §0.5; save the prompt |
| any | SendMessage to `tw-*` | the path check; save the message |
| any | Bash `git commit` | the commit guard (§0.6) |

The implementer gets no read restriction. It is meant to read the tests, and nothing it reads
leaks back to the test-writer, since the reverse channel is guarded.

**Fails closed.** If the hook cannot parse its payload, or a library is missing, it denies, as the
other guards do. An `agent_type` that is absent leaves reads unguarded, because the hook cannot know
the role. That is why TDD lanes use subagents (§0.3).

### 0.8 Where separation still leaks

| Leak | Mitigation | Left as a blind spot |
|---|---|---|
| The test-writer reads src through git (`git log -p`, `git show <sha>`, `git blame`, `git grep`) | Bash allowlist: git only with `test/` pathspecs | git through code the guard does not model (julia, `sh -c`, scripts) is denied by the allowlist, but only for modelled command forms |
| Test code reads src at run time (`read(pathof(M))`, `@less`, `@which`, `methods(f)`, `code_lowered`, `include("../src/…")`), and the test-writer runs it | `tdd.jl red` lints the red diff for these forms and fails the run with class `BOUNDARY` | obfuscated or indirect forms; the lint is a pattern list |
| Run output: stacktraces name `src` files and lines, and `show` of a value can expose struct fields | Accepted: no source text is printed | yes: paths, line numbers and field values reach the test-writer |
| Shared repo files: `docs/src/` and docstrings written by the implementer | By design: public docs are API, and tests may rely on them | a docstring that describes implementation details |
| Shared repo files: the changelog fragment, HANDOFF, `.lanes/reports/` | The read guard denies them; the test-writer does not write the fragment (the implementer or the sub-lead does) | content copied into an allowed file |
| The sub-lead relays: pastes src or the implementer's reasoning into a brief or a message | `tdd.jl brief` builds briefs; the hook checks paths at dispatch and saves prompts; `brief-check` (E5) checks for lines copied from GREEN, REFACTOR or STUB bodies; the reviewer reads the saved briefs | a paraphrase ("make sure you test the cache path") passes every check, so only the reviewer catches it |
| The lead's own context holds both sides | The lead never writes tests or code in a TDD lane (CLAUDE.md "do not implement") | yes |
| Backfill mutation sites: the test-writer sees `file:line` and the `--from`/`--to` tokens of the lines it mutates | The sites come from `gaps --lcov`, proposed by the sub-lead or a helper; the tokens of one line only | yes: a narrow, deliberate leak (§5.4) |
| Same model, same priors: two instances of one model are separate contexts, not independent judges | Tests must cite the spec; reviewer; optionally a different `model` for test-writer (§9 Q9) | yes |
| A pane teammate without `agent_type` | It cannot make role commits (fail closed), but its reads are unguarded: use subagents | yes, until probed |
| Another harness (Codex agents in `.codex/agents/`) | None: the hooks are Claude Code's | yes |


## 1. Decision summary

| # | Question | Decision (recommended) |
|---|---|---|
| D0 | Context separation (goal 1) | Two fresh agent instances per task, never a role switch, a fork or a shared transcript. A defined boundary (§0.4). Briefs built by `tdd.jl brief` and checked at dispatch and at audit (§0.5). A git author per role, tied to the harness's `agent_type` by a commit guard (§0.6). A `tdd_boundary` hook that denies the test-writer reads of src, its git history and the other side's reports (§0.7). The remaining leaks are listed (§0.8). |
| D1 | The role | A 13th template role, `test_writer` / `test-writer`, in `write` mode, for unit and example tests only. The implementer's commits may not touch `test/**`, and the history check enforces that (§4.2 rule H4). |
| D2 | TDD protocol | Per behaviour: STUB (only for new names) → RED → GREEN → REFACTOR, plus `test-fix` and `test-refactor` for changing tests. Each commit carries a `TDD:` trailer, and the history has to follow the order in §3.1. |
| D3 | Right-reason red | `tdd.jl red` parses only the failure *headers* and classifies each one. An assertion failure counts, and so does any exception raised inside an item, `MethodError` included. Rejected: `UndefVarError`, parse or load errors, a load error caught by `@test_throws`, a run with no summary, a test that passes, and a run that matched no items. |
| D4 | Enforcement | `tdd.jl audit` runs the history rules H1–H9 (H9: per-role authors) plus the evidence rules E1–E5 (E5: saved briefs). `dod.jl` gets the history rules as requirement `tdd`. The lead runs both locally before every merge, since Chui merges locally. The lane mode has one source, a `TDD-Mode:` trailer. TDD lanes merge `main` in and never rebase. |
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
file_scope = ["test/**"]
scorecard = ["worked only from its tdd.jl brief: no src beyond the stub diffs, no implementer context", "each test derived from the spec or public docs, cited", "RED evidence: every new item fails for the right reason (tdd.jl red)", "one behaviour per test item, no implementation details asserted", "backfill: every characterization item killed a mutant (tdd.jl mutate)", "stays out of src/ and the specialist test files"]
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

0. **Your context is the boundary.** You work only from your `tdd.jl brief` (§0.4–0.5). Never read
   `src/`, `ext/`, their git history, the implementer's reports or the lane's changelog fragment,
   and never ask for them. The `tdd_boundary` hook denies most of these; the rest is on you. Write
   only to the lead. Commit with `--author "test-writer <test-writer@factory.invalid>"`.
1. **Derive each test from a stated source.** A source is a spec or plan line, a docstring,
   `docs/src/`, a contract entry or an ADR; cite it in the item name or a one-line comment.
   - Beyond the docs, the only view of `src/` you get is the STUB diffs in your brief.
   - Never test code you wrote. Never write test code that reads source (`pathof`, `@less`,
     `methods`, `read` of a src file): `tdd.jl red` fails such code as `BOUNDARY`.
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
6. **Disputes.** A dispute reaches you only as a written test-fix request inside a new brief, never
   as a conversation (§0.4). Answer with either:
   - a `TDD: test-fix` commit, re-checked by `tdd.jl red`; or
   - a written reason why the test stands, sent to the lead.

   The lead decides if you two disagree.
7. **`test-refactor`.** Restructure tests, for example extract a shared `@testsnippet`, only after
   a green. Commit with `TDD: test-refactor` and run `tdd.jl green`. No assertion may be removed or
   weakened; the reviewer checks this.
8. **Backfill** (§5). Commit items with `TDD: backfill`, then run `tdd.jl mutate` for each one
   against that commit. A bug becomes `@test_broken` plus a report line; never fix it yourself.
9. **Shared rules.** Edit/Write only. Report the changed files as a list, and say which checks did
   not run. You do not write the changelog fragment; the implementer or the sub-lead does, because
   it may describe the implementation.

### 2.3 What changes for the other roles

| Role | Change |
|---|---|
| implementer | `file_scope = ["src/**", "ext/**", "changelog.d/**"]`. New role line: "Implements one planned task against the test-writer's red tests: minimal code to green, then refactor with tests unchanged." New rules: you work from your `tdd.jl brief` (the task, the spec, the red test files and the red evidence), never from the test-writer's messages; commit with `--author "implementer <implementer@factory.invalid>"`; message only the lead, and dispatch no agents; never touch `test/**` (rule H4 fails the lane); a test you dispute goes to the sub-lead as a written test-fix request, with no source code in it (§0.4); you write the lane's changelog fragment; STUB declares only (rule H5 checks it); GREEN is the minimal code that passes the red items; REFACTOR only after a green. Scorecard: "failing test written first" becomes "tdd.jl audit OK". |
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

- **One worktree, two instances, turn-taking.** A lane is one worktree and one branch. Its two
  agents are separate instances (§0.3). They take turns, never run at once, and commit before they
  hand over. The sub-lead dispatches each one with a fresh `tdd.jl brief` and relays nothing else.
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
| `BOUNDARY` | the red diff's test code reads source (`pathof(`, `@less`, `@edit`, `@which`, `@code_`, `code_lowered`, `methods(`, `read(` or `open(` on a path containing `src/`, `include(` of a `src/` path); a lint run before the tests (§0.8) | no (the run fails) |

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
julia scripts/tdd.jl api    [--root DIR]               docstrings of exported/public names, no bodies (Julia >= 1.11)
julia scripts/tdd.jl brief  --role R --task FILE [--requests FILE...]   build a role's brief (§0.5)
julia scripts/tdd.jl brief-check --role R FILE        lint a brief, request or message against the boundary
```

The context-boundary hook, .claude/hooks/tdd_boundary.sh (with `_tdd_boundary_lib.sh`;
managed, T3), is specified in §0.7.

- Each file stays under the 400-line `scripts/*.jl` budget. The classifier goes in
  scripts/_tdd_classify.jl, the history rules in scripts/_tdd_history.jl (which `dod.jl` includes
  as well), mutate and gaps in scripts/_tdd_backfill.jl, and api, brief and brief-check in
  scripts/_tdd_brief.jl.
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
| H3 | Paths by phase. `stub`, `green` and `refactor` change no `test/**`. `red`, `test-fix`, `test-refactor` and `backfill` change no code, no `Project.toml` and no `changelog.d/`. |
| H4 | The implementer's test ban: no commit without a test-writer phase (`red`, `test-fix`, `test-refactor`, `backfill`) touches `test/**` (M4; this is H3 seen from the other side, listed for the register). |
| H5 | A `stub` adds only declarations. tdd.jl parses each changed `src`/`ext` file at the commit and at its parent (`Meta.parseall`) and compares the top-level expressions. The new ones may only be `function NAME end`; a `struct`/`mutable struct`/`abstract type`/`primitive type` whose body holds only field declarations (no inner constructors, no methods); `export`/`public`; a docstring attached to one of these; or `using`/`import`. Any other new or changed top-level expression FAILS. |
| H6 | Order. A `stub` is followed by a `red` before any `green`. Each `green` comes after a `red`/`test-fix` with no other `green` since that red (one green per red: squash small steps). A `refactor` or `test-refactor` comes after a `green`, with no `red` waiting for its green in between. |
| H7 | The last code-changing phase in the lane is `green` or `refactor`, so a lane does not end on a red. |
| H8 | Mode `refactor`: no `red`/`green`/`stub`; every code commit is `refactor`; no commit touches `test/**`. Mode `skip`: the `TDD-Mode:` line carries a reason, and no other rule applies. |
| H9 | Authorship (§0.6): every `red`, `test-fix`, `test-refactor` and `backfill` commit is authored `test-writer <test-writer@factory.invalid>`, and every `stub`, `green` and `refactor` commit is authored `implementer <implementer@factory.invalid>`. No commit without a phase carries either role author. Together with the commit guard, this ties each phase to the harness role that ran it. |

### 4.3 Evidence rules (`tdd.jl audit` only; the files are local and gitignored)

| Rule | Check |
|---|---|
| E1 | Every `red` and `test-fix` commit has `red-<sha7>` with a passing classification. |
| E2 | Every `green`, `refactor` and `test-refactor` commit has `green-<sha7>` that passed. In mode `refactor`, the merge base also needs a passing `green-<sha7>` (green before the change). |
| E3 | Every item a `backfill` commit adds has a `mutate-<slug>` or `mutexp-<slug>` file, at that commit or a later lane commit, that passed (§5.2). The exception: an item whose only assertions are `@test_broken` (m4) is listed, not proved. |
| E4 | No evidence file is `dirty: true` or has `termsignal ≠ 0`. |
| E5 | Boundary (§0.5): every test-writer and implementer dispatch in the lane has a saved prompt in `.lanes/briefs/<lane>/dispatched/`, and so does every message to a `tw-*` agent. Each one passes the full `brief-check` against the lane's history at audit time, including the check for lines copied from GREEN, REFACTOR or STUB-body diffs. |

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

- **Context boundary first.**
  - Read every saved brief and message in `.lanes/briefs/<lane>/dispatched/`.
  - None of them carries src, the implementer's reasoning or a paraphrase of the implementation
    ("test the cache path"). `brief-check` cannot catch a paraphrase.
  - Each role was a fresh instance: the lane ledger shows separate `agent_id`s with `agent_type`
    test-writer and implementer, and no fork.
  - The commit authors match H9.
  - `tdd_boundary` denials in the ledger show attempts to cross the boundary. Read each one: it is a
    finding, even when the guard held.
- `tdd.jl audit` and `dod.jl` outputs pasted and OK; the `TDD-Mode:` reason holds.
- RED items cite their source and assert behaviour, not implementation.
- For each `BEHAVIOUR` red caused by a `MethodError`: the call's arguments match the spec's
  signature. A wrong argument order would also be a `MethodError` (B2).
- Each `HELPER` flag: the helper is correct, and the failure comes from the code under test.
- GREEN is minimal. A `test-refactor` removes or weakens no assertion.
- Merge commits: `git show --cc` holds no test edit made while resolving a conflict.
- Backfill: each mutation changes behaviour the item claims to test; every `mutexp` fallback is
  justified.

### 4.6 Register rows (`.agents/checks.toml`)

```toml
[[checks]]
id = "tdd"
rule = "In a required-mode lane that changes src/ext, at least one RED commit exists, each GREEN follows its RED, REFACTOR follows a GREEN, STUB commits only declare, implementer phases never touch test/**, test-writer phases never touch src/ext, each red item fails with an assertion or an in-item exception (never UndefVarError, a parse or load error, a typo caught by @test_throws, a pass, or no run), and each characterization item kills a mutant"
prevented_by = "scripts/tdd.jl"
runs_in = ["local /change-review: tdd.jl audit (history + evidence) and dod.jl requirement `tdd` (history) before every merge", "ci Guards dod.jl on pull_request only (Chui merges locally: none today)"]
test = "scripts/test/test_tdd.jl"
blind_spots = [
  "authorship (H9) ties a phase to the harness role only through the tdd_boundary commit guard: one machine and one user set both authors, and a commit made outside the modelled command forms (julia/sh -c code, git commit-tree, a script, a hook-less session) can carry any author and trailer; the author records which role committed, not what that agent had read",
  "evidence is gitignored (.lanes/evidence/): rules E1-E4 run only on the machine that made it; dod.jl checks history only",
  "that a test is derived from the spec and not the code, asserts behaviour rather than implementation, that GREEN is minimal, that a test-refactor weakens nothing",
  "a MethodError from wrong arguments is classed BEHAVIOUR (reviewer checks the signature)",
  "exceptions caught inside property and law kits (Supposition @check, law_capture-style helpers) or by a deliberate try/catch are classed ASSERTION; a load error hidden that way stays red until `tdd.jl green` fails one handoff later",
  "a broken helper raising inside an item is classed BEHAVIOUR; only flagged (HELPER file:line) when its own frame is first in the stacktrace",
  "a rebase or squash orphans sha-keyed evidence and the order; merge commits are skipped, so a test edit made while resolving a conflict is seen only by the reviewer (`git show --cc`)",
  "H5 compares top-level expressions: a declaration-only struct can still hide behaviour in a field type or a `Base.@kwdef` default (a macro call is not a declaration, so @kwdef fails H5)",
  "mutate proves the item fails for ONE mutation, not how strong it is; `mutexp` (wrong expectation) proves only that the assertion runs",
  "gaps: a public name counts as tested if it appears as a whole word anywhere in test/ (short names like `map` give false positives); needs Julia >= 1.11 for Base.ispublic",
  "test code that reads source at run time is caught only by the BOUNDARY lint's pattern list"
]

[[checks]]
id = "tdd_boundary"
rule = "The test-writer works in a separate context: it cannot read src/ext, their git history, the implementer's reports or the lane's changelog fragment; neither role dispatches agents or messages anyone but the lead; test-writer/implementer dispatches carry a tdd.jl brief that holds no src outside the checked stub diffs, and are saved; a git commit's role author matches the caller's agent_type, and its staged paths match the role"
prevented_by = ".claude/hooks/tdd_boundary.sh"
runs_in = ["hook PreToolUse(Read|Grep|Glob|Bash|Agent|SendMessage)"]
test = "scripts/test/test_hooks_tdd.jl"
blind_spots = [
  "the role comes from the hook input's agent_type, documented for subagents and in-process teammates; a tmux-pane teammate may not carry it (UNVERIFIED), and then its reads are unguarded (its role commits still fail closed)",
  "the Bash allowlist is only as good as bash_guard's parser: forms it does not model (see bash_guard's blind spots) are denied by default only when recognised as commands at all",
  "run output reaches the test-writer: stacktraces name src files and lines, and `show` of a value can expose fields",
  "a sub-lead's paraphrase of the implementation passes the path check and the copied-line check; only the reviewer reading the saved briefs catches it",
  "docs/src and docstrings are shared by design and may describe implementation",
  "the lead's own context holds both sides; two instances of one model share priors (separate contexts, not independent judges)",
  "other harnesses (.codex/agents) run no Claude Code hooks"
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
   m5). It is exit 2 if `--from` is not on that line. Because the test-writer runs mutate, nothing
   mutate prints, and nothing it writes to the evidence file, quotes the `src` line: only
   `F:LINE`, `--from` and `--to`, which the test-writer already holds (§0.8).
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
- **Cap:** plan Task 13 measures one area first (about 10 items). When the projection for the
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
paths. The sub-lead writes the lane's fragment, because the test-writer may not touch
`changelog.d/` (H3). The test-writer's briefs hold the gaps list, `tdd.jl api` and the spec or docs;
for backfill it has no stub diffs and reads no `src/`. **Backfill under the boundary:** the
test-writer chooses `mutate --src F:LINE` targets without reading src. So the sub-lead, or a separate
read-only helper agent that never talks to the test-writer, proposes the mutation sites. Each one
comes from the uncovered-lines list (`gaps --lcov`) as `file:line` plus `--from`/`--to` tokens, and
the test-writer only picks one per item. Seeing a line's tokens, never the function, is accepted
as a narrow leak (§0.8). Mode `required`; the lane changes no code, so H1 passes, and E3 still
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
roughly 1.5–2× the wall-clock per task (an estimate; plan Task 10 measures it).

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
| ChuiCore.jl | tdd.jl and its four helpers, test_tdd.jl, `tdd_boundary.sh` and its lib, the hook's test file, `.claude/settings.json` (the new matcher), test_writer.md, the changed bodies, `checks.toml`, `dod.jl`, `/change-review`, the lane-lifecycle skill | the registry entry and the implementer scope; `risk.toml` (`tdd` added to T1–T3 `requires`, the 5 new scripts added to the T3 globs; the hook is already covered by `.claude/hooks/*`); `test/runtests.jl` (the selection block); `.agents/factory.toml` `[tdd] lead_names` if the default does not fit. Waits for v0.0.1. |
| ChuiTypes.jl | same | same; after its phase-5 branches merge |
| ChuiFrames.jl | same | same; after its `feat/p4-*` branches merge |
| coordinator | same managed files (the body is unused) | `risk.toml`: the 5 new scripts in its T3 globs. The registry is unchanged (D7). |

**D7.** The coordinator has no `test/` tree; the profile excludes `test/*`. Its tests are the
factory's `scripts/test/*`, which `coord_factory_maintainer` writes. **Recommendation:** no
coordinator test-writer, and no `tdd` in its tiers, because the coordinator has no code paths in
H1's sense. Revisit if factory changes keep landing with tests written after the code.

### 7.3 Approvals the user gives (plan Task 0, before any build)

1. **ADR-0015**, "Test-first lanes with a separate test-writer" (coordinator `adr/`). It records D1
   (the 13th role), D3, D4, D6 and the answers to §9. The user accepts it **before** plan Task 1
   (M7).
2. **`FACTORY_ALLOW_T3=1`** for the coordinator sync session (plan Task 11). The sync writes
   `.agents/bodies/*`, `scripts/*` and `.agents/checks.toml`.
3. **Per package:** the hand edits (§7.2), and later the `coverage.floor` raise (§5.1).

### 7.4 Template tests to add

- **scripts/test/test_tdd.jl (new):**
  - the classifier on the recorded fixtures: every class, on both versions, including the measured
    `stub outside test` → BEHAVIOUR, `typo outside` → WRONG-REASON,
    `@test_throws` + `Thrown: UndefVarError` → WRONG-REASON, `new method on existing g` → BEHAVIOUR,
    the helper → BEHAVIOUR + HELPER, the nested testset prefix, `ERROR: LoadError: Some tests did not pass` ignored,
    and `Total 0` → NOT-RUN;
  - each history rule H1–H9, on synthetic commit lists and on a scratch git repo for H5;
  - each evidence rule E1–E5;
  - mutate: a killed mutant, a surviving mutant, a load-breaking mutation, a dirty tree, an
    unmatched name, the scratch file restored after a throw, two items at one sha giving two files;
  - gaps.
- **scripts/test/test_hooks_tdd.jl (new):** hook payloads for each row of the §0.7 table. Both
  allowed and denied cases are tested, with and without `agent_type`, plus a malformed payload
  (fail closed) and a missing library (fail closed). This covers:
  - a test-writer `Read` of `src/x.jl` → denied;
  - `git show HEAD` → denied; `git log -- test/` → allowed;
  - `julia -e` → denied;
  - a commit with the wrong `--author` → denied; a lead commit with a role author → denied;
  - an implementer commit with staged `test/` → denied;
  - a dispatch without the brief header → denied;
  - a SendMessage from the test-writer to `impl-*` → denied.
- **`test_tdd.jl` additions:** `brief` and `brief-check`: a src path outside the stub block, a line
  copied from a green diff, a request holding source, a missing header. Also the `BOUNDARY` lint
  forms, H9, and E5.
- **`test_dod.jl`:** the `tdd` requirement, delegating to the history rules.
- **`test_gen.jl`:** 13 agents, and the implementer scope without `test/**`.
- **`test_runtests_template.jl`:** `item=` selection, `:contract` never selected, the stable-only
  exclusion kept for named items, and `TDD_MATCHED` recording.

**Dogfood limit (m7).** The factory's own tests are `@testset`s in `scripts/test/`, not
`@testitem`s, and the factory has no `src/`. So `tdd.jl red` cannot classify the factory's reds,
and `tdd.jl audit` on the factory lane passes vacuously through H1. Plan Tasks 1–10 use a separate
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
9. **A different model for the test-writer?** Two instances of one model share priors (§0.8).
   Recommendation: keep `model = "inherit"` for now, and record in the dogfood measurement (plan
   Task 10) whether the reviewer finds tests that mirror the implementation. Revisit if it does.
10. **The read guard: deny by default (a Bash allowlist) or deny a list of reads?** Deny by default
    (§0.7). A list of denied reads misses every read tool it does not name. The cost is that the
    test-writer cannot use ad-hoc shell commands.
11. **TDD lanes with subagents only, until the pane-teammate `agent_type` probe passes?** Yes
    (§0.3).

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

### Revision 3: the user's clarified purpose → changes

| Lead's item | Change |
|---|---|
| 1. Context separation is goal 1 and the design principle; trailers, classifier and audit are its evidence | New §0.1 (goal and principle); D0 in the decision table; the problem restated as one context (§0.2) |
| 2. Two distinct instances: no role switch, no fork, no resume with the other's transcript; no pasting of src or reasoning | §0.3: fresh `subagent_type` dispatches named `tw-*`/`impl-*`; continuation only within one's own task; neither role dispatches agents; the hook denies dispatches without a brief (§0.5, §0.7) |
| 3. What crosses the boundary; disputes as written test-fix requests through the sub-lead | §0.4 table (receives / never receives); requests are checked by `brief-check` and carry no src; §2.2 rule 6 and the implementer's rules updated; backfill mutation sites are proposed by the sub-lead or a separate helper, as tokens only (§5.4); the test-writer no longer writes the changelog fragment (scope `test/**`; H3) |
| 4. A git author per role, H-rules on authorship, an honest blind spot | §0.6 authors `test-writer|implementer <…@factory.invalid>`; H9; a commit guard that ties `--author` to the hook's `agent_type` and checks the staged paths; the old "one git identity" blind spot rewritten (§4.6): it is partly closed, since one machine sets both |
| 5. Brief templates; the reviewer checks the briefs | §0.5 include/exclude lists for both roles; `tdd.jl brief` and `brief-check`; prompts saved at dispatch; E5; the reviewer's boundary-first checklist (§4.5) |
| 6. Leaks, and whether reads can be denied mechanically | §0.8 leak table. §0.7: feasible: the `tdd_boundary` PreToolUse hook (Read/Grep/Glob/Bash allowlist, Agent, SendMessage, commit guard), keyed on the documented `agent_type`; the version on this machine is UNVERIFIED (plan Task 0 probe). A new `BOUNDARY` class for test code that reads source; a new register row `tdd_boundary` |
