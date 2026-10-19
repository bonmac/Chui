# ADR-0006: Minimum Julia version

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint)
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem (a downstream package may raise its own floor, never lower it below its upstreams)

## Context

As of 2026-10-19: stable is **1.13.2**, LTS is **1.10.12** (E-05). Locally, juliaup has `release`
= 1.13.2 and `1.11.7`, with no `lts` channel. `common.md` §3 asks for a CI matrix of LTS, stable
and nightly.

| Feature | First version | Needed for | Evidence |
|---|---|---|---|
| Package extensions, `[weakdeps]` | 1.9 | all optional integrations | E-08 |
| `public` keyword | 1.11 (`@compat public` is a no-op on 1.10) | marking contract API | E-06 |
| `Base.ScopedValues` | 1.11 (ScopedValues.jl backport for ≤ 1.10) | ChuiTypes effect environment and cancellation | E-25 |
| Pkg `[workspace]` | 1.12 | test and docs sub-environments (a convenience) | E-09 |
| JET 0.12 | compat `[1.12, 2)`; JET 0.9.0–0.9.18 is the 1.10 line | the type-stability gate | E-11 |
| Runic as a Pkg app (`-m`) | 1.12 (Runic itself: `[1.10, 2)`) | local formatter CLI | E-10, E-15 |

## Decision

1. **`julia = "1.10"`** in every package's `[compat]` (i.e. `[1.10, 2.0)`). Decided by the user at
   the L0 checkpoint (2026-10-19), over the 1.12 runner-up below.
2. **CI matrix:** `lts` (blocking), `1` = stable (blocking), `pre`/nightly (non-blocking). JET, the
   docs build, doctests and snapshot tests run on stable only (ADR-0007, ADR-0008).
3. **Runtime code** must work on 1.10:
   - mark the public API with `@compat public …` or `export`;
   - ChuiTypes uses the ScopedValues.jl backport, which re-exports `Base.ScopedValues` on 1.11+ (E-25).
4. **Compat.jl is allowed in every Chui package without a per-package dependency ADR** (recorded
   once, here): Compat 4.18.1, compat `Compat = "4.10"` or later (`@compat public` needs ≥ 4.10.0; E-06, E-33).
5. **Local machine:** the lead should run `juliaup add lts` so both blocking CI versions can be
   reproduced locally. `release` is already 1.13.2.

### Costs of the 1.10 floor

| Cost | Mitigation |
|---|---|
| `public` is a no-op on 1.10 | `@compat public`; the docs mark the public API (ADR-0008) |
| ExplicitImports falls back to `isexported` when `Base.ispublic` is missing (E-26), so its `*_are_public` checks report `public`-only names as non-public on 1.10 | run `test_all_qualified_accesses_are_public` / `test_all_explicit_imports_are_public` only when `VERSION ≥ v"1.11"` |
| No `Base.ScopedValues` | ScopedValues.jl as a ChuiTypes dependency (its own dependency ADR) |
| JET 0.12 does not install | JET in its own environment, stable only (ADR-0007) |
| No `[workspace]` | separate `test/`, `docs/` and JET `Project.toml` files |
| Behaviour differs between 1.10/1.11 and 1.13 (e.g. reassigning an imported `c`, E-24) | snapshots and doctests run on stable only; documented per case |

## Alternatives rejected

| Alternative | Cost if chosen |
|---|---|
| `julia = "1.12"` (strong runner-up) | **Loses:** users on LTS 1.10 (their share is UNVERIFIED), and the `lts` CI job, so `common.md` §3 must change. **Gains:** native `public` and ScopedValues; correct ExplicitImports public checks; JET 0.12 in the normal test env; workspaces; one fewer Julia version to debug; fewer `VERSION` gates. |
| `julia = "1.11"` | Gains `public`, ScopedValues and `Memory`, but 1.11 is neither LTS nor stable, and JET 0.12 still does not install. |
| `julia = "1.9"` | Below LTS, with no CI coverage; ExplicitImports ≥ 1.13 needs 1.10 (E-10). |

## Consequences

- TTFX budgets are measured on stable *and* LTS.
- A runtime feature needing ≥ 1.11 (e.g. `Memory`-backed buffers in ChuiFrames) needs that
  package to raise its floor by ADR, or to gate the code on `VERSION`.
- JET findings that only appear on LTS are not caught (an accepted blind spot).

## Verification

- E-05 (julialang.org downloads; `juliaup status`), E-06 (HISTORY.md, Compat README),
  E-08/E-09 (Pkg docs), E-11 (JET `Compat.toml`), E-24 (`c` reassignment), E-25 (HISTORY.md
  line 463; ScopedValues.jl source), E-26 (ExplicitImports source), E-33 (Compat registry entry).
- UNVERIFIED: whether 1.10 ignores a `[workspace]` section cleanly; the LTS user share.

## Revisit when

- A new LTS is announced (move the floor to it).
- A package ADR needs a runtime feature from ≥ 1.11.
- JET publishes a line whose compat covers 1.10 again, or ExplicitImports drops 1.10.
