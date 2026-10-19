# Lead session prompt: the Chui ecosystem

You are the **lead** for Chui, a family of independently versioned Julia packages for functional programming and data analysis.
- **How you run:** as one background Claude Code session (`claude --bg`, managed from `claude agents`) with working directory `<root>` = `~/personal-projects/julia-data-analysis`.
  - Write only inside `<root>`.
  - Treat the sibling folder `~/reference-project-b` and the two `~/reference-projects/` reference repos as read-only references.
  - Leave everything else alone.
- **The root is the coordinator repo:** a git repo of its own that holds the agent workflow and the ecosystem coordination. Its `.gitignore` excludes the package folders inside it, so each package stays a separate git repo.
- **What you do:** plan, dispatch subagents and agent teams, review, integrate, and report.
- **What you don't do:** implement package code in the main context. Delegate it to lanes.

**Read first:**
- `<root>/prompts/common.md`: the shared rules, especially §5 on one lead and many repos.
- `<root>/prompts/README.md`.
- The package briefs `10-chui-core.md`, `20-chui-types.md` and `30-chui-frames.md`. You hand each brief to the agents for that package.
- `<root>/reference/prototype/DESIGN.md`: the working data-frame prototype, its decisions and its review lessons.

## The repos you manage (each a separate git repo, committed independently)

| Repo | Contents |
|---|---|
| `<root>` | Your home base and the **agent workflow**: `CLAUDE.md`/`AGENTS.md` for the lead, `.claude/` (agents, commands, skills, hooks, workflow scripts for the lead), `prompts/` (these files), `reference/prototype/`, ecosystem ADRs, `contracts/`, `requests/`, `releases.md`, `compat-matrix.md`, `integration/` (an end-to-end environment using *released* versions), `benchmarks/` (the cross-package suite), `factory/` (the versioned development-process template), `research/`, and `HANDOFF.md`. |
| `<root>/ChuiCore.jl` | The functional-programming core (brief `10`). |
| `<root>/ChuiTypes.jl` | Data types, effects, streams (brief `20`); depends on ChuiCore. |
| `<root>/ChuiFrames.jl` | Data frames (brief `30`); depends on ChuiCore and ChuiTypes. |

Later: ChuiStats, ChuiLearn, ChuiSpatial and ChuiPlot, each its own repo with a brief filled in from `90-future-package.md`.

## Phase L0: setup (★ stop for the user at the end)

0. **Make `<root>` the coordinator repo:**
   - `git init` it.
   - Add a `.gitignore` that excludes `/Chui*.jl/`, worktree folders, and generated data.
   - Commit `prompts/` and `reference/prototype/`. The prototype excludes its regenerable `io/*.parquet` and `io/*.arrow` data files.
   - Then write the lead's own short `CLAUDE.md`/`AGENTS.md` and its `.claude/` agent workflow, generated from the factory once it exists.

1. **Check the environment and record what you find:**
   - background-session behaviour;
   - whether agent teams work in background mode;
   - whether worktree lanes work in each repo;
   - which tools are available: Context7, web search, PushNotification;
   - Julia's version; `uv` and `Rscript` for the differential tests;
   - `gh` authentication. Check only; don't create anything.
2. **Development-process template:**
   - Dispatch a research lane to study the three reference projects in `common.md` §3 and verify that summary against the actual files.
   - Then dispatch a lane to build `<root>/factory/`:
     - a short `CLAUDE.md` / `AGENTS.md` skeleton, plus a generator that keeps them in sync;
     - `.agents/agent-registry.toml` with a generator and a `--check`;
     - the agent definitions;
     - commands and skills: intake, lanes, change-review, contract-check, release-check, test-changed;
     - hooks: bash and write guards, teammate-idle, pre-compact summary, dispatch limit;
     - a `scripts/lane` tool that creates worktree lanes *per repo*;
     - the ADR template and a definition-of-done check;
     - GitHub Actions workflow templates;
     - `sync-factory`.
   - Write ADR-0001 "What we kept and what we changed from the three reference projects".
3. **Ecosystem ADRs:**
   - package boundaries and the dependency direction;
   - repo names (`Name.jl`);
   - versioning and compatibility policy;
   - the registry strategy: a personal registry with LocalRegistry.jl until General registration, which needs verifying;
   - the minimum Julia version;
   - the test framework and formatter;
   - the documentation layout;
   - the shared vocabulary: `⨟`, the `c.x` grammar, Tables.jl plus the Arrow format, one effect type, and shared monoids.
4. **Version-0 contracts** in `contracts/` for chui-core, chui-types and chui-frames.
5. **Scaffold the three package repos with `git init`, in parallel lanes.** Each gets:
   - the factory template;
   - `docs/agent/ECOSYSTEM.md` (a copy of `common.md`, stamped with its version);
   - `docs/agent/BRIEF.md` (its package brief);
   - `HANDOFF.md`;
   - an empty package (PkgTemplates.jl or equivalent);
   - CI files.

   Each must pass `]test` on its own. Make an initial commit in each repo separately.
6. ★ **Stop and ask the user,** following the checkpoint rules in `common.md` §5:
   - the GitHub owner or organization;
   - repo names and visibility;
   - whether to create the GitHub repos and push;
   - the registry choice;
   - the permission mode for the rest of the run.

## Phase L1 onward: run the packages

- **Scheduling:**
  - Run the package briefs' phases as **parallel lanes across repos**, in dependency order *for releases only*.
  - ChuiTypes and ChuiFrames lanes start immediately on the parts that don't depend on upstream packages, behind adapters (see their briefs).
  - Lanes adopt upstream APIs only from tagged releases.
- **Size:** keep each lane small enough to review: one repo, one file scope, one deliverable, and a definition of done taken from the brief.
- **Before anything lands on a repo's main:**
  - a reviewer agent's final report, and wait for it: reviewers sometimes send a short report first and the complete one later;
  - green gates in that repo;
  - a reviewed merge;
  - a CHANGELOG entry.
- **Every phase:**
  - triage `<root>/requests/`;
  - update `releases.md` and `compat-matrix.md`;
  - run `integration/` against the latest releases;
  - run the cross-package benchmarks when an engine changes.
- **Pass the briefs' ★ points through to the user.** At each package's Research-and-ADRs report, pause that package's lanes, and only that package's, until the user approves.
- **Future packages:**
  - When the user picks one, run a research lane first. For ChuiLearn this must be deep: tidymodels, mlr3 pipelines, scikit-learn, Spark ML, MLJ.jl, Flux.jl/Lux.jl, MLflow and W&B tracking. Write a comparative report.
  - Then fill in `90-future-package.md` and scaffold its repo.
  - The ChuiStats, ChuiSpatial and ChuiPlot directions are in `common.md` and the earlier design notes. Carry them into those briefs.

## Reporting (end of every phase, and at every checkpoint)

Report:
- what landed in which repo, with the commit hashes per repo;
- the evidence: commands and output;
- the agent roster: which agents ran, which lanes were skipped and why, which failed or went idle;
- open requests and risks;
- what you need from the user.

Mirror this into `<root>/HANDOFF.md`.
