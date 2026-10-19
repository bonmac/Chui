# ADR-0007: Test framework, quality checks and formatter

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint)
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem

## Context

`common.md` §1.7 and §4 require unit, law (property-based), contract, differential and snapshot
tests; Aqua, JET and ExplicitImports; and "JuliaFormatter, using the style recorded in the
ecosystem ADR". Latest registered versions (E-10, E-32) and repo activity (E-12):

| Tool | Version | Julia compat | Notes |
|---|---|---|---|
| TestItemRunner / TestItems | 1.3.2 / 1.1.0 | `1` | active; VS Code test-explorer runner |
| ReTestItems | 1.35.3 | ≥ 1.8 | active; same `@testitem` style; worker processes, per-item `timeout`, `retries`, memory threshold |
| Supposition | 0.3.5 | ≥ 1.8 | API fits; **last release 2024-07-27** |
| Aqua | 0.8.18 | `1` | active |
| JET | 0.12.3 | `[1.12, 2)`; 0.9.0–0.9.18 is the 1.10 line | active |
| ExplicitImports | 1.15.0 | ≥ 1.10 | public-name checks need 1.11+ (E-26) |
| Runic | 1.13.0 | `[1.10, 2)` (no Julia pin) | zero-config, `runic-action@v1` |
| JuliaFormatter | 2.14.0 | ≥ 1.10 | revived 2026; Blue/Default "likely ready" (E-16) |

## Decision

1. **Unit tests: TestItems via TestItemRunner.** `test/runtests.jl` is
   `using TestItemRunner; @run_package_tests` (optionally with a `filter` on `ti.tags`, E-14).
   Standard tags: `:unit`, `:laws`, `:property`, `:contract`, `:differential`, `:snapshot`, `:slow`, `:quality`.
   **ReTestItems** may replace the runner in a package by that package's ADR. ChuiTypes should
   evaluate it for its leak and cancellation stress tests, since it provides per-item timeouts
   and process isolation (`nworkers ≥ 1`). Whether one test tree runs unchanged under both runners
   is UNVERIFIED (ReTestItems needs `*_test.jl` file names and has `@testsetup`).
2. **Property and law tests: Supposition.jl** (`Supposition = "0.3"`), test-only.
   - Law kits take an **equality predicate** argument (default `isequal`; `isapprox` with stated
     tolerances for floating-point instances), because float aggregates are only approximately
     associative (ADR-0009 §5).
   - **Packaging of ChuiCore's law kits** (ChuiCore's phase-1 ADR picks one; Supposition must not
     be a hard dependency):
     - (a) an extension on weakdeps `Test` + `Supposition`. Extension modules cannot add to the
       parent's exports, so ChuiCore **declares and exports stub functions**
       (`function test_monoid_laws end`) and the extension adds the methods;
     - (b) a separate test-utilities package that depends on ChuiCore and Supposition. Its name
       must pass ADR-0003, and it is versioned with ChuiCore;
     - rejected: a submodule that hard-depends on Supposition.
   - Supposition's release staleness is tracked in each repo's debt register.
3. **Quality gates** (a `:quality` test item each, failing the build):
   - `Aqua.test_all(Pkg)`;
   - ExplicitImports: `test_no_implicit_imports`, `test_no_stale_explicit_imports`, and the
     `*_via_owners` checks on every version. The `*_are_public` checks run **only on
     `VERSION ≥ v"1.11"`** (E-26).
   - **JET has its own environment**, `test/jet/Project.toml` with `JET = "0.12"`, run by a
     stable-only CI step (`JET.test_package(Pkg; target_modules = (Pkg,))`). JET is **not** in
     `test/Project.toml`: JET 0.12 needs Julia ≥ 1.12, so it would break resolution on the 1.10 job (E-11).
4. **Snapshot tests:** golden files under `test/snapshots/`, compared as text and updated only with
   `CHUI_UPDATE_SNAPSHOTS=1`. Output that depends on the Julia version (printing types, lowered
   code) is compared **on stable only**, or kept as per-version goldens
   (`test/snapshots/v1.13/…`) when both versions matter.
5. **Formatter: Runic.jl**, decided by the user at the L0 checkpoint (2026-10-19). Zero-config;
   `runic-action@v1` in CI; no line-length rule (E-15). This replaces `common.md` §1.7's
   "JuliaFormatter", and §1.7 now names Runic and cites this ADR.
6. **Doctests** run on stable only (ADR-0008).

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| `JET = "0.9, 0.12"` in `test/Project.toml` | It resolves on every version (0.9 on 1.10/1.11, 0.12 on ≥ 1.12), but it loads JET's heavy tree into every matrix job, gives findings that differ by JET line, and can hold back other test dependencies. |
| Plain `Test` + `include` files | No per-item tags or editor runner; tiers would be hand-rolled env-var logic. |
| ReTestItems everywhere | Better isolation and timeouts, but stricter file naming and no clear gain for the pure packages; kept as a per-package option. |
| JuliaFormatter 2.x (Blue style) | `common.md` §1.7's original choice. Needs a style config per repo and a line-length policy; it was revived only in 2026 (E-16). Rejected at the L0 checkpoint in favour of zero-config Runic. |
| Hand-rolled property testing | Shrinking and replay are the hard part; Supposition provides them. |

## Consequences

- Factory CI template: the test matrix (ADR-0006); the Runic format check; a stable-only JET step with
  its own environment; stable-only doctest and snapshot steps; contract jobs (ADR-0004).
- Supposition is a single-maintainer dependency with slow releases: a tracked risk.

## Verification

- E-10, E-11 (JET `Compat.toml`), E-12, E-13 (Supposition, Context7), E-14 (julia-testitems.org),
  E-15 (Runic README), E-16, E-26 (ExplicitImports source), E-32 (ReTestItems, Context7
  `/juliatesting/retestitems.jl`).
- UNVERIFIED: whether TestItemRunner runs each `@testitem` in its own module (ReTestItems documents
  that it does); one test tree under both runners.

## Revisit when

- Supposition has a breaking bug, or a successor appears.
- LTS moves to ≥ 1.12 (JET can move back into the test env).
- Runic changes its style incompatibly, or stops being maintained.
