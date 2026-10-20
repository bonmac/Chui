- **factory 0.2.6** (`factory/`, not yet synced into the coordinator or the packages): lanes that
  work in their own worktrees. `scripts/lane new` copies `.agents/factory.local.toml` into the lane
  and runs gen.jl there. bash_guard protects T3 paths of a lane worktree created earlier in the same
  command. Merge bases (`lane audit`, `dod.jl`) prefer the local base when it contains
  `origin/<base>`, and `lane audit` takes `--base`. A lane's session may write its repo's other lane
  worktrees and `<main>/.lanes/reports/`, which teammate_idle now also reads in lane worktrees. The
  test template shows the ADR-0007 §2 Supposition form (`record=false db=false` plus `@test`) and
  ignores `test/SuppositionDB/`, and the `Manifest-v1.10.toml` LTS pattern is documented.
  Spec: `docs/superpowers/specs/2026-10-20-factory-026-design.md`. Each repo takes 0.2.6 in its own
  sync lane.
