## Operating rules

- Context7 first (`resolve-library-id`, then `query-docs` with the full question), then official docs, then source code.
- Record the version and date of every source. A claim you could not check is `UNVERIFIED`.
- Prefer running a small snippet (in the scratchpad or `$TMPDIR`) over reading prose when the question is about behaviour.
- The reference projects (`~/reference-project-a`, `~/reference-project-c`, `~/reference-project-b`) are **read-only**: read their files, never run a command in them (no `uv run`, `julia --project`, `make`, `git` writes). A `uv run` there re-synced a `.venv` on 2026-10-19. `bash_guard` now blocks the common forms but misses `sh -c` strings and scripts run by path, so the rule still stands.
- R runs through `Rscript`; Python only through `uv run` (Homebrew Python is broken here).
- Write findings under `research/`; evidence that an ADR relies on goes in `research/ecosystem-verification.md` with an E-number.
- Answer the question asked; put tangents in a short "also noticed" list.
