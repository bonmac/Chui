# ADR-0015: Test-writer role and test-first lanes

- **Status:** Proposed. The user accepts it at the merge of `feat/testwriter-spec`. The six design
  questions in it were already answered by the user on 2026-10-26.
- **Date:** 2026-10-26
- **Deciders:** the user. The change is T3 in every repo that takes it: the registry, the bodies,
  the hooks and the gate scripts.
- **Scope:** ecosystem: the factory template (0.3.0), the coordinator, and every package that
  syncs it.

The full design is `docs/superpowers/specs/2026-10-26-factory-test-writer-design.md` (revision 6).
The implementation plan is `docs/superpowers/plans/2026-10-26-factory-test-writer.md`. This ADR
records only the decisions; the spec's section numbers are cited for detail.

This ADR is longer than 120 lines because it records seven decisions, each with the user's answer
and the hook or gate that enforces it.

## Context

- **The user's request** (2026-10-26): "plan the test-writer role. It should follow proper TDD
  principles. Write any missing tests once done." The clarified purpose: "separate the tester
  from the implementer to have separate contexts and valid testing as per TDD."
- **Today one `implementer` agent writes both the test and the code**, in one context:
  `file_scope` includes `test/**`. Nothing checks that a test was ever red, or red for a
  behavioural reason. `dod.jl`'s `tests` requirement passes when `test/` changed at all (spec
  §0.2).
- **The real topology** (measured 2026-10-26, spec §0.2):
  - one lead session runs from `<root>` (`claude --bg`), and its agents work in package worktrees
    under the coordinator's hooks;
  - the coordinator has no `implementer` or `test-writer` agent;
  - the ledger records 0 implementer events.
- **ADR-0001** caps the template at "12 roles; prune by unused for N phases". The registry asks
  whether an existing role covers any 13th. None does: law, property and differential testers need
  generators or a reference implementation, and the critic and the reviewer are read-only (spec
  §2.1).
- **Every package's `coverage.floor` is `0.0`** (spec §0.2).
- **Measured facts the rules depend on**, from the critics' probes on Julia 1.13.2 and 1.10.12,
  with TestItemRunner 1.3.2:
  - the failure-header format;
  - how `@compat public …` parses;
  - that `remove_linenums!` keeps macrocall line slots;
  - git's author precedence under `--amend` and `-C`.

  Spec §3.3, §4.2 H5 and §0.5 record these, and plan Task 1 turns them into fixtures.
- **UNVERIFIED** until plan Task 0's probe runs: that PreToolUse hook input carries `agent_type` for
  a subagent the lead dispatches into a package worktree. The Claude Code hooks docs say it does for
  subagents; on this machine every SubagentStop since 2026-10-25 has logged `agent_type "-"`.

## Decision

1. **Context separation is the principle.**
   - Each test-first task gets two fresh agent instances: a `test-writer` (new, the 13th template
     role) and an `implementer`.
   - They must never be one agent switching roles, a fork, or one resumed with the other's
     transcript.
   - The brief is the only channel between them. It is built from the include/exclude templates in
     spec §0.4, and the dispatcher must not relay src or the other side's reasoning.
2. **Topology (a)** (user, 2026-10-26).
   - The coordinator registry gains the `test_writer` and `implementer` roles, which reverses the
     earlier D7.
   - The lead dispatches them as plain subagents: `subagent_type`, no `team_name`, no fork.
   - One set of coordinator hooks resolves each target path to its checkout (spec §0.3).
   - TDD lanes must use subagents, not teammates, until the probe shows `agent_type` for teammates.
3. **The test-writer's view is limited mechanically** (spec §0.6).
   - It may read only allowlisted paths: in any checkout `test/`, `docs/`, `Project.toml`, red and
     green evidence, and its own briefs; in the coordinator also `docs/superpowers/`, `contracts/`
     and `adr/`. It may write only `test/**`, outside the seeded runners.
   - It may run only allowlisted Bash, and git only as `status`, `add`, `commit` and
     `diff -- test/`.
   - Registry frontmatter removes `Agent`, `Task`, `SendMessage`, `WebFetch`, `WebSearch` and
     `NotebookEdit` from it (spec §2.1).
   - The implementer must never write `test/**`. An implementer edit to a test FAILS the lane (user,
     2026-10-26).
4. **Identity** (spec §0.5).
   - Role commits are authored `test-writer <test-writer@factory.invalid>` or
     `implementer <implementer@factory.invalid>`. Mode commits are authored
     `lead <lead@factory.invalid>`, which only the main session may use.
   - A commit guard checks the effective author before the commit: `--author`, then
     `--reset-author`, then the source commit, then `git var`.
   - It re-checks the resulting commit after it is made, on success and on failure, and records its
     sha in the session's ledger. Audit rule E5 requires a matching record for every role commit.
