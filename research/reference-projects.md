# Reference projects: what the study found (summary)

Lane: `ref-research` (Phase L0, step 2a). Date: 2026-10-19. Read-only.

The factory (`factory/`) was adapted from three private local projects, studied read-only to
check `prompts/common.md` §3 against their files. This public summary keeps the findings and
drops the projects' names, paths and internals; the full study is kept outside the repo. The
decisions it fed are in [ADR-0001](../adr/0001-reference-projects-kept-and-changed.md).

- **Reference project A**: the base process (flow, ADRs, lanes, hooks, test and gate tiers).
- **Reference project B**: the agent registry, scorecards, risk tiers and lifecycle rules.
- **Reference project C**: the adversarial agents, generated `AGENTS.md`, lane caps and the
  merge gate on the merged commit.

## Corrections to §3

1. All three projects already generate their agent files from a registry with a `--check`
   that fails on drift; only B also generates Codex agent files. A's is the cleanest; C's
   split (data fields in the registry, prose bodies concatenated verbatim) is the best shape.
2. A coverage floor that only rises exists in B and C. A's floor is fixed; its real one-way
   ratchets are size budgets checked against the previous commit.
3. Risk tiers and protected paths were documented but **not enforced**: the guard always
   allowed the write, and the protected-path list existed in several disagreeing copies.
4. Every project's CI was local-only or duplicated across several runners and a Makefile,
   and some mains were left red.
5. No project had an automated definition of done (spec → plan → tests → review → CHANGELOG).

## Problems confirmed

| §3 problem | Finding |
|---|---|
| Long instruction files | Hand-maintained twin `CLAUDE.md`/`AGENTS.md` files of several hundred lines that had drifted apart |
| Too many agents | Dozens of roles in one project, most of them specialist reviewers; few demonstrably used |
| Duplicated or local-only CI | The same gates copied into several CI systems and Make targets |
| Red main tolerated | Recent CI runs red on main |
| Unnavigable decision logs | A single very long decision log with no index |
| Loose scripts | Hundreds of top-level scripts, few with their own tests |
| Root junk | Coverage, test-report and trace files at the repo root |
| No automated definition of done | Partial checks only |

## Ideas worth taking that §3 does not mention

- Spec `Status:` lines checked by a script; size budgets that only go down.
- A meta-guard: every guard reachable from CI and from the local entry point.
- A doc-reference checker (cited paths and tests must exist).
- Paired regression cases when a check changes ("prove the guard bites"); a rule that detects
  checks that cannot fail.
- `teammate_idle` that blocks the first idle and demands a report.
- A handoff template with "checks NOT run, and why" and a proof of closure.
- A PR template with risk-tier checkboxes; a PRD template for intake.
- A cap on open lanes enforced at spawn time; a lane ledger.
- Each check's blind spots written down next to it.

## Recommendations (as adopted)

The keep / adapt / drop tables are in [ADR-0001](../adr/0001-reference-projects-kept-and-changed.md).
In short: one registry generating every agent file; `CLAUDE.md` as the source of a generated
`AGENTS.md`; ADR template plus index; small tested POSIX-sh hooks instead of large Python ones;
one `risk.toml` that the write guard, the definition-of-done check and the PR template all read;
one GitHub Actions pipeline calling `scripts/ci.jl`; about 12 roles with scorecards.

UNVERIFIED: the reference projects' current CI state (nothing was run there).
