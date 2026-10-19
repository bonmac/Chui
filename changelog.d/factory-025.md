- **factory 0.2.5** (`factory/`, not yet synced into the coordinator): checks that agree between a
  fresh clone and a dev checkout. `scripts/check_docs.jl` no longer reports a reference to a
  gitignored path (such as `.claude/hooks/read-only-roots.txt`) as stale, and the gen.jl tests no
  longer depend on the host's gitignored local files, and every factory Julia file is
  Runic-formatted, so `scripts/ci.jl format` passes in a synced package. Fixes the first GitHub
  Actions failures of 2026-10-19. Spec: `docs/superpowers/specs/2026-10-20-factory-025-clean-clone.md`.
  Each package takes 0.2.5 in its own sync lane.