5. **The TDD cycle per behaviour** (spec §3).
   - The order is STUB (new names only), then RED, then GREEN, then REFACTOR, plus `test-fix` and
     `test-refactor` (user, 2026-10-26: STUB commits for new names).
   - A red counts only for an assertion failure or an in-item exception (`MethodError` included). It
     never counts for `UndefVarError`, a parse or load error, a pass, or an unmatched item.
   - History rules H1–H9 run in `tdd.jl audit` and `dod.jl`; evidence rules E1–E5 run in audit.
     The lead runs both before every merge. TDD lanes merge `main` in and never rebase.
6. **Backfill** (spec §5; user, 2026-10-26).
   - Characterization tests are committed first. A separate `mutator` agent then proves that each
     one fails under a src mutation; `mutexp` is a fallback, justified each time it is used.
   - The cap is 2 h per backfill lane: split or accept, never sample.
   - Bugs found become `@test_broken` and are reported.
   - After each backfill, the user sets `coverage.floor` to the measured value minus 1 point.
   - The order is ChuiCore, then ChuiTypes, then ChuiFrames, each after its running branches merge.
7. **Version.** Factory 0.3.0, a minor bump (stricter guards, a narrowed role). It builds on 0.2.8,
   the separate dispatch_limit fix, which ships first.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep one implementer that writes tests first | That is the problem itself: one context writes both the test and the code (spec §0.1) |
| Fold the work into the law, property or differential tester | They need generators or a reference implementation; none writes black-box unit tests from the spec (spec §2.1) |
| Topology (b): a session started in each package repo | A `--bg` lead cannot start one, it sits outside the lead's ledger and cap, and results return through files (spec §0.3) |
| Accept `UndefVarError` as a red for new names | A typo produces the same error, so it proves nothing (spec §3.2) |
| Throwing method stubs | They change dispatch on existing generics and put code in a STUB (spec §3.2) |
| A read denylist for the test-writer | It misses transcripts, the depot copy and the mutate scratch copy, all measured (spec §12, M-D) |
| A brief linter (`brief-check`) with a copied-line rule | It false-fires on the normal path, and it misses a paraphrase, the dominant leak. Deferred with a trigger (spec §11) |
| Patch bump 0.2.8 for this change | The CHANGELOG rule calls for a minor bump when a guard becomes stricter (spec §9.1) |

## Consequences

- **Each code lane's workflow changes:** 2–4 more handoffs per task, an estimated 1.5–2× the
  wall-clock. Plan Task 9 measures it.
- **New managed files:**
  - the scripts tdd.jl, _tdd_classify.jl, _tdd_history.jl and _tdd_backfill.jl;
  - the hooks tdd_boundary.sh, _tdd_commit_guard.sh and tdd_commit_post.sh;
  - the body test_writer.md;
  - rows `tdd` and `tdd_boundary` in `.agents/checks.toml`.
- **Hand edits (T3), coordinator:** the registry entries and the `risk.toml` T3 globs.
- **Hand edits (T3), each package:** the registry, `risk.toml` (`tdd` in T1–T3) and the
  `test/runtests.jl` selection block. ChuiCore's sync waits for its v0.0.1 tag (spec §9.2).
- **What stays open** (spec §0.7 and the register's blind spots):
  - a paraphrase relayed in a brief;
  - test code that reads src at run time, which is detected only after the fact;
  - one machine setting both authors;
  - the lead's own context holding both sides.

## Verification

- **Measured by the critics** (gitignored scratch under `<root>/.lanes/scratch/tw-critic*/`):
  - TestItemRunner failure headers on both Julia versions;
  - `item=nosuch` → `Total 0`, exit 0;
  - the `@compat public` parse (`macrocall(@compat, LNN, :public, tuple)`). The related parse
    facts are recorded in `research/ecosystem-verification.md` E-37: `public` is a ParseError on
    1.10.12 and parses on 1.13.2, which is why packages write `@compat public`;
  - macrocall line slots surviving `remove_linenums!`;
  - `--amend`/`-C` keeping the source author, and `--author` overriding it;
  - `git show <rev>:<path> -- test/` printing src.
- **Measured by the lead and the critic:**
  - the coordinator's `.claude/agents/` has no role agents;
  - the ledger has 0 implementer events, and no SubagentStart since 2026-10-20.
- **UNVERIFIED:**
  - PreToolUse `agent_type` for a lead-dispatched subagent on this machine (plan Task 0);
  - that Pkg.test passes `TDD_MATCHED` to the test process (plan Task 2);
  - the mutate cost (plan Task 6);
  - whether a nonzero-exit Bash call always fires PostToolUseFailure (the docs imply it).

## Revisit when

- Plan Task 0's probe shows no `agent_type` for a lead-dispatched subagent. The boundary then needs
  another source for the role.
- The probe shows `agent_type` for teammates: TDD lanes may then use teammates.
- A reviewer finds a leak in a saved brief that a check would have caught. Bring back
  `brief-check`.
- A reviewer finds test code that reads src at run time. Bring back the BOUNDARY lint.
- Plan Task 9's dogfood numbers show the cost is far above the 1.5–2× estimate.
- Review finds tests that mirror the implementation despite the separation. Consider a different
  model for the test-writer.
