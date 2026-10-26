# Factory 0.3.0: a `test-writer` role and test-first lanes with separate contexts

- **Date:** 2026-10-26, revision 6. Revision 6 fixes critic round 4: the `@compat` parse,
  macrocall line nodes, the ledger path, failed or background commits, and precedence. The history
  is in §12:
  - revision 2 answered the critic's round 1;
  - revision 3 made context separation the goal;
  - revision 4 answered critic round 2: the real topology, the H5 fix, and the cut list;
  - revision 5 answers critic round 3: `@compat public`, amend and `-C`, the git allowlist, and the
    lead as the dispatcher.
- **Lane:** testwriter-spec (coordinator; this spec and its plan only).
- **Asked by the user:** "plan the test-writer role. It should follow proper TDD principles. Write
  any missing tests once done." Clarified purpose (relayed by the lead): "separate the tester
  from the implementer to have separate contexts and valid testing as per TDD."
- **Tier:** T3 in every repo that takes it, because the registry, bodies, hooks, gate scripts, their
  tests and `risk.toml` change. It needs the user's `FACTORY_ALLOW_T3=1` and ADR-0015, both
  obtained in plan Task 0 before any build (§9.3).
- **Plan:** `docs/superpowers/plans/2026-10-26-factory-test-writer.md`
- **Status:** design only; nothing is implemented. A fact not yet checked is marked UNVERIFIED.
- **Ground truth used:** the critics' probes, all measured:
  - round 1: TestItemRunner 1.3.2 output on Julia 1.13.2 and 1.10.12, in the main checkout's
    gitignored `.lanes/scratch/tw-critic/TddScratch/*.txt`;
  - round 2: the H5 parse probe, the lead session's agent listing, and the ledger.

## 0. Goal and design principle: separate contexts

### 0.1 Goal

**Goal 1, the design principle.** The test is written in a context that has never seen the
implementation, and the code is written against tests its author cannot change.

A test the implementer wrote, or one written by an agent that read the implementer's reasoning,
tends to restate the code. Then "red, then green" proves only that the code agrees with itself.
Valid TDD needs a test derived from the spec: its red means "the behaviour is missing", and its
green means "the behaviour now exists".

The machinery is kept to what the separation needs:

1. two fresh role agents, whose tools are limited by registry frontmatter (§0.3);
2. a path allowlist for the test-writer's reads and writes, and role write scopes (§0.6);
3. a commit guard (effective author plus staged paths) and history rule H9 (§0.5);
4. `tdd.jl red`/`green`, the classifier and history rules H1–H8 (§3, §4).

Items 3 and 4 are also the **evidence** that the separation held and the tests are valid. Anything
else is deferred to §11, "Later".

**Goal 2:** backfill the missing tests in the existing packages under the same separation (§5).

### 0.2 Problem

Today the `implementer` writes both the test and the code in one context:

- its `file_scope` is `["src/**", "test/**", "ext/**", "changelog.d/**"]`;
- its rule is "Test first: write the failing test, run it, see it fail, then implement".

Nothing checks that rule. `dod.jl`'s `tests` requirement passes when `test/` changed at all, in any
order, and no evidence records that a test was ever red, or why.

**The real topology (critic round 2, NB1, measured):**

- One lead session runs from `<root>` (prompts/common.md §5, `claude --bg`). Its subagents work in
  package worktrees, `<root>/ChuiX.jl/.worktrees/<lane>`, under the **coordinator's** hooks
  (`$CLAUDE_PROJECT_DIR` is `<root>`).
- The lead session's `.claude/agents/` holds no `implementer` and no `test-writer`.
- The ledger has 0 `implementer` events and 454 `general-purpose` ones: package roles have never
  run here.

A design keyed on package-local agents and hooks would never engage.

### 0.3 Topology and agent instances (NB1)

**Two options:**

| | (a) The coordinator dispatches the roles (**recommended**) | (b) TDD lanes run from a session started in the package repo |
|---|---|---|
| How | The coordinator registry gains `test_writer` and `implementer`, using the managed template bodies, which the coordinator already vendors and which are package-neutral. The coordinator's `tdd_boundary` hook resolves each target path to its checkout: the nearest ancestor with a `.git` entry, whether a package repo or a lane worktree. Its rules apply to the path relative to that checkout. | The user, or a headless `claude -p`, starts a sub-lead session with cwd = the package repo. The package's own agents and hooks apply. |
| For | It matches how the ecosystem runs: one `--bg` lead; dispatch_limit, the ledger and lane-lifecycle all in one place. No extra sessions for the user. The same hook also works in a package-rooted session, where the checkout is the root. | The package's rules apply unchanged; paths are simple. |
| Against | It reverses D7; the hook must handle nested checkouts; package registries carry the same two roles (for package-rooted sessions). | A new session per TDD lane, outside the lead's ledger and cap. Results come back through files. A background lead cannot start an interactive session, and `claude -p` from Bash is untested under bash_guard. |

**Recommendation: (a).** It is the only option that engages without changing how the user runs the
ecosystem. The plan's Task 0 probe runs in topology (a): the lead's coordinator session dispatches a
probe subagent that works in a package worktree.

**In topology (a) the dispatcher is the lead (R3-M4).** Wherever a step below says "the lead
dispatches", "relays" or "passes on", that is the lead session. No general-purpose sub-lead is
interposed. The lead sees both sides, as it must to review, so the rule is not "the dispatcher saw
nothing". The rule is:

**The brief is the only channel.**

- The dispatcher never relays src, a diff beyond the stub diffs, or the other side's reasoning.
- The saved dispatch prompts (§0.6) are the evidence, and the reviewer reads them.
- `tdd.jl mutate` reads src, so it runs in its **own general-purpose `mutator` subagent**,
  dispatched by the lead. The mutator's report never goes into a test-writer brief (§5.2).

**Instances:**

- **Two separate agents per task, each spawned fresh:** one with `subagent_type: test-writer`, one
  with `subagent_type: implementer`.
- **The exact dispatch form (R3-M6)** is an Agent tool call with that `subagent_type`, the brief as
  `prompt`, no `team_name`, and no `fork`.
  - A `name` (`tw-<lane>-<task>` / `impl-<lane>-<task>`) is used only if the Task 0 probe shows that
    a named dispatch still carries PreToolUse `agent_type`.
  - Otherwise dispatches are unnamed, and the agent is continued by its agent id.
- **This lead's agents run as in-process teammates today.** The ledger since 2026-10-25 shows
  `idle-reported`/`idle-blocked` events, 0 SubagentStart, and every SubagentStop with
  `agent_type "-"`. The memory note says the same: under `--bg`, teammates are in-process.
  Whether a plain Agent call from this lead yields a subagent whose PreToolUse carries
  `agent_type` is exactly what Task 0 measures.
- **What is never allowed:**
  - one agent switching roles;
  - a `fork`;
  - an agent resumed with the other's transcript;
  - relaying outside the brief.
- **Continuing an agent** is allowed only within its own task. A new task gets fresh instances.
- **Tools come from the registry frontmatter (§2.1).** Neither role has `Agent`, `Task` or
  `SendMessage`, so neither can dispatch or message the other. The test-writer also has no
  `WebFetch`/`WebSearch`, which could fetch pushed src. That frontmatter replaces revision 3's hook
  rows for Agent and SendMessage.
- **Subagents only, not teammates, until probed (M-G).** The Claude Code docs
  (code.claude.com/docs/en/hooks, "Common input fields", fetched by the critic on 2026-10-26)
  document `agent_type` as present "when the session uses `--agent` or the hook fires inside a
  subagent". They do not document it for teammates. On this machine it is UNVERIFIED even for
  subagents: every SubagentStop since 2026-10-25 logged `agent_type: "-"`. Plan Task 0 probes it.

### 0.4 What crosses the boundary, and only that

| To | Receives | Never receives |
|---|---|---|
| test-writer | the plan task text (which may name src *paths*; a path is not content); the spec; the public API (`docs/src/`, and docstrings of public names rendered by `tdd.jl api`); the lane's STUB diffs, which H5 checks as declarations only; its own tests and red/green evidence; written test-fix requests | the content of `src/`/`ext/` beyond the STUB diffs; GREEN or REFACTOR diffs; the implementer's messages, reports or reasoning; the lane's changelog fragment, HANDOFF, `.lanes/reports/`; transcripts |
| implementer | the plan task text; the spec; the red test files (it reads them itself); the red evidence | the test-writer's messages, reports or reasoning |

