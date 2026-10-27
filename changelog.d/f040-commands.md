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
  - Task 7 (D7): `factory/template/.claude/skills/lane-lifecycle/SKILL.md` names the cap's key
    (`[lanes] max_open` in `.agents/agent-registry.toml`) and never a number or a claim marker
    ("default 4" is gone): the file is synced unchanged into repos whose caps differ, so the number
    lives in each repo's CLAUDE.md with its `<!-- claim: max_open=N -->` marker, which
    `factory/template/.agents/factory.toml` `[check_claims] required = ["max_open"]` keeps requiring.
    Its "Close" rule says a report file counts only once its first line is the Verdict line and that
    `scripts/lane audit <name> --report <file>` runs after the reviewer's FINAL report.
    `factory/template/CLAUDE.md` (134 lines, rendered into `factory/template/AGENTS.md`) gains
    "Precedence" (the factory's `scripts/lane`, reviewer, critic, cap and intake tiers win over
    `using-git-worktrees`, `subagent-driven-development` and `brainstorming`; plugin skills only
    for brainstorming at T2+ and executing a plan) and "Writing files under the guard"
    (Edit/Write only; `(cd dir && cmd)`; a refused probe is `NOT RUN`; gated words go in a file),
    and lists `/lane-review` and `/ci-triage`. `factory/template/.claude/commands/lanes.md` step 2
    names `.claude/worktrees/*` as unmanaged. Test: `test_check_claims.jl` (the skill carries no
    `claim: max_open` marker and no cap number; a package-shaped repo whose registry says 6 and whose
    CLAUDE.md marker says 4 fails `check_claims --strict` naming `CLAUDE.md`, never the skill).
  - Review round 1 (`fix(commands)`): B1, the skill's hardcoded `max_open=4` marker broke
    `check_claims` in every synced repo with another cap (above). M1: the `description:` of
    `lane-review.md` and `ci-triage.md` held `: ` unquoted (invalid YAML): both double-quoted, and
    `test_check_docs.jl` checks every `.claude/commands/*.md` frontmatter (a value holding `: ` is
    quoted; `ruby -ryaml` parses the block when ruby is present). `/lane-review`: step 3 compares the
    evidence files' `tests:` headers, not a hand-parsed Test Summary; step 5 says
    `subagent_type: reviewer`; step 8 copies the base evidence file into the lane's
    `.lanes/evidence/` before removing the base checkout, and step 9 quotes both. `/ci-triage` step 5
    labels in order: a gate → `guard`, else passes locally → `flake`, else → `defect`.
