# ADR-0004: Versioning and compatibility policy

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint)
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem

## Context

Each package is released on its own, and downstream packages adopt upstream releases
deliberately (`common.md` §2, §5). Pkg applies SemVer with a leading-zero rule (E-07):
`"0.2.3"` means `[0.2.3, 0.3.0)`, and `"0.0.3"` means `[0.0.3, 0.0.4)`. General requires
upper-bounded `[compat]` for `julia` and every dependency, and rejects pre-release versions for
new packages (E-20). Pkg refuses to resolve a `develop`ed package whose version is outside a
dependent's `[compat]` (E-31).

## Decision

1. **Version rules, one per range:**
   - **0.0.x (unstable snapshots):** every release bumps the patch (`0.0.3` → `0.0.4`), and Pkg
     treats every release as breaking. There is no "compatible feature release" in this range.
     Downstream compat names the exact snapshots it was tested with, e.g. `ChuiCore = "0.0.4"`.
     Several entries are allowed once each is tested (`"0.0.4, 0.0.5"`).
   - **0.x, x ≥ 1:** bump the **minor** (`0.3.2` → `0.4.0`) for any breaking change, including
     removing or renaming a contract item (ADR-0010). Bump the **patch** for backward-compatible
     features and fixes. Downstream compat names the minor, e.g. `ChuiCore = "0.3"`.
   - **≥ 1.0:** standard SemVer: major = breaking, minor = features, patch = fixes. Downstream
     compat names the major, e.g. `ChuiCore = "1"`, or `"1.4"` when it needs a 1.4 feature.
2. **Pre-0.1 snapshots go to the personal registry as `0.0.x`;** the first stable version is
   `0.1.0`. **Decided at the L0 checkpoint (2026-10-19):** `0.0.x` snapshots replace brief
   `20-chui-types.md`'s "tagged pre-release (`v0.1.0-DEV`)", and the brief now says so. Reason:
   pre-release versions fail AutoMerge and their Pkg/LocalRegistry handling is UNVERIFIED.
3. **`[compat]` on everything:** `julia` (ADR-0006), every `[deps]`, every `[weakdeps]`, and the
   test, docs and JET environments. Bounds are caret ranges with a finite upper bound (no `">=x"`,
   no bare `"0"`).
4. **When `version` changes on `main`:** only in the **release commit**, the one that is
   registered. Between releases, `main` keeps the last released version number. That way the
   "upstream `main`" contract job (rule 5) still satisfies downstream compat and tests the new
   *code*. If `main` had already bumped to `0.0.5`, Pkg would refuse a downstream that asks for
   `0.0.4` (E-31): the job would fail by construction and say nothing about the API.
5. **Contract tests** (`test/contracts/`, ADR-0010) run in CI twice, each in its own environment
   (not the package's test environment):
   - against the **latest registered release** of each upstream: **blocking**;
   - against **upstream `main`**, through a `Pkg.develop` of the git URL done in CI only:
     **warning only** (`continue-on-error: true`).
6. **Breaking-change process** (in this order):
   1. a contract ADR in the root repo naming the change, its migration and the affected downstreams;
   2. where feasible (from 0.1 on), a deprecation release first (`Base.@deprecate` /
      `Base.depwarn`) that keeps the old API for one minor cycle;
   3. the breaking release (rule 1) with a `CHANGELOG.md` entry and migration notes;
   4. `releases.md` and `compat-matrix.md` updated; each downstream upgrades on its own branch.
7. **CompatHelper** opens PRs to widen bounds. A widening is merged only after the contract tests pass.
8. **Every PR updates `CHANGELOG.md`** (Keep a Changelog style, with a `## Unreleased` section).

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Lock-step versions for all packages | Contradicts independent releases and forces no-op releases. |
| `v0.1.0-DEV` pre-release tags (brief 20's original wording; rejected at the L0 checkpoint) | Rejected by AutoMerge for new packages (E-20); Pkg resolution of pre-releases UNVERIFIED. |
| Bump `main`'s version right after each release (`-DEV` style) | Breaks the upstream-`main` contract job by construction (E-31). |
| CI rewrites downstream compat before the `main` job | More machinery, and it hides the very compat question the job should raise. |
| Unbounded or `"*"` compat | Fails AutoMerge (E-20) and lets breaking upstream releases in silently. |
| Contract tests only against `main` | `main` is not what users install, so the blocking run must use the release. |

## Consequences

- A downstream package cannot adopt an upstream feature until it is registered.
- In the 0.0.x phase every upstream release forces a compat edit downstream. That is intended:
  each adoption is deliberate.
- The factory CI template needs two contract jobs per upstream, each with its own environment.

## Verification

- E-07: Pkg compatibility docs (Context7 `/websites/pkgdocs_julialang_v1`).
- E-20: AutoMerge `guideline_version_number_no_prerelease` (guidelines.jl 859–873, listed at 1341).
- E-31: local test — Pkg reports "Unsatisfiable requirements" for a dev'd `Up 0.0.4` against
  `Up = "0.0.3"`, and resolves once the version is `0.0.3`.
- UNVERIFIED: Pkg/LocalRegistry handling of pre-release versions (not needed if rule 2 holds).

## Revisit when

- A package reaches 0.1 or 1.0.
- The deprecation cycle proves too slow or costly in practice.
