# Environment check (Phase L0, step 1)

Recorded 2026-10-19 by the lead session. Every line below comes from a command or tool call run in this session.

## Session

| Item | Finding | Evidence |
|---|---|---|
| Session mode | Background job (`claude --bg`), job dir `~/.claude/jobs/11d20fa9`, bypass-permissions mode. | session context |
| Background edit guard | Edits in the shared checkout are rejected until the session isolates. The lead therefore edits the coordinator repo in the worktree `.claude/worktrees/lead-l0` (branch `worktree-lead-l0`) and merges to `main` locally at each checkpoint. | Write tool refusal text |
| Agent teams | **Teammates work, but in-process, not in tmux panes.** An Agent call with a `name` spawns a teammate (mailbox, SendMessage). `ListAgents` labels them `pane`, but `tmux list-panes -a` shows no pane for them: the background lead has `$TMUX` unset, so there is no session to split. The user confirmed they see no panes. Watch them via `claude agents` / `claude attach junta`. For real tmux panes, run the lead interactively inside tmux. | `echo $TMUX` → empty; `tmux list-panes -a`; `ListAgents` |
| Agent teams (interactive, re-checked) | **Relaunched interactively inside tmux session `junta`: teammates open as real tmux panes.** Spawning `ref-research` and `eco-architect` created panes `junta:1.2` and `junta:1.3`. | `tmux list-panes -a` |
| Use | Named teammates for lanes that need continuation via SendMessage; unnamed background subagents for one-shot tasks. Close each when done (TaskStop). | — |
| Worktree lanes | `EnterWorktree` failed before `git init` ("not in a git repository"); succeeded after. Per-package lanes use `git worktree add <repo>/.worktrees/<lane>` through `factory/scripts/lane`; verified per repo in step 5. | tool output |
| Context7 | Available (`mcp__context7__*`). Prototype notes: Arrow.jl and Parquet2 are not indexed. | ToolSearch |
| Web search / fetch | `WebSearch`, `WebFetch` available. | ToolSearch |
| PushNotification | Available. | ToolSearch |

## Toolchain

| Tool | Version |
|---|---|
| Julia | `release` 1.13.2 (default), `lts` 1.10.12, and `1.11.7`, all via juliaup. Updated by the user on 2026-10-19; check with `julia +lts --version`. |
| Julia registries | `General` only (no personal registry yet) |
| Julia default threads | 1 — run with `-t auto` |
| uv | 0.12.23; `uv run --python 3.13` → CPython 3.13.13 works |
| Rscript | R 4.4.2; `dplyr`, `tidyr`, `data.table`, `readr` installed |
| git | 2.56.0, user Boniface Makone |
| gh | logged in as `bonmac`. Checked only; nothing created. |
| Hardware | Apple M3 Pro, 12 CPU threads, 18 GiB RAM, macOS 26.6.2 |

## Reference repos (read-only)

- The three reference repos (paths in the gitignored `.agents/factory.local.toml`) — all present. One has a second copy elsewhere on the machine; it is listed as a read-only root too.

## Consequences

- The CI LTS job can be reproduced locally with `julia +lts`.
- Under `--bg`, teammates run in-process with no panes. When the lead runs interactively inside tmux, they open as panes. Phase rosters list every teammate and subagent either way.
