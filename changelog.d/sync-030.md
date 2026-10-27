- **Changed:**
  - The coordinator is synced to **factory 0.3.0**, including the tw-032 amendment
    (`--profile coordinator`; 96 managed files added and 20 updated; `.factory-version` records
    0.3.0). It brings the test-writer role and
    test-first lanes (ADR-0015; spec `docs/superpowers/specs/2026-10-26-factory-test-writer-design.md`):
    the tdd scripts (`scripts/tdd.jl`, `_tdd_classify.jl`, `_tdd_history.jl`, `_tdd_evidence.jl`,
    `_tdd_backfill.jl`), the `tdd_boundary` and `tdd_commit_post` hooks with `_tdd_allow.sh` and
    `_tdd_commit_guard.sh`, `bodies/test_writer.md`, the changed bodies, `checks.toml`, `dod.jl`,
    `/change-review` and the `lane-lifecycle` skill.
    - The eight seeded files whose factory copy differs (`.agents/agent-registry.toml`,
      `.gitignore`, `CHANGELOG.md`, `CLAUDE.md`, `HANDOFF.md`, `LICENSE`, `ratchets.toml`,
      `risk.toml`) are left as they are, apart from the hand edits below.
  - The coordinator registry gains the `test-writer` and `implementer` agents. Their entries are
    the template's, with the managed bodies (spec §2.1, D7 reversed). `risk.toml` protects the five
    tdd scripts as T3. The coordinator's tiers do not require `tdd`, because it has no `src/`.
    Restart the session before the first TDD dispatch.
  - The spec records the lead's E5 ruling from lane tw-031 (§0.5 dated note): violations match lane
    shas only, and a late swept record satisfies E5 only through the lead's `TDD-Waiver`.
