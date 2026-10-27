- **factory 0.4.0, commands** (`factory/template/`; not yet versioned or synced), plan
  `docs/superpowers/plans/2026-10-27-factory-040.md` Tasks 6 and 7 (and Task 5's verdict words in
  `/change-review`):
  - Task 6 (D6, D12): new `factory/template/.claude/commands/lane-review.md` (`/lane-review <lane>`:
    pre-flight of lane, base and merge base; `scripts/lane audit --reported`; the test gate by repo
    kind through `scripts/evidence.jl` as `base-<sha>`/`lane-<sha>` (a `Project.toml` → `ci.jl test`
    on both plus `tdd.jl gaps` and a `tdd.jl mutate` per new `@testitem`; a `factory/MANIFEST.toml`
    → the factory suite on both plus the D3 hook-mutation route, `NOT RUN` while `runtests.jl` has
    no `--hooks-dir`; neither → `NOT RUN`; `not applicable`, `waiting` and exit 124 are printed
    `NOT RUN`, never green; `evidence.jl` has no `diff`, so the two `latest` files are compared by
    hand); `ci.jl guards` and `dod.jl`; the `reviewer` dispatched with base, scope, evidence names
    and the report path `.lanes/reports/<name>-<round>.md`; the FINAL report; then
    `scripts/lane audit <lane> --report <file>`; the agent closed) and
    `factory/template/.claude/commands/ci-triage.md` (`/ci-triage [run id]`: `gh run list --limit 5`,
    `gh run view <id> --log-failed`, failed jobs grouped by their first `Test Failed at` or `ERROR:`
    line, each reproduced with `julia scripts/ci.jl <job> --timeout 900`, labelled
    `flake | guard | defect`, a table and the next lane per defect).
    `factory/template/.claude/commands/change-review.md` step 2 runs `/lane-review <lane>` and step 5
    uses `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST` with `Head: <sha>`. The coordinator
    profile (`factory/MANIFEST.toml`) excludes `.claude/commands/{contract-check,release-check,test-changed}.md`,
    whose descriptions now start `Package repos only:`. Tests: `test_sync_factory.jl` (the
    coordinator dry run offers none of the three and both new commands; the package run offers
    both), `test_check_docs.jl` (every `scripts/` path the two commands name exists).
  - Task 7 (D7): `factory/template/.claude/skills/lane-lifecycle/SKILL.md` states the cap once as
    the registry's number with a `<!-- claim: max_open=4 -->` marker ("default 4" is gone; the
    template registry says 4, so the skill says 4), and its "Close" rule says a report file counts
    only once its first line is the Verdict line and that `scripts/lane audit <name> --report <file>`
    runs after the reviewer's FINAL report. `factory/template/.agents/factory.toml` `[check_claims]`
    keeps `required = ["max_open"]` over every tracked `*.md` (`files = []`), so the skill is checked.
    `factory/template/CLAUDE.md` (134 lines, rendered into `factory/template/AGENTS.md`) gains
    "Precedence" (the factory's `scripts/lane`, reviewer, critic, cap and intake tiers win over
    `using-git-worktrees`, `subagent-driven-development` and `brainstorming`; plugin skills only
    for brainstorming at T2+ and executing a plan) and "Writing files under the guard"
    (Edit/Write only; `(cd dir && cmd)`; a refused probe is `NOT RUN`; gated words go in a file),
    and lists `/lane-review` and `/ci-triage`. `factory/template/.claude/commands/lanes.md` step 2
    names `.claude/worktrees/*` as unmanaged. Test: `test_check_claims.jl` (a copy of the skill
    against a registry of another cap fails `check_claims --strict` naming `SKILL.md`).
