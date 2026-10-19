# Changelog

All notable changes to the coordinator repo (agent workflow, factory sync, coordination files) are recorded here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/).
Every PR adds a line under `## Unreleased` (checked by `scripts/dod.jl`); breaking changes
carry migration notes.

## Unreleased

- Vendored the ecosystem factory template, profile `coordinator` (see `.factory-version`).
- Coordinator `CLAUDE.md`, agent registry (10 coordinator roles), `risk.toml` protected paths.
- Bootstrap spec `docs/superpowers/specs/2026-10-19-coordinator-bootstrap.md`; HANDOFF brought up to date; the reference-repo rule now says what bash_guard catches and what it misses.
- Skeletons: `requests/README.md`, `releases.md`, `compat-matrix.md`, `integration/README.md`, `benchmarks/README.md`.