**Disputes go in writing, through the lead.** The implementer writes a test-fix request: the item,
what is wrong *relative to the spec* (citing the line), and the proposed expected behaviour. It
holds no source code. The lead passes it on unchanged, inside the next test-writer brief. The two agents never talk; the
frontmatter has no SendMessage for either.

**Brief templates.** These are documented in the lane-lifecycle skill; the reviewer checks them.

- **test-writer:**

  ```
  <!-- tdd-brief role=test-writer lane=<lane> checkout=<abs path of the lane worktree> head=<sha> -->
  ## Task    (the plan task text)
  ## Spec    (the path)
  ## Public API   (tdd.jl api output; docs/src pages)
  ## Stub diffs   (git show of each stub commit, only if H5 passed)
  ## Test-fix requests   (verbatim, if any)
  ## Boundary  (§0.4 and §0.6, quoted)
  ```

  Excluded: any src content beyond the stub diffs, green or refactor diffs, the implementer's words.
- **implementer:** the same header with `role=implementer`, then `## Task`, `## Spec`,
  `## Red tests` (paths and shas), `## Red evidence` (paths) and `## Boundary`. Excluded: the
  test-writer's report and messages.

`tdd.jl brief --role R --lane DIR` prints the header (exit 2 on a dirty lane, M-B), the `## Public
API` section and the stub-diff section. It saves the brief under `<main>/.lanes/briefs/<lane>/`,
where `<main>` is the **main checkout of the repo that owns the lane** (R3-M5). Lane names repeat
across repos, so the `checkout=` field in the header, not the lane name, identifies the lane. The
lead adds the task text and the rest by hand. A lint of brief contents was cut (§11).

### 0.5 Identity: a git author per role, and the commit guard

- **Authors:**
  - `test-writer <test-writer@factory.invalid>` for `red`, `test-fix`, `test-refactor` and
    `backfill`;
  - `implementer <implementer@factory.invalid>` for `stub`, `green` and `refactor`.

  The committer is the machine's user.
- **H9 (§4.2):** each phase commit's author is its phase's role.
- **The lead's identity is explicit (R3-m1).** "Lead-authored" means authored exactly
  `lead <lead@factory.invalid>`, set with `--author` by the main session. The main session is the
  caller with no `agent_type`. The commit guard denies that identity to every caller that has an
  `agent_type`, `general-purpose` included. Today's general-purpose package lanes therefore cannot
  make a lead-authored commit.
- **The commit guard has two halves** (split from the boundary hook, m5): `_tdd_commit_guard.sh`
  runs at PreToolUse, and `tdd_commit_post.sh` at PostToolUse. Both apply to every `git commit` by
  any caller, in any checkout under the session root. A compound line (`git add … && git commit …`,
  `;`, `||`) is split with bash_guard's parser. Each `git commit` in it is checked, and its checkout
  comes from the `cd`/`-C` that precedes it.
- **PreToolUse: the effective author, as it will be recorded (R3-M2, R4-m1).** The first rule that
  applies wins, as measured:
  1. `--author` given: that identity. It beats the source commit, even under `--amend`.
  2. `--reset-author` with `--amend` or `-C`/`-c`: the caller's identity, from step 4.
  3. `--amend`, `-C`/`-c`/`--reuse-message`/`--reedit-message <commit>`: the **source commit's**
     author (`git log -1 --format='%an <%ae>'`). Env vars are ignored there, measured.
  4. Otherwise `git -C <checkout> var GIT_AUTHOR_IDENT`, with the command's env assignments and
     `-c` options applied. A `git config user.*` set earlier is covered, because `git var` reads it.

  Then:
  - a role caller must commit as exactly its role;
  - no caller may produce a role identity that is not its own, or the lead identity if it has an
    `agent_type`;
  - a role caller may not write a `TDD-Mode:` trailer.

  For the **test-writer** (R4-m2), the guard also denies `-C`, `-c`, `--reuse-message`,
  `--reedit-message`, `--fixup` and `--squash`: they print or reuse another commit's message. It
  denies `--amend` unless HEAD is already authored `test-writer`.
- **No background commits (R4-M3).** A Bash call with `run_in_background: true` whose command
  contains `git commit` is denied for every caller: the post check would run before the commit
  exists.
