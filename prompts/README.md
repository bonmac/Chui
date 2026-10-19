# Junta: one background lead session, separate repos

A single Claude Code session, the **lead**, runs the whole effort as a background agent and orchestrates subagents and agent teams. Everything lives under **`<root>` = `~/personal-projects/julia-data-analysis`**: the agent workflow, the coordination, and the package repos. Each package is a **separate git repo**, committed, released and pushed to GitHub independently.

## Layout

```
~/personal-projects/julia-data-analysis/    <root>: coordinator git repo + the lead's working directory
├── CLAUDE.md, AGENTS.md     lead instructions        (created by the lead in phase L0)
├── .claude/                 lead agents, commands, skills, hooks, workflow scripts
├── prompts/                 these files: 00-lead.md, common.md, package briefs
├── reference/prototype/     the earlier Tidy.jl prototype and DESIGN.md
├── factory/                 versioned development-process template, vendored into each package repo
├── adr/ contracts/ requests/ releases.md compat-matrix.md
├── integration/ benchmarks/ research/ HANDOFF.md
├── .gitignore               ignores /Junta*.jl/, so the packages stay separate repos
├── Junta.jl/                git repo: functional-programming core
├── JuntaADT.jl/             git repo: data types, effects, streams   (depends on Junta)
└── JuntaDF.jl/              git repo: data frames                    (depends on Junta and JuntaADT)
```

## Files in `prompts/`

| File | Used by |
|---|---|
| `00-lead.md` | The lead session's prompt. This is what you launch. |
| `common.md` | Shared rules for the lead and every agent; copied into each package repo as `docs/agent/ECOSYSTEM.md`. |
| `10-junta.md`, `20-junta-adt.md`, `30-junta-df.md` | Package briefs the lead hands to that package's agents; copied into each repo as `docs/agent/BRIEF.md`. |
| `90-future-package.md` | Brief template for JuntaStat, JuntaML, JuntaSF and JuntaPlot. |

## Launch

```sh
cd ~/personal-projects/julia-data-analysis
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --bg -n junta --permission-mode acceptEdits \
  "Read prompts/00-lead.md and follow it exactly."
```

`--bg` prints the session id. Then:

| Command | Does |
|---|---|
| `claude agents` | Agent view: lists the background sessions and their state (running or waiting for input). |
| `claude attach junta` | Open the lead in this terminal, e.g. to answer a ★ checkpoint. Part of the name works too. |
| `claude logs junta` | Print the lead's recent output without attaching. |
| `claude stop <id>` / `claude rm <id>` | Stop the session, or delete it (and its worktree, when that's safe). |
| `claude --bg --resume <id>` | Continue the same session in the background later. |

**Notes:**
- **Permission prompts:** a background session waits at any permission prompt or ★ checkpoint until you attach. `acceptEdits` lets it edit files without asking but still asks before shell commands; `auto` asks less often.
- **Agent teams:** the lead's first job is to check whether agent teams work in background mode. If they don't, it falls back to subagents and says so.
- **Your approval stays required** for creating GitHub repositories, choosing their visibility, pushing, registering packages and deleting anything, whatever the permission mode.

## How the work flows

- **Lanes:** each lane works on one repo, in a git worktree of that repo, on a separate set of files. Lanes in different repos run in parallel.
- **Commits:** each repo, including the root, is committed independently. A change spanning packages becomes one commit per repo, upstream first and released before downstream adopts it.
- **Independence:** every package repo passes `]test` from a fresh clone, using only *released* versions of the other packages.
- **Contracts:** `<root>/contracts/` defines what each package promises the others, and downstream repos test against those contracts.
- **Cross-package needs:** these are written as `<root>/requests/*.md` and scheduled by the lead.
- **State:** `<root>/HANDOFF.md` holds the overall state. Each package repo has its own `HANDOFF.md`.
