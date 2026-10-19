# Spec: coordinator bootstrap (Phase L0)

Status: Implemented (awaiting the L0 ★ checkpoint) · Date: 2026-10-19 · Tier: T3

## Goal

Turn `<root>` into the Chui coordinator repo described in `prompts/00-lead.md` (Phase L0, steps 0–5) and `prompts/common.md` §5: the lead's own agent workflow, generated from the factory, plus the ecosystem coordination skeleton.

## Scope

- **Factory:** vendor `factory/` into the coordinator with `--profile coordinator` (ADR-0001, the factory README).
- **Lead instructions:** `CLAUDE.md` as the source; `AGENTS.md` generated from it.
- **Coordinator roster:** 10 roles in `.agents/agent-registry.toml`, with repo-owned bodies `coord_*.md`.
- **Protected paths:** `risk.toml` makes the user's briefs (`prompts/`) and `contracts/` T3, and `adr/`, `factory/`, `releases.md` and `compat-matrix.md` T2.
- **Reference repos:** `.agents/factory.toml` lists the three reference repos as bash_guard read-only roots (the 2026-10-19 incident).
- **Skeletons:** `requests/README.md`, `releases.md`, `compat-matrix.md`, `integration/README.md` and `benchmarks/README.md` follow the formats in ADR-0010.

Out of scope: any package code; remotes, pushes and registries (all wait for the ★ checkpoint).

## Basis

- ADR-0001: what was kept and changed from the reference projects.
- ADR-0010: the cross-repo workflow (requests, contracts, releases, compat matrix, integration).

## How the T3 files were written

The seeded `risk.toml` makes the registry, `risk.toml`, `settings.json` and the hooks T3, so a first vendoring cannot pass write_guard. The user authorized the following one-time bypasses on 2026-10-19; each lane listed the files it wrote:

1. **coord-setup:** the coordinator bootstrap.
2. **The 0.2.0 sync** into the coordinator, plus the lead's follow-up: `.agents/factory.toml` added to the T3 globs.
3. **contracts-fixer:** `contracts/` fixes after the critic.
4. **One `check_docs` exclusion** in each package's `.agents/factory.toml` at scaffold.

The 0.2.1 sync wrote only `.factory-version` among T3 files and fell under authorization 2.

## Verification

Run from the coordinator worktree:

- `julia scripts/gen.jl --check` → OK (26 files)
- `julia scripts/test/runtests.jl` → 581/581
- `julia scripts/check_docs.jl` → OK
- `julia scripts/dod.jl --base main` → must pass on the branch before main is fast-forwarded
- Reviewer: coord-review on 275e879 (changes requested: this spec, the ratchet, a stale HANDOFF, and a stale safety claim). The ratchet failure is a factory bug, fixed in factory 0.2.2, whose sync awaits the user.
