- **Changed:**
  - The coordinator is synced to **factory 0.2.7** (`--profile coordinator`; 18 managed files
    updated, `scripts/test/test_runtests_template.jl` added, `.factory-version` records 0.2.7).
    `docs/CHECK_COVERAGE.md` is regenerated from `.agents/checks.toml`.
    - `julia scripts/ci.jl <job> --timeout SECONDS` (or `CI_TIMEOUT`) bounds a job and kills its
      whole process group on expiry (exit 124). The coordinator's CLAUDE.md Commands block now names
      it, since CLAUDE.md is seeded and the sync does not update it.
    - Where `origin/<base>` does not resolve, `lane audit`, `dod.jl`, `ratchet.jl` and `bench.jl`
      fall back to the local `<base>` and print a note.
    - Evidence records a signalled run's termination signal and does not count it as a pass.
    - The seven seeded files whose factory copy differs (`.agents/agent-registry.toml`,
      `.gitignore`, `CHANGELOG.md`, `CLAUDE.md`, `HANDOFF.md`, `LICENSE`, `ratchets.toml`) are
      left as they are.
