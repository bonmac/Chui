# ADR-0007: Test framework, quality checks and formatter

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint); §2 amended 2026-10-20 (user at
  the ChuiCore phase-1 ★, see "Amendment 2026-10-20")
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
   - *Amended 2026-10-20:* properties use `@check record=false db=false` plus an explicit `@test`, every
     law kit has planted-violation tests on the LTS job, and ChuiCore chose option (a). See
     "Amendment 2026-10-20" below.
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

## Amendment 2026-10-20: §2, Supposition results on the 1.10 LTS

Decided by the user at the ChuiCore phase-1 ★ (2026-10-20), on the lead's recommendation. It adds
rules to §2; nothing above is removed, and where they differ this section wins.

**Finding.**
- With Supposition 0.3.5 on Julia 1.10.12, a failing `@check` inside a `@testset` is **not
  recorded**. It prints the counterexample, but the summary is "None" and the process exits 0, so
  the run passes. On 1.13.2 the same file reports `Pass 1 Fail 1` and exits 1. The ChuiCore lane
  found this (ChuiCore `docs/research/law-kits-modules-names.md` L-4, `check3.jl`), and the lead
  reproduced it on 2026-10-20 with the same versions.
- Cause (ChuiCore L-5, read from source, not debugged at run time): Supposition defines
  `Test.get_test_counts(::SuppositionReport)` only on Julia ≥ 1.11. Julia 1.10's `Test` counts
  only child testsets that are `DefaultTestSet`s. So this is a 1.10 `Test` limitation that
  Supposition works around only on ≥ 1.11, and a Supposition release fixing 1.10 is unlikely.
- 1.10 is the blocking LTS job (ADR-0006). A property test that relies on `@check` recording
  therefore passes vacuously exactly where the matrix is meant to protect us.
- **No upstream issue is filed** (the user's decision): the defect is in 1.10's `Test`, and the
  workaround below is local and cheap.

**Rules added to §2** (every Chui package, every supported Julia version):
1. A Supposition property or law test **must** call `@check record=false db=false …` and assert
   the returned report with an explicit `@test`. It **must not** rely on `@check` recording itself
   in the enclosing testset. The same form runs on every version, so no `VERSION` branch is needed.
   - **Why `db=false`** (added 2026-10-20, same cause class: a 1.10/1.13 mismatch). ChuiCore's
     phase 2 found that Supposition's default counterexample database (`test/SuppositionDB`),
     written under Julia 1.13, crashes 1.10 with "Cannot read stream serialized with a newer
     version". ChuiCore's kits already pass `db=false` (ChuiCore `feat/phase2-traits` 58bad5d,
     reported by the lead).
   - **Packages must not commit a `SuppositionDB` directory.** A counterexample worth keeping
     becomes an explicit regression test.
2. Each law kit **must** have planted-violation tests: for each law, a deliberately unlawful
   instance run through the kit inside a capturing `Test.AbstractTestSet`. The test asserts that
   **exactly** the inner testset named after that law holds a failure, and no other law's does
   (ChuiCore ADR-0007 §5). These tests
   **must** run on the LTS CI job.
3. The pass check reads Supposition internals that are not documented API: `report.result` and
   `Supposition.Pass`, or `results(sr).ispass`, which also handles `broken` (ChuiCore L-4, L-5).
   They are pinned by `Supposition = "0.3"` and guarded by rule 2. Each repo's debt register
   records the workaround, with this section's "Revisit when" as its removal trigger.
4. **Packaging of ChuiCore's law kits is decided: option (a)** (ChuiCore ADR-0007, accepted
   2026-10-20). Method-less exported stubs, plus two extensions: `ChuiCoreTestExt` on `Test`
   (finite samples) and `ChuiCoreSuppositionExt` on `Test` + Supposition (generators). Aqua's
   `test_deps_compat` needs a compat entry for every weakdep, stdlibs included (`Test = "1"`).

**Alternatives rejected.**

| Alternative | Why rejected |
|---|---|
| Keep relying on `@check` recording, and run property tests on stable only | The LTS job is blocking (ADR-0006): law and property tests would not guard 1.10 at all. |
| `@check` as is, plus `VERSION`-gated rules (record=false only on 1.10) | Two forms of every test, and the 1.10 branch is the one nobody runs locally. |
| File an upstream issue and wait | The cause is 1.10's `Test`, and Supposition already works around it on ≥ 1.11. A fix for 1.10 is unlikely (L-5), and waiting leaves the gap open. |
| Replace Supposition | §2's original reasons stand (shrinking and replay); the workaround costs one line per property. |

**Consequences.** The factory's test template should show the `record=false db=false` + `@test`
form, and its `.gitignore` could list `test/SuppositionDB` (a
factory-maintainer change, not part of this amendment). ChuiTypes and ChuiFrames follow rule 1 in
their first property tests. Contract CC-011 is unaffected. ADR-0012 proposes recording the
decision in `contracts/chui-core.md`'s "Law kits" item, once the user applies that T3 edit.

**Verification.** ChuiCore `docs/research/law-kits-modules-names.md` L-1, L-4 (`check3.jl`: exit 0
on 1.10.12, exit 1 on 1.13.2; `check5.jl`/`check6.jl` for the workaround), L-5 (the source lines
of the cause); the lead's reproduction on 2026-10-20. Not yet copied into
`research/ecosystem-verification.md` as an E-number. The `db=false` finding comes from ChuiCore's
phase-2 lane, as the lead reported it (ChuiCore `feat/phase2-traits` 58bad5d); this lane did not
reproduce it. UNVERIFIED: that Supposition's internals stay stable across 0.3.x releases.

**Revisit when.** The LTS moves to ≥ 1.11, so the defect disappears: rule 1 may stay as the
uniform form, but its debt entry closes. Also when a Supposition release records results on
1.10, or ADR-0007's own Supposition trigger fires.
