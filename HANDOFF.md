# HANDOFF — Junta coordinator (lead)

Updated: 2026-10-19 · Phase: **L0 setup (paused, relaunching interactively)**

## State
- Coordinator repo `<root>` on `main` (`7e1fe92`: prompts + prototype). Lead work is on branch `worktree-lead-l0` (worktree `.claude/worktrees/lead-l0`).
- Done: L0 step 0 (git init, .gitignore, first commit) and step 1 (environment check, `research/environment.md`).
- The user asked to stop the `--bg` session and relaunch the lead interactively inside tmux, so teammates get visible panes.

## Lanes
| Lane | Scope | Status |
|---|---|---|
| ref-research | `research/reference-projects.md` | **Stopped by the lead before reporting; no output written. Re-dispatch.** |
| eco-architect | `adr/0000`, `adr/0002–0010`, `adr/README.md`, `research/ecosystem-verification.md` | **Stopped by the lead before reporting; no output written. Re-dispatch.** |

## Next
1. Merge `worktree-lead-l0` into `main`, then re-dispatch both lanes in parallel (00-lead.md steps 2–3).
2. Re-check that teammates now appear as tmux panes (`tmux list-panes -a`) and update `research/environment.md`.
3. Continue L0 steps 2–6; stop at the ★ checkpoint.

## Decisions waiting for the user
- (filled in at the ★ L0 checkpoint)