- **PostToolUse and PostToolUseFailure: the authoritative check, on the resulting commit (R3-M2,
  R4-M3).**
  - **Why both events.** `tdd_commit_post.sh` is registered on **both** events. A Bash call that
    commits and then fails (`git commit … && julia scripts/ci.jl test` on a red test exits 1) fires
    only PostToolUseFailure, per the docs.
  - **The pending record.** The PreToolUse half records each checkout's HEAD under the call's
    `tool_use_id` in `<session root>/.lanes/tdd-pending/`.
  - **The check.** The post half takes every new commit since then:
    `git rev-list <before>..HEAD`, which after an amend yields the amended commit.
  - **Sweep.** Every Pre and post call first sweeps stale `tdd-pending` entries, older than the
    call or left by a cancelled call, which fires neither event. Their new commits are checked and
    recorded the same way, marked `late: true`, and the entry is deleted.

  For each commit it checks:
  - author against caller;
  - the trailer phase against the caller's role;
  - the changed paths against the role (the test-writer changes only `test/**`, outside the seeded
    runners; the implementer changes no `test/**`).

  It appends `{ev: "tdd-commit", agent_id, agent_type, checkout, sha}` with the **resulting sha** to
  **the TDD ledger**. The TDD ledger is defined once, here (R4-M2): it is the session's ledger,
  `<session root>/.lanes/ledger.jsonl`, the file `_lib.sh` already writes (`$ROOT/.lanes/ledger.jsonl`).
  In topology (a) that is the coordinator's. `tdd.jl audit` and `dod.jl` read it through `--ledger
  PATH`. The default is the outermost directory above the lane checkout that holds
  `.lanes/ledger.jsonl`, which in (a) is `<root>`. `/change-review` passes
  `--ledger <root>/.lanes/ledger.jsonl` explicitly.
  PostToolUse cannot undo a commit. A violation is written as `tdd-commit-violation` and printed to
  the caller, and audit rule E5 fails on it.
- **Audit rule E5 (§4.3)** requires every role-authored commit in the lane to have a `tdd-commit`
  record with the same sha and a matching `agent_type`, and no `tdd-commit-violation`. On the
  machine that holds the ledger, this also detects the unmodelled forms (`git commit-tree`, julia
  code), because they leave no record.

**What this proves, and what it does not.** A commit that passes H9 and E5 was made through a
`git commit` that the hooks saw, by a process the harness reported as that role. The commit itself
was checked after it was made. That partly closes the "one git identity" blind spot, because one
machine and one user still set both authors:

- E5 needs the local ledger, so a fresh clone or CI sees H9 only;
- a commit made with the hooks off and then given a forged ledger line passes;
- the author says which role committed, not what that agent had read. §0.6 covers what it read.

### 0.6 The `tdd_boundary` hook: paths and Bash

- **Three managed files, each ≤ 150 lines (m5):**
  - .claude/hooks/tdd_boundary.sh, for paths, the Bash allowlist and dispatch. It is registered in
    `settings.json` with PreToolUse matchers `Read|Grep|Glob|Edit|Write|MultiEdit|NotebookEdit|Bash`
    and `Agent|Task` (the latter as dispatch_limit, M-G).
  - .claude/hooks/_tdd_commit_guard.sh, sourced by tdd_boundary.sh for `git commit`.
  - .claude/hooks/tdd_commit_post.sh, at PostToolUse `Bash` **and** PostToolUseFailure `Bash`
    (R4-M3).

  The PreToolUse hooks run through the same fail-closed `sh -c '… exit 2'` wrapper as the other
  guards.
- **Paths.** Each target path is resolved **with symlinks followed** (`cd -P`/`pwd -P` on its
  directory; m2) to its checkout, and to the path relative to it (§0.3a). A `test/` symlink to
  `../src` therefore resolves to `src/` and is denied.
- **Who it applies to.** It applies when `agent_type` is `test-writer` or `implementer`, to every
  caller's `git commit`, and to the lead's dispatches of a role.
- **Feasible with the current hooks:** PreToolUse input carries `agent_type` inside a subagent
  (documented; UNVERIFIED here, see Task 0). bash_guard's word splitter and wrapper handling are
  sourced from `_bash_guard_lib.sh`.

| Caller | Tool | Rule |
|---|---|---|
| test-writer | Read, Grep, Glob | **Allowlist (M-D).** In any checkout: `test/**`, `docs/**` (spec, plan, docs/src), `Project.toml`, `.lanes/evidence/red-*` and `green-*`, `.lanes/briefs/<lane>/test-writer-*` (m-c). In the coordinator: `docs/superpowers/**`, `contracts/**`, `adr/**`. Grep and Glob must give a `path` inside that list. Everything else is denied, including transcripts (`~/.claude/projects/…`), the depot (`~/.julia/packages/…`), `.lanes/scratch/` (the mutate copy), `src/`, `ext/`, `.lanes/reports/`, `changelog.d/` and HANDOFF. |
| test-writer | Edit, Write, MultiEdit, NotebookEdit | allow only `test/**` of a checkout, except the seeded runners `test/runtests.jl` and `test/Project.toml`, which hold `item=`/`TDD_MATCHED`, the NOT-RUN oracle (m3) |
| test-writer | Bash | **Allowlist (M-E).** `cd <checkout>`; `julia [<checkout>/]scripts/tdd.jl red\|green\|api …`; `julia [<checkout>/]scripts/ci.jl test …`; `git [-C <checkout>]` with **only** `status`, `add <test/ paths>`, `commit` (the guard) and `diff [--cached] -- <paths>`, where every pathspec is under `test/` (R3-M3); `ls`/`cat`/`head`/`tail`/`wc`/`grep`/`rg` with explicit allowlisted paths. Everything else is denied, including `git log` (commit messages carry the implementer's reasoning), `git show`, any `<rev>:<path>` argument (it ignores the pathspec; measured: `git show HEAD:src/a.jl -- test/` printed src), `git blame`, `julia -e`, `sh -c`, `scripts/evidence.jl` called directly (it runs any command) and `tdd.jl mutate`. |
| implementer | Edit, Write, MultiEdit, NotebookEdit | deny `test/**` of any checkout (M-B) |
| implementer | Bash | bash_guard's modelled write targets under `test/**` are denied. Unmodelled writes are caught at commit by the staged-path check and H3/H4. |
| any | `git commit` | the commit guard (§0.5), PreToolUse and PostToolUse |
| the lead only: a caller with **no `agent_type`** (R4-m3); any caller with an `agent_type`, the mutator and other general-purpose agents included, is denied | Agent/Task with `subagent_type` test-writer or implementer | The prompt starts with a `tdd-brief` header for that role. Its `checkout=` is a lane worktree under the session root (R3-M5), its `head=` equals that checkout's HEAD, and the checkout is clean (M-B). The prompt is saved to `<main>/.lanes/briefs/<lane>/dispatched/`. |

**Fails closed:** a payload the hook cannot parse, a missing library or a missing jq means deny. For
the Read, Grep, Glob and Bash matchers that applies to **every caller**, the lead included. That is
an availability cost, and the register says so (m-d). With `agent_type` absent, only the commit guard
and the lead-dispatch rule apply: the reads are unguarded. That is why TDD lanes are subagent-only
(§0.3).

### 0.7 Where separation still leaks

| Leak | Mitigation | Left open |
|---|---|---|
| The test-writer reads src (directly, through git, a transcript, the depot copy, or the mutate scratch copy) | Read/Grep/Glob and Bash allowlists (§0.6) | command forms bash_guard cannot parse are denied, not modelled |
| Test code reads src **at run time** (`read(joinpath(pkgdir(M), "src", …))`, `@less`, `methods`) and the test-writer runs it, committed or not | **Detected after the fact, never prevented (M-E).** The reviewer greps the red diffs for `pkgdir(`, `pathof(`, `@less`, `@edit`, `@which`, `methods(`, `code_lowered`, `read(` and `include(` of a `src` path (§4.5). A mechanical lint is in §11. | an uncommitted run-time read leaves no trace |
| Run output: stacktraces name src files and lines, and `show` of a value can expose fields | Accepted: no source text is printed | yes |
| `docs/src` and docstrings written by the implementer | By design: they are the public API | a docstring that describes internals |
| Plan task text names src paths | Accepted: paths, not content (M-F) | — |
| The lead relays the implementation in a brief, a request or a paraphrase, or puts the mutator's report into a test-writer brief | Brief templates; saved dispatch prompts; the reviewer reads them | a paraphrase passes every mechanical check |
| The lead's own context holds both sides | The lead never writes tests or code | yes |
| Two instances of one model share priors | Tests cite the spec; review | separate contexts, not independent judges (§11) |
| Teammates, or a missing `agent_type` | TDD lanes are subagent-only (§0.3) | until the probe passes |
| Other harnesses (`.codex/agents`) | none | yes |

## 1. Decision summary

| # | Question | Decision (recommended) |
|---|---|---|
| D0 | Context separation (goal 1) | Two fresh role subagents per task, with tools limited by frontmatter. Topology (a): the coordinator dispatches the roles, and one multi-checkout `tdd_boundary` hook enforces path allowlists and the commit guard. Brief templates; saved dispatch prompts. |
| D1 | The role | A 13th template role `test_writer` / `test-writer` (unit and example tests), asked for by the user. The implementer loses `test/**`, and H3/H4, the hook and the commit guard enforce that. |
| D2 | TDD protocol | Per behaviour: STUB (new names only) → RED → GREEN → REFACTOR, plus `test-fix`/`test-refactor`. Each commit carries a `TDD:` trailer and must follow the order in §3.1. |
| D3 | Right-reason red | `tdd.jl red` classifies the failure *headers* only. An assertion failure counts as red, and so does any in-item exception, `MethodError` included. Rejected: `UndefVarError`, parse or load errors (also under `@test_throws`), no summary, a pass, an unmatched item. |
| D4 | Enforcement | History rules H1–H9 run in `tdd.jl audit` and in `dod.jl`'s `tdd`. Evidence rules E1–E5 run in audit only. The lead runs both locally before every merge. The mode is a `TDD-Mode:` trailer on a commit authored `lead <lead@factory.invalid>`. `skip` fails dod unless it is lead-authored with a reason. A PostToolUse commit check and E5 tie role commits to ledger records. Lanes merge, never rebase. |
| D5 | Backfill | Characterization items, committed first; then a separate **`mutator` subagent** dispatched by the lead runs `tdd.jl mutate` per item (evidence `mutate-<slug>`/`mutexp-<slug>`). `gaps` lists public names with no test. Order: ChuiCore, ChuiTypes, ChuiFrames. Bugs found become `@test_broken` and are reported. A 2 h cap. |
| D6 | Version | 0.3.0, a minor bump: stricter guards and a narrowed role. |
| D7 | Coordinator | **Reversed (NB1):** the coordinator registry gains `test_writer` and `implementer`, for package lanes. Coordinator-own work (no `src/`) does not use TDD. |
| D8 | Cost and skips | 2–4 more handoffs per task. The lead picks the mode, and records it on a lead-authored commit. A lane with no `src/`/`ext/` change needs no mode. |

## 2. The role (D1)

### 2.1 Registry entries (template and coordinator `.agents/agent-registry.toml`)

```toml
[[agents]]
slug = "test_writer"
name = "test-writer"
role = "Writes unit and example tests from the spec, plan and public API, in a context that never sees the implementation (RED); and characterization tests for untested code."
description = "Use in a test-first lane before the implementer writes code, with a tdd-brief, to write the failing tests for one planned behaviour; or to backfill missing tests."
model = "inherit"
color = "yellow"
default_mode = "write"
tools = ["Read", "Grep", "Glob", "Bash", "Edit", "Write"]
disallowed_tools = ["Agent", "Task", "SendMessage", "WebFetch", "WebSearch", "NotebookEdit"]
file_scope = ["test/**"]
scorecard = ["worked only from its tdd-brief: no src beyond the stub diffs", "each test derived from the spec or public docs, cited", "RED evidence: every new item fails for the right reason (tdd.jl red)", "one behaviour per test item, no implementation details asserted", "commits authored test-writer"]
output_format = "behaviours and their sources, test items written, tdd.jl red output, disputes and bugs found, checks not run and why, scorecard"
```

**The implementer entry** changes as follows:

- `file_scope = ["src/**", "ext/**", "changelog.d/**"]`;
- `tools = ["Read", "Grep", "Glob", "Bash", "Edit", "Write", "WebFetch", "WebSearch"]`;
- `disallowed_tools = ["Agent", "Task", "SendMessage"]`.

gen.jl already renders `tools` and `disallowed_tools` (gen.jl:32, :108–109; m-e). In the coordinator
registry both entries use the template bodies (`test_writer.md`, `implementer.md`); the
coordinator vendors them already as managed files.

**What the test-writer does not edit** (the body says so, and the lead's `--owns` narrows it per
lane):

- `test/laws/**`, `test/property/**`, `test/differential/**`, `test/contracts/**` and `test/jet/**`;
- items tagged `:laws`, `:property`, `:differential`, `:contract` or `:quality` (ChuiCore keeps law
  tests flat: `test/*_laws_tests.jl`);
- the seeded runners.

**Why a 13th role.** No existing role can write black-box tests for code it did not write: the law
and property testers use generators; the differential tester needs a reference implementation; the
critic and the reviewer are read-only. The user asked for this one, and ADR-0015 records it (Task 0).

### 2.2 Body (new managed .agents/bodies/test_writer.md)

0. **Your context is the boundary.** Work only from your tdd-brief (§0.4). Never read `src/`,
   `ext/`, their history, transcripts, the depot, reports or the changelog fragment, and never ask
   for them; the hook denies most of these.
   - Commit with `--author "test-writer <test-writer@factory.invalid>"`.
   - Your final reply is your report.
1. **Derive each test from a cited source:** a spec or plan line, a docstring, `docs/src/`, a
   contract or an ADR. Never write test code that reads source (§0.7).
2. **One behaviour per `@testitem`**, named for the behaviour, with few assertions.
3. **Test the public API only.** No private fields, internal names, call counts or allocations, and
   no exact `show` output (that belongs in `:snapshot`).
4. **RED.** Commit the tests alone with `TDD: red`, then run `tdd.jl red` and paste its output.
   - On `WRONG-REASON`, `PASSED`, `COLLATERAL` or `NOT-RUN`, fix the test, amend the commit and run
     it again.
   - Never use `@test_throws` to manufacture a red.
5. **Never touch `src/`, `ext/`, `Project.toml` or `changelog.d/`.** If you need a stub, name it in
   your report.
6. **Disputes arrive as a written test-fix request in a new brief.** Answer with a `TDD: test-fix`
   commit (checked by `tdd.jl red`), or with a reason in your report.
7. **`test-refactor`:** after a green only. Remove or weaken no assertion; run `tdd.jl green`.
8. **Backfill:** commit items with `TDD: backfill`. A separate mutator agent runs `mutate` against
   your commit; you never see its sites.
   A bug becomes `@test_broken` plus a report line; never fix it.
9. **Shared rules:** Edit/Write only; report changed files and the checks not run.

### 2.3 Other roles

| Role | Change |
|---|---|
| implementer | Role line: "Implements one planned task against the test-writer's red tests: minimal code to green, then refactor with tests unchanged." Rules: work from your tdd-brief; commit with `--author "implementer <implementer@factory.invalid>"`; never touch `test/**`; disputes go to the lead as a written test-fix request with no source code; you write the lane's changelog fragment; STUB declares only (H5); GREEN is minimal; REFACTOR comes only after a green. Scorecard: "failing test written first" becomes "tdd.jl audit OK". |
| law-tester, property-tester, differential-tester | One line: "In a test-first lane, commit new items with `TDD: red` before the code." |
| reviewer | The §4.5 checklist. |

## 3. TDD protocol inside one lane (D2, D3)

### 3.1 Phases and order

```
STUB          implementer  src/ext only, declarations only         TDD: stub
RED           test-writer  test/** only, the new items fail        TDD: red           + red evidence
GREEN         implementer  src/ext only, minimal                   TDD: green         + green evidence
REFACTOR      implementer  src/ext only, behaviour unchanged       TDD: refactor      + green evidence
TEST-FIX      test-writer  test/** only, a disputed test changed   TDD: test-fix      + red evidence
TEST-REFACTOR test-writer  test/** only, after a green             TDD: test-refactor + green evidence
BACKFILL      test-writer  test/** only, characterization items    TDD: backfill      + mutate evidence per item
```

- One worktree and one branch per lane. The two instances take turns. The lead dispatches each one
  only on a clean lane, with a brief whose `head=` is the current HEAD (§0.6).
- Small steps: one behaviour, or a small named group, per RED.
- The lane's mode goes on a **lead-authored** commit, as a `TDD-Mode: <mode> — <reason>` trailer
  (§6).

### 3.2 New names need stubs; new methods do not

- **A new name** red-fails with `UndefVarError`, and a typo produces the same error. So the
  implementer first commits a STUB holding only declarations:
  - `function f end`;
  - field-only `struct`s;
  - `export`/`public`;
  - docstrings;
  - an `include` of a new file holding only these.

  H5 checks it.
- **A new method or a changed behaviour** needs no stub. Its red is a `MethodError` (measured:
  `g("a")` with `g(x) = x + 1` gives `MethodError: no method matching +(::String, ::Int64)` on both
  versions), or a wrong value; both count.
- **Throwing method stubs are rejected.** They change dispatch on existing generics, they put code
  in a STUB, and they do not cover a MethodError raised inside Base.

### 3.3 Classification (measured output format)

Failure headers, the same on 1.10.12 and 1.13.2:

```
<innermost testset name>: Test Failed at <absolute file>:<line>
<innermost testset name>: Error During Test at <absolute file>:<line>
```

- Only header lines are parsed. Stacktrace line numbers for the item file are wrong (measured
  `items_tests.jl:539` in a 37-line file). A header belongs to the `@testitem` whose span contains
  its line.
- A block runs to the next header or the `Test Summary:`. Its exception line is the first line after
  `Test threw exception`/`Expression:` or `Got exception outside of a @test`, with one `LoadError: `
  stripped.
- `ERROR: LoadError: Some tests did not pass` is ignored.

| Class | Rule | Red? |
|---|---|---|
| `ASSERTION` | a `Test Failed` header whose block has no `Thrown: (UndefVarError\|LoadError\|ParseError\|ArgumentError: Package)` | yes |
| `BEHAVIOUR` | an `Error During Test` header whose exception is not rejected (`MethodError`, `ArgumentError`, `KeyError`, `AssertionError`, …) | yes |
| `WRONG-REASON` | an `UndefVarError`, `ParseError`/`syntax:`, `LoadError`, `SystemError: opening file` or `Package … not found` exception; an `ASSERTION` whose `Thrown:` is one of those; a header in no span; no `Test Summary:`; `termsignal ≠ 0` | no |
| `PASSED` | a requested item with no header | no |
| `NOT-RUN` | a requested item that was not selected (§3.4) | no |
| `COLLATERAL` | a header in the span of an item that was not requested | no (the run fails) |

- **An item is red** when it has an `ASSERTION` or `BEHAVIOUR` header and no `WRONG-REASON` header.
  The run passes when every requested item is red and nothing is `COLLATERAL`.
- **`HELPER file:line`** is a report-only flag: the first stacktrace frame is a `test/` file other
  than the item's.
- **Requested items** are the `@testitem`s a RED or TEST-FIX commit added or touched. Unchanged items
  whose `setup = [...]` names a changed `@testmodule`/`@testsnippet` also run and must pass. A RED
  commit that touches no `@testitem` exits 2.

### 3.4 Running only the requested items (seeded `test/runtests.jl`)

- **`item=<name>`** (works through `Pkg.test(test_args=ARGS)` with spaces, measured). The filter
  order is:
  1. `:contract` is never selected;
  2. the stable-only exclusion still applies;
  3. `item=`;
  4. the tags.
- **`TDD_MATCHED=<file>`:** the filter appends each selected name. A requested name missing from the
  file is `NOT-RUN`. `green` and `mutate` also need a `Test Summary:` total of at least the number of
  requested items (`item=nosuch` exits 0 with `Total 0`, measured). That Pkg.test passes ENV through
  to the test process is UNVERIFIED; Task 2 tests it.

### 3.5 Evidence, GREEN, REFACTOR

- **Where the runs happen.** `tdd.jl red|green` runs at a committed HEAD through `evidence.jl`
  (kinds `red`/`green`); a dirty tree is exit 2. The classification is appended under `--- tdd ---`.
- **`green`:** the lane's red items must all pass and all be matched, then the default suite runs.
- **GREEN and REFACTOR** change only `src/`, `ext/`, `changelog.d/`, and `Project.toml` when the plan
  names a new dependency. "Minimal" is the reviewer's call. REFACTOR needs green evidence.

## 4. Enforcement (D4)

### 4.1 Files (4 scripts plus 3 hook files; all managed, T3)

```
julia scripts/tdd.jl red    [--root DIR] [--rev REV]   classify a RED/TEST-FIX commit's items
julia scripts/tdd.jl green  [--root DIR]               the lane's red items pass, then the default suite
julia scripts/tdd.jl audit  [--root DIR] [--base B]    history rules H1-H9 + evidence rules E1-E5
julia scripts/tdd.jl api    [--root DIR]               docstrings of exported/public names (Julia >= 1.11)
julia scripts/tdd.jl brief  --role R [--root DIR]      header + api + stub diffs; refuses a dirty tree; saves it
julia scripts/tdd.jl mutate [--root DIR] --item NAME (--src F:LINE | --expect F:LINE) --from S --to S   (mutator agent)
julia scripts/tdd.jl gaps   [--root DIR]               public names with no test (Julia >= 1.11)
```

The work splits into these files, each ≤ 400 lines:

- scripts/tdd.jl;
- scripts/_tdd_classify.jl;
- scripts/_tdd_history.jl, which dod.jl includes too;
- scripts/_tdd_backfill.jl, holding mutate and gaps;
- the hooks .claude/hooks/tdd_boundary.sh, .claude/hooks/_tdd_commit_guard.sh and
  .claude/hooks/tdd_commit_post.sh (§0.5, §0.6). They source `_bash_guard_lib.sh`, and each is
  ≤ 150 lines.

### 4.2 History rules (`git rev-list --no-merges --reverse <mb>..HEAD`; *code* = `src/**`, `ext/**`)

The mode comes from the `TDD-Mode:` trailer of the oldest commit that carries one. That commit must
be authored `lead <lead@factory.invalid>`; otherwise the trailer is ignored and the mode is
`required`. With no such trailer the mode is `required`.

| Rule | Check |
|---|---|
| H1 | No commit changes code: PASS, and H2–H8 do not apply (H9 still does). Otherwise every code-changing commit has a phase trailer. |
| H2 | Mode `required`: at least one `red`. |
| H3 | `stub`, `green` and `refactor` change no `test/**`. `red`, `test-fix`, `test-refactor` and `backfill` change no code, `Project.toml` or `changelog.d/`. **No phase commit changes the seeded runners `test/runtests.jl` or `test/Project.toml`** (m3); only a non-phase, lead-authored commit may, such as a sync. |
| H4 | No commit outside a test-writer phase touches `test/**` (H3 seen from the other side, for the register). **The one exemption (R4-m4):** a non-phase commit authored `lead <lead@factory.invalid>` may change the two seeded runners `test/runtests.jl` and `test/Project.toml`, and nothing else under `test/`. |
| H5 | A `stub` only declares (NB2, NB3, R3-M1, R4-B1, R4-M1). For each changed src/ext file:<br>1. Parse the parent and the commit (`Meta.parseall`).<br>2. Strip **every** `LineNumberNode`: run `Base.remove_linenums!`, and also replace each macrocall's own line slot (`args[2]`), which `remove_linenums!` keeps (measured), with `nothing`. A stub inserted above an existing method, **documented or not**, then leaves that statement unchanged.<br>3. Descend into `module`/`baremodule` bodies.<br>4. Compare the statements as multisets.<br>**Added** statements may only be: `function NAME end`; a field-only `struct`/`mutable struct`; `abstract type`; `primitive type`; `export`/`public`; **a `@compat` statement as it actually parses (measured on 1.13.2 and 1.10.12):** a macrocall whose name is `@compat` or `Compat.@compat`, followed after its line slot by **either** the bare symbol `:public` and then one name or a tuple of names (`@compat public a, h` → `macrocall(@compat, LNN, :public, (a, h))`), **or** exactly one `export` Expr (`@compat export g`). That is the form every package uses, because `public` does not parse on 1.10. Also: a docstring (`Core.@doc` or a string before a decl) wrapping one of these; `using`/`import`; `include("f.jl")` of a file the commit **adds**, whose own statements pass the same rule.<br>**Removed** statements are not allowed, except an `export`/`public`/`@compat public` statement replaced in the same commit by one naming a superset of its names. Deleting a method or any other statement fails.<br>Anything else fails, `Base.@kwdef` and inner constructors included. |
| H6 | Order: a `stub` comes before its `red`; one `green` per `red`/`test-fix`; `refactor`/`test-refactor` only after a `green`. |
| H7 | The lane does not end on a red. |
| H8 | Mode `refactor`: no red, green or stub; no `test/**` change. Mode `skip`: dod's `tdd` **FAILS** unless the mode commit is lead-authored and carries a reason (M-A). |
| H9 | The authors match the phases (§0.5), and no phase-less commit carries a role author. |

### 4.3 Evidence rules (`tdd.jl audit`; local and gitignored)

| Rule | Check |
|---|---|
| E1 | Each `red`/`test-fix` has a passing `red-<sha7>`. |
| E2 | Each `green`/`refactor`/`test-refactor` has a passing `green-<sha7>`. In mode `refactor`, the merge base also needs one. |
| E3 | Each item a `backfill` adds has a passing `mutate-<slug>` or `mutexp-<slug>`. Items whose only assertions are `@test_broken` are listed, not proved. |
| E4 | No evidence file is dirty or killed. |
| E5 | Every role-authored lane commit has a `tdd-commit` record in **the TDD ledger** (§0.5: `<session root>/.lanes/ledger.jsonl`, passed as `--ledger`; R4-M2) with the same sha and the matching `agent_type`. There is no `tdd-commit-violation` record for the lane (R3-M2). |

### 4.4 Where it runs; merges and rebases

- **Before every merge** (M5), the lead runs `julia scripts/dod.jl --base main` and `tdd.jl audit
  --base main` in the lane through `/change-review`, because Chui merges locally. CI runs dod only on
  pull requests, and there are none today.
- **Merge, never rebase:** evidence is keyed by sha. After a rebase, run `green` at the tip, and
  audit reports the missing reds for the lead to decide.

### 4.5 Reviewer checklist

- **Boundary first.**
  - The saved dispatch prompts follow the §0.4 templates and carry no src, reasoning or paraphrase.
  - The ledger's `tdd-commit` lines show separate `agent_id`s per role, and no fork.
  - The authors match H9.
  - Every `tdd_boundary` denial is a finding.
  - Grep the red diffs for the run-time source-read forms (§0.7).
- `audit` and `dod` pasted and OK. A mode trailer is lead-authored, and its reason holds.
- RED items cite sources and assert behaviour. For a `MethodError` red, the arguments match the
  spec signature.
- `HELPER` flags checked. GREEN is minimal. A test-refactor weakens nothing. Merge commits
  (`git show --cc`) hold no test edits.
- Backfill: the mutations are meaningful, and each `mutexp` is justified.

### 4.6 Register rows (`.agents/checks.toml`)

```toml
[[checks]]
id = "tdd"
rule = "In a lane that changes src/ext: mode required has a RED; GREEN follows its RED; REFACTOR follows a GREEN; STUB only declares (inside module blocks too); implementer phases never touch test/** and test-writer phases never touch src/ext/changelog.d; phase authors match roles; a skip lane fails unless the lead set the mode; red items fail by assertion or in-item exception, never UndefVarError, a parse/load error, a typo under @test_throws, a pass or no run; characterization items kill a mutant"
prevented_by = "scripts/tdd.jl"
runs_in = ["local /change-review: tdd.jl audit (history + evidence) and dod.jl `tdd` (history) before every merge", "ci Guards dod.jl on pull_request only (none in Chui today)"]
test = "scripts/test/test_tdd.jl"
blind_spots = [
  "authorship ties a phase to a role only through the tdd_boundary commit guard: one machine and one user set both authors; a commit made outside the modelled forms (julia/sh -c code, git commit-tree, a script, a hook-less session) can carry any author and trailer",
  "evidence and the ledger are gitignored: E1-E5 run only on the machine that made them; dod checks history only",
  "that a test comes from the spec and asserts behaviour, that GREEN is minimal, that a refactor-mode lane adds no behaviour",
  "a MethodError from wrong arguments is BEHAVIOUR (the reviewer checks the signature)",
  "exceptions caught inside property or law kits or a try/catch are ASSERTION until `green` fails",
  "a broken helper raising inside an item is BEHAVIOUR; it is only flagged (HELPER)",
  "a rebase or squash orphans sha-keyed evidence; a test edit made while resolving a merge conflict is seen only by the reviewer",
  "mutate proves one mutation fails the item, not how strong it is; mutexp proves only that the assertion runs",
  "gaps: a public name counts as tested if it appears anywhere in test/; needs Julia >= 1.11"
]

[[checks]]
id = "tdd_boundary"
rule = "A test-writer reads and writes only allowlisted paths (test/, docs/, evidence, its briefs; never src/ext, transcripts, the depot or the mutate copy) and runs only allowlisted Bash; an implementer never writes test/**; every git commit's effective author is a role only when the caller is that role, and its staged paths fit the role; the lead dispatches a role only on a clean lane with a current tdd-brief, and the prompt is saved"
prevented_by = ".claude/hooks/tdd_boundary.sh (with _tdd_commit_guard.sh) and .claude/hooks/tdd_commit_post.sh"
runs_in = ["hook PreToolUse(Read|Grep|Glob|Edit|Write|MultiEdit|NotebookEdit|Bash)", "hook PreToolUse(Agent|Task)", "hook PostToolUse(Bash) and PostToolUseFailure(Bash)"]
test = "scripts/test/test_hooks_tdd.jl"
blind_spots = [
  "the role comes from agent_type, documented for subagents only; teammates and a missing agent_type leave reads unguarded (TDD lanes are subagent-only)",
  "the Bash allowlist relies on bash_guard's parser; unparsed forms are denied, not modelled",
  "test code that reads src at run time is detected after the fact by review, never prevented; an uncommitted read leaves no trace",
  "run output names src files and lines, and show() can expose fields",
  "the lead's paraphrase in a brief passes; only review of the saved prompts catches it",
  "PostToolUse cannot undo a commit: a violating commit exists until audit E5 fails the lane",
  "a cancelled Bash call fires no post event: its commit is recorded only by the next call's sweep of .lanes/tdd-pending (marked late), so a session that ends right after a cancelled commit leaves it unrecorded and E5 fails the lane",
  "E5 needs the local ledger: a fresh clone or CI sees H9 only, and a forged ledger line passes",
  "fails closed on every Read/Grep/Glob/Bash call, the lead's included, when jq or a library is missing (availability cost)",
  "two instances of one model share priors; other harnesses (.codex) run no hooks"
]
```

## 5. Backfilling missing tests (D5)

### 5.1 Gaps

`tdd.jl gaps` lists the exported and `public` names that appear nowhere in `test/`. It runs on
Julia ≥ 1.11 (`Base.ispublic`). ChuiCore's API is mostly `public`. Ranking order:

1. public API with no test;
2. error paths;
3. the edge cases the docs name.

Uncovered lines (`--lcov`) are deferred (§11). After a package's backfill merges, the lane reports
the measured coverage, and the lead proposes a `coverage.floor` 1 point below it to the user (T3).
Every package's floor is `0.0` today.

### 5.2 The proof: `tdd.jl mutate`, run by a separate mutator agent (m-a, R3-M4)

1. **The test-writer commits a few items** with `TDD: backfill` and reports their names and the
   behaviour each one claims.
2. **The lead dispatches a fresh general-purpose `mutator` subagent** with the item names and
   claims, the lane checkout and the sha. The mutator reads src, picks one mutation per item and
   runs `tdd.jl mutate` against that committed HEAD (a dirty tree is exit 2). It reports to the lead.
   Its report, and the `mutate-*` evidence that records the mutation, never go into a test-writer
   brief; the test-writer's read allowlist covers only `red-*`/`green-*` evidence. A surviving
   mutant goes back to the test-writer as "item X did not detect a change to the behaviour it
   claims", without the site.
3. **mutate itself:**
   - It uses one persistent scratch worktree, `.lanes/scratch/mutate/` (`git worktree add
     --detach`, then `git checkout --detach <sha>` per run), with `Manifest.toml` and
     `Manifest-v1.10.toml` copied in.
   - It applies one replacement at `--src F:LINE`, or `--expect F:LINE` as the fallback (evidence
     `mutexp-`).
   - It runs `item=NAME` with `TDD_MATCHED`. The item must be matched and fail as
     `ASSERTION`/`BEHAVIOUR` on a non-broken assertion. It then restores the file in `finally`.
   - It runs the item on the real tree, where it must be matched and pass.
   - It writes `mutate-<slug>` or `mutexp-<slug>`. The slug is the name lowercased, with runs of
     non-`[a-z0-9]` characters replaced by `-`, cut to 24 characters, then `-` and 8 hex digits of
     the name's SHA-1: at most 40 characters for the kind.
4. **Mutants run on 1.13 only;** the full suite runs on both versions at the end.
5. **Cost (UNVERIFIED):** 30–120 s per mutant.
   - Whether the scratch copy and the real tree invalidate each other's precompile cache is measured
     in Task 6 (m-b).
   - **Cap:** 2 h per lane, measured on about 10 items first. Above it, a ★: the work splits into
     area lanes, run one at a time, or the user accepts the cost. Never sample.

### 5.3 Bugs and silent docs

- **Docs and behaviour disagree:** write the item for the documented behaviour, with `@test_broken`
  and `BUG: <line>; reported <date>`, and report it. The fix is an ordinary TDD lane whose first
  commit is a `test-fix` turning `@test_broken` into `@test`.
- **The docs are silent:** the lead asks the package's architect.

### 5.4 Lanes and order

One backfill lane per package, dispatched by the lead (topology (a)). The test-writer gets a brief
with the gaps list, `tdd.jl api` and the docs. A mutator subagent runs mutate (§5.2), and the lead
writes the fragment.

| Order | Package | When |
|---|---|---|
| 1 | ChuiCore.jl | after its 0.3.0 sync merges; that waits for the v0.0.1 tag, and ChuiCore has none yet |
| 2 | ChuiTypes.jl | after `feat/phase5`, `feat/p5-perf` and `feat/p5-ttfx` merge, and then its 0.3.0 sync (`chore/sync-027` is merged, 08e9468) |
| 3 | ChuiFrames.jl | after `feat/p4-*` merge, and then its 0.3.0 sync (`chore/sync-027` is merged, bc8c97a) |

## 6. Cost and modes (D8)

- **Cost.** Each task adds STUB (sometimes), RED, GREEN, REFACTOR, and sometimes a dispute round:
  2–4 more handoffs per task, in sequence. That is about 1.5–2× the wall-clock, an estimate that plan
  Task 9 measures.
- **Modes.** The lead decides the mode and records it as a `TDD-Mode: <mode> — <reason>` trailer
  on a commit authored `lead <lead@factory.invalid>`, for example an empty first commit
  (`git commit --allow-empty --author "lead <lead@factory.invalid>"`). The commit guard denies that
  trailer from role agents, and denies the lead identity to any caller with an `agent_type`.

| Case | Mode |
|---|---|
| No `src/`/`ext/` change (docs, CI, tests only, backfill) | none (H1) |
| Pure refactor | `refactor` (lead-authored; the reviewer checks no behaviour is added) |
| Spike or prototype | `skip` (lead-authored with a reason; otherwise dod fails) |
| Urgent fix | `required`: the red item is the reproducer |
| Everything else | `required` (the default) |

## 7. Not in scope

- implementation;
- mutation testing as a metric;
- changing law, property or differential tests;
- glob negation;
- TDD config in `lane.jl`.

## 8. Decided (user, 2026-10-26)

The user answered the six open questions on 2026-10-26, relayed by the lead. Each answer is final
for 0.3.0 and is recorded in ADR-0015.

1. **Topology: (a).** The coordinator dispatches the roles (§0.3).
2. **An implementer edit to `test/**` FAILS** the lane: H3/H4, the hook and the commit guard.
3. **New names get STUB commits.** H5 descends into modules; new methods need no stub (§3.2).
4. **The backfill proof is a src mutation run by a separate mutator agent.** `mutexp` is a
   fallback, justified each time it is used (§5.2).
5. **Mutation cost is capped at 2 h per backfill lane.** Above the cap, split the lane or accept
   the cost; never sample (§5.2).
6. **The coverage floor is set by the user** after each backfill, to the measured value minus 1
   point (§5.1).

Decided earlier, without a question:

- the 13th role (the user asked for it);
- 0.3.0 (the CHANGELOG rule);
- subagent-only lanes until the probe passes;
- the read guard as an allowlist (the lead's ruling).

## 9. Rollout (D6, D7)

### 9.1 Version: 0.3.0

The factory CHANGELOG rule: "a breaking change (… a stricter guard) bumps the minor version while
below 1.0". This release has stricter guards (dod `tdd`, `tdd_boundary`), a narrowed implementer and
a new seeded edit.

**It builds on 0.2.8.** The dispatch_limit fix (§13) ships first, separately, as factory 0.2.8, and
0.3.0 starts from the 0.2.8 template. Each repo takes 0.2.8 before 0.3.0. Plan Task 1 starts only
after 0.2.8 is merged in `factory/`.

### 9.2 What each repo needs

| Repo | Sync brings (managed) | Hand edits (seeded; T3) |
|---|---|---|
| coordinator | the 4 tdd scripts, `tdd_boundary.sh`, `settings.json`, `test_writer.md` and the changed bodies, `checks.toml`, `dod.jl`, `/change-review`, lane-lifecycle | **the registry: `test_writer` and `implementer` entries (D7 reversed)**; `risk.toml`: the 4 scripts in the T3 globs (no `tdd` in its tiers: the coordinator has no `src/`) |
| ChuiCore.jl | the same | the registry entry, the implementer change and `tools`; `risk.toml` (`tdd` in T1–T3, the 4 scripts in T3); `test/runtests.jl` (the selection block). Waits for v0.0.1. |
| ChuiTypes.jl, ChuiFrames.jl | the same | the same; after the branches in §5.4 merge |

The package registries carry the roles for package-rooted sessions; topology (a) uses the
coordinator's.

### 9.3 Approvals (plan Task 0)

1. ADR-0015 (drafted as Proposed in this lane, `adr/0015-test-writer-role-and-test-first-lanes.md`),
   accepted by the user at this branch's merge, before Task 1. The §8 answers are already recorded,
   so Task 0's question step is complete.
2. `FACTORY_ALLOW_T3=1`:
   - for the probe in Task 0, which adds a temporary probe agent and logging hook to the coordinator;
   - for the coordinator sync and registry edit in Task 10.
3. The package hand edits, and later the coverage floors.

### 9.4 Template tests

- **scripts/test/test_tdd.jl:**
  - the classifier on the measured fixtures, every class, on both versions;
  - H1–H9, including **"stub adding export + function-end inside the module block passes H5"** (NB2)
    and "include of a new declaration-only file passes H5";
  - E1–E5;
  - mutate: kill, survive, load-breaking, dirty, unmatched, restored after a throw, two items at one
    sha;
  - gaps; api; brief (refuses a dirty tree).
- **scripts/test/test_hooks_tdd.jl:** payload cases for every rule in §0.5–0.6, about 25 (plan
  Task 8). Plan Tasks 5 and 8 list the tests rule by rule, and also name the few rules left to
  review (m4).
- **`test_dod.jl`:** `tdd`, including skip without a lead-authored mode commit, which FAILS.
- **`test_gen.jl`:** 13 agents; the implementer has no `test/**`; the test-writer's `tools` render.
- **`test_runtests_template.jl`:** `item=`, `:contract`, the stable-only exclusion, `TDD_MATCHED`.

**The dogfood limit.** Factory tests are `@testset`s and there is no `src/`, so tdd.jl cannot check
the factory's own lane. Plan Tasks 2–8 separate the contexts by hand, and the report says so.

## 10. Plan map

| Plan task | Spec |
|---|---|
| 0: ADR-0015, the user's answers, the `agent_type` probe in topology (a): unnamed and named dispatches | §0.3, §8, §9.3 |
| 1–2: fixtures; `item=` and `TDD_MATCHED` | §3.3, §3.4 |
| 3–4: the classifier; `red`, `green`, `api`, `brief` | §3, §0.4 |
| 5: history rules H1–H9 and audit E1–E5 | §4.2, §4.3 |
| 6: `mutate` (the mutator agent) and `gaps` | §5 |
| 7: dod `tdd` and the seeded `risk.toml` | §4.2, §6 |
| 8: the `tdd_boundary` hook | §0.5, §0.6 |
| 9: registry, bodies, register, skill, VERSION; the dogfood measurement | §2, §4.6, §6 |
| 10–12: coordinator sync and registry; package syncs; backfill | §9, §5 |

## 11. Later: deferred or cut, each with its trigger

| Item | Status | Trigger to revisit |
|---|---|---|
| `brief-check` lint (src paths, copied lines) and scripts/_tdd_brief.jl | deferred to 0.3.x | a reviewer finds a leak in a saved prompt that a mechanical check would have caught, or Task 9's dogfood numbers show hand-written briefs drifting from the template |
| The 30-character copied-line rule and the round-2 brief re-check (formerly E5) | cut | only together with `brief-check`, excluding docstrings and the `## Public API` section (M-F) |
| The `BOUNDARY` lint (test code reading src) | deferred | a reviewer finds a run-time source read in a red diff |
| `gaps --lcov` (uncovered lines) | deferred | local coverage verified (CoverageTools in a scratch env), or PR CI with a coverage artifact |
| Hook rows for Agent and SendMessage from role agents | replaced by `tools` frontmatter | a role is ever run where frontmatter is not honoured |
| Teammates in TDD lanes | not allowed | the probe shows `agent_type` in teammate PreToolUse payloads |
| A different model for the test-writer | deferred (old Q9) | review finds tests mirroring the implementation |
| Sandboxing the test process against src reads | not designed | a run-time read is found despite review |

## 12. Revision history: findings → changes

### Revision 2 (critic round 1)

| Finding | Change |
|---|---|
| B1: a lane with no red could pass | H2, H5, H6, H7, E2 |
| B2: no legal red for a new method | `MethodError` is BEHAVIOUR; throwing stubs rejected (§3.2) |
| B3: mutate evidence overwritten | `mutate-<slug>`/`mutexp-<slug>`; commit first (§5.2) |
| M1: wrong output model | headers only, as measured (§3.3) |
| M2: `@test_throws` masking | `Thrown:` rule, and a blind spot |
| M3: vacuous runs | `TDD_MATCHED`, NOT-RUN, a minimum total (§3.4) |
| M4: the test ban was not enforced | H3/H4; now also the hook and the commit guard |
| M5: CI does not run; two sources for the mode | local dod/audit; one mode trailer |
| M6: rebase | merge, never rebase |
| M7: the ADR came late | Task 0 |
| M8: mutate cost | a persistent scratch copy, a cap |
| m1–m9 | setup modules, gaps on 1.11+, `--no-merges`, `@test_broken`, `mutexp`, the rollout order, the dogfood limit, `test-refactor`, the `item=` exclusions |

### Revision 3 (the user's clarified purpose)

Context separation became goal 1 (§0.1). It brought:

- two fresh instances (§0.3);
- the boundary table (§0.4);
- per-role authors and H9 (§0.5);
- the `tdd_boundary` hook (§0.6);
- the leak table (§0.7).

### Revision 4 (critic round 2 and the lead's rulings)

| Finding | Change |
|---|---|
| NB1: the roles and hooks never engage in the real topology | The topology is analysed and (a) recommended (§0.3). The coordinator registry gains both roles (D7 reversed, §9.2). The hook resolves the checkout from the target path. The Task 0 probe runs in topology (a): a lead-dispatched subagent working in a package worktree |
| NB2: H5 rejected every real stub | H5 descends into `module`/`baremodule` bodies, compares multisets, and allows `include` of a new declaration-only file (§4.2). New Task 5 tests: "stub adding export + function-end inside the module block passes H5", and the include case |
| M-A: modes were self-declared | The mode must be on a lead-authored commit, and the commit guard denies `TDD-Mode:` from roles. Skip FAILS dod unless lead-authored with a reason (H8) |
| M-B: uncommitted edits crossed the handoff | `brief` refuses a dirty tree; the hook's lead-dispatch rule requires a clean lane and `head=` = HEAD; Edit/Write role scopes in the hook (§0.6) |
| M-C: the commit guard checked only `--author` | The effective author via `git var GIT_AUTHOR_IDENT` with the command's env and `-c`, for every caller; `git config user.*` is covered by the same check (§0.5) |
| M-D: the Read guard was a denylist | It is now an allowlist; transcripts, the depot and the mutate copy are denied (§0.6) |
| M-E: the Bash allowlist was too tight and too loose | `cd`/`git -C` into a checkout allowed; `evidence.jl` only through `tdd.jl`; `mutate` not for the test-writer; run-time reads stated as detected, never prevented (§0.7) |
| M-F: brief-check rejected the normal path | `brief-check` deferred and the copied-line rule cut (§11); plan task paths allowed (§0.4) |
| M-G: the agent_type claim was overstated | Restated: documented for subagents only; teammates not allowed; the Task 0 probe records SubagentStart/Stop too; the hook records `tdd-commit` ledger lines; matcher `Agent\|Task` |
| m-a: mutate leaked src to the test-writer | mutate is not the test-writer's tool (revision 5: a separate mutator agent runs it) |
| m-b: cache interaction | measured in Task 6 |
| m-c: the hook could not know "its own" brief | the allowlist uses `test-writer-*` briefs |
| m-d: fail-closed availability cost | a blind spot in the register |
| m-e: no tools frontmatter | `tools`/`disallowed_tools` set for both roles (§2.1) |
| Cut list | cut: the 30-character rule and E5; deferred: brief-check, _tdd_brief.jl, the BOUNDARY lint and `gaps --lcov`; the Agent/SendMessage hook rows replaced by frontmatter; 4 scripts; 6 open questions; §11 Later |
| Stale text (spec :466, plan :35, :54, :101) | the usage block now says H1–H9 + E1–E4; the plan header says revision 4; the class list is current (BOUNDARY deferred); Task 0 says "the 6 questions" |

### Revision 5 (critic round 3 and the lead's rulings)

| Finding | Change |
|---|---|
| NB3: `@compat public` rejected | H5 allows a `@compat`/`Compat.@compat` macrocall whose argument is `public`/`export`. Task 5 test with ChuiCore names.jl-style files |
| R3-M1: line numbers; deletions | `remove_linenums!` on both sides; removals forbidden except `export`/`public` replaced by a superset. Tests: stub above a method passes; deleting a method fails; narrowing an export fails |
| R3-M2: amend and `-C` | The author comes from the source commit for `--amend`/`-C`/`-c`/reuse; the PostToolUse check runs on the resulting commit; `tdd-commit` records the resulting sha; new E5: every role commit has a matching record (the round-2 E5, the brief re-check, stays cut); compound `add && commit` is split |
| R3-M3: git output leaked | git for the test-writer is only `status`, `add`, `commit` and `diff [--cached] -- test/…`; `log`, `show` and `<rev>:<path>` are denied |
| R3-M4: the sub-lead was undefined | In (a) the dispatcher is the lead. "The brief is the only channel" replaces "not dispatched by an agent that saw the other side". mutate runs in its own `mutator` subagent, whose report never reaches a test-writer brief |
| R3-M5: lane names repeat across repos | The header carries `checkout=<abs path>`; briefs go to the owning repo's main `.lanes/briefs/<lane>/`. Task 8 test with two repos that share a lane name |
| R3-M6: dispatch form; teammates | The exact form is stated (an Agent call, no `team_name`, no fork; named only if the probe allows). The spec says this lead's agents run as in-process teammates today. Task 0 probes an unnamed and a named dispatch and passes on PreToolUse `agent_type` alone; a missing SubagentStart is reported, not fatal |
| R3-m1: "lead-authored" was too loose | It now means `lead <lead@factory.invalid>`, denied to any caller with an `agent_type`. A mode trailer on any other commit is ignored. skip fails dod unless lead-authored with a reason |
| R3-m2: symlinks | Paths are resolved with `pwd -P` before the allowlist check; Task 8 test |
| R3-m3: the runner was writable | `test/runtests.jl` and `test/Project.toml` are denied to the test-writer (hook) and to every phase commit (H3) |
| R3-m4: rules without tests | Every stated rule has a plan test; plan "Left to review" lists the rest |
| R3-m5: one hook too big | Split into tdd_boundary.sh, _tdd_commit_guard.sh and tdd_commit_post.sh, each ≤ 150 lines |
| R3-m6: dispatch_limit | Out of scope; §13 "Related" |

### Revision 6 (critic round 4; the lead checks this delta, with no further critic round)

| Finding | Change |
|---|---|
| R4-B1: the `@compat` clause did not match the parse | H5 matches `macrocall(@compat \| Compat.@compat, LNN, :public, name\|tuple)` or one `export` Expr. The Task 5 test uses verbatim names.jl lines and the critic's p2/c2 |
| R4-M1: macrocall line nodes survived | Each macrocall's `args[2]` is stripped as well as `remove_linenums!`. Task 5 test: a stub above a **documented** method (the critic's p4/c4) |
| R4-M2: E5 read a ledger the hooks never write | One TDD ledger, defined once in §0.5: `<session root>/.lanes/ledger.jsonl`, passed to audit and dod as `--ledger`. Task 8 test where the session root ≠ the checkout |
| R4-M3: a failed or background Bash call left no record | The post hook also runs on PostToolUseFailure; `run_in_background` with `git commit` is denied; stale `tdd-pending` entries are swept (marked late); a new blind spot for a cancelled final call. Tests |
| R4-m1: precedence | `--author` > `--reset-author` > source commit > `git var`. "Or the replaced sha" deleted. Test: amend `--author` with a role is denied at Pre |
| R4-m2: the test-writer could print another commit's subject | `-C/-c/--reuse-message/--reedit-message/--fixup/--squash` denied for the test-writer; `--amend` only on a test-writer HEAD. Test |
| R4-m3: the dispatch rule admitted the mutator | Dispatch requires **no** `agent_type`. Test: a general-purpose dispatch of a test-writer is denied |
| R4-m4: H3 contradicted H4 | H4 exempts lead-authored, non-phase commits to the two seeded runners only |
| R4-m5: the §4.1 heading | Now "4 scripts plus 3 hook files" |
| The lead: prove parse-level rules by RED tests | The critic's probe pairs become named fixtures (plan Task 1: `h5/p2…c6`, `parent/child`; `git/amend`, `git/C-HEAD`, `git/amend-author`, `git/C-reset-author`), each used by a named Task 5 or Task 8 test that must be seen RED before its rule is implemented |

## 13. Related (outside this spec)

- **dispatch_limit does not bind (critic round 3, m6; measured).**
  - `dispatch_limit.sh` counts open lanes from SubagentStart events in the ledger, and none have
    been logged since 2026-10-20, so its open count is 0 and the `max_open` cap never applies.
  - The likely cause, UNVERIFIED, is that this lead's agents are in-process teammates.
  - **The fix ships first, separately, as factory 0.2.8** (the lead's decision, 2026-10-26). This
    spec does not change dispatch_limit; 0.3.0 builds on 0.2.8 (§9.1).
  - The same cause is why the `tdd-commit` ledger lines (§0.5) do not rely on SubagentStart/Stop.
