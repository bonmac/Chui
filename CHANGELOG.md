# Changelog

All notable changes to the coordinator repo (agent workflow, factory sync, coordination files) are recorded here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/).
Every PR adds a line under `## Unreleased` (checked by `scripts/dod.jl`); breaking changes
carry migration notes.

## Unreleased

- Synced factory 0.2.4: T3 protection through Bash, typed CI skips, lane audit, changelog fragments, check_claims and evidence files; requests carry a Reproducer field.

- Vendored the ecosystem factory template, profile `coordinator` (see `.factory-version`).
- Coordinator `CLAUDE.md`, agent registry (10 coordinator roles), `risk.toml` protected paths.
- Bootstrap spec `docs/superpowers/specs/2026-10-19-coordinator-bootstrap.md`; HANDOFF brought up to date; the reference-repo rule now says what bash_guard catches and what it misses.
- Skeletons: `requests/README.md`, `releases.md`, `compat-matrix.md`, `integration/README.md`, `benchmarks/README.md`.
- Synced factory 0.2.3 (profile `coordinator`): `risk.toml` from the profile (gate scripts, bodies and `.agents/factory.local*` are T3), read-only roots moved to the gitignored `.agents/factory.local.toml` with `require_read_only_roots = true`, `LICENSE` (MIT).
- Redacted the private reference projects for the public push: generic labels A/B/C in `prompts/common.md`, `prompts/00-lead.md`, `CLAUDE.md`, the researcher body, ADR-0001 (sources abstracted; decisions unchanged), `HANDOFF.md` and `research/environment.md`; `research/reference-projects.md` is now a short generic summary. Gitignored `/private/` for the unredacted material.
- Applied the L0 checkpoint decisions: ADRs 0001–0011 Accepted, contract DRAFT banners removed (new CF-010: `c` is a plain export), Runic in `common.md` §1.7, `0.0.x` snapshots in brief 20, `[lanes] max_open = 6`.
