# ADR-0005: Registry strategy

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint)
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem

## Context

Downstream packages must depend on *released* upstream versions (`common.md` §2), long before the
packages are ready for General. Only `General` is installed locally (E-05). Verified facts:
- **LocalRegistry.jl** 0.5.7 (E-10, E-18, E-29):
  - `create_registry(name_or_path, repository_url; description, push = false, branch, …)`. The
    URL may be a bare repo on local storage (`file:///…`), or `"."` for a registry with no upstream.
  - `register(package; registry, commit = true, push = true, repo, …)`: it **pushes by default**.
    For a new package, `repo` defaults to the package's `git remote` URL, which is recorded in the
    registry. With `commit` and `push` both true, it registers from a temporary clone.
  - It does not check that dependencies are registered anywhere.
  - Consistency testing: `RegistryCI.test(path; registry_deps = ["General"])`, with
    `JULIA_PKG_UNPACK_REGISTRY=true` (`docs/registry_ci.md`).
- **julia-buildpkg** has a `localregistry` input: a newline-separated list of registry URLs, added
  after General (E-30).
- **TagBot** supports custom registries through its `registry: Owner/Repo` input (E-22).
- **General** (E-19, E-20): Registrator only; a 3-day wait for a new package; an OSI-approved
  license; no dependencies on unregistered packages; LLM-generated code must be reviewed by a human.

## Decision

1. **Personal registry `ChuiRegistry`**, its own GitHub repo, created with
   `LocalRegistry.create_registry("ChuiRegistry", "<git URL>"; description = "Chui ecosystem", push = false)`,
   then reviewed and pushed by hand, at `github.com/bonmac/ChuiRegistry`. Visibility is **public**
   (decided at the L0 checkpoint), so that CI and TagBot need no tokens; a private registry needs
   a key in every repo's CI (E-22).
2. **Gate "create and push the package and registry repos": opened at the L0 checkpoint
   (2026-10-19).** The user approved GitHub owner **`bonmac`**, **public** visibility, and creating
   and pushing `ChuiRegistry` and each `<Name>.jl` repo (`ChuiCore.jl`, `ChuiTypes.jl`,
   `ChuiFrames.jl`). The lead performs those outward actions; until they are done, rule 3 applies.
3. **Local-only fallback until the repos exist on GitHub:**
   - create the registry against a local bare repo
     (`create_registry("ChuiRegistry", "file:///<root>/.registry/ChuiRegistry.git"; push = false)`),
     with `<root>/.registry/` git-ignored;
   - register with `register(pkg; registry = "ChuiRegistry", repo = "file:///<root>/<Name>.jl", push = false)`
     (an explicit file URL, because the package has no remote yet), then commit and push to the
     local bare repo;
   - downstream lanes `pkg> registry add file:///…`, and contract tests run **locally only**;
   - after the gate opens, the registry's package URLs are rewritten to the GitHub URLs in one
     reviewed commit. The rewrite procedure is UNVERIFIED and must be tested on a throwaway package first.
4. **Release flow (personal registry, after the gate):** the release-manager lane, once the user
   confirms the release:
   1. the release commit bumps `version` (ADR-0004 rule 4);
   2. **push `main`, then wait for CI to be green on that commit**;
   3. from a clean clone, `register(; registry = "ChuiRegistry")`, which pushes by default;
   4. TagBot (`registry: bonmac/ChuiRegistry`) tags the commit and creates the GitHub release;
   5. record the release in `releases.md` and `compat-matrix.md`.
5. **CI** adds the registry with julia-buildpkg's `localregistry: <ChuiRegistry URL>`. The registry
   repo runs `RegistryCI.test` with `registry_deps = ["General"]` on every push.
   **CompatHelper and TagBot use `ChuiRegistry` as an extra registry** (decided at the L0
   checkpoint): CompatHelper is given General plus `ChuiRegistry`, so it widens bounds on Chui
   upstreams too, and TagBot gets `registry: bonmac/ChuiRegistry` (E-22). The exact CompatHelper
   keyword is UNVERIFIED until the registry exists (factory `CompatHelper.yml` comment).
6. **LocalRegistry lives in a shared environment** (e.g. `@registry`), never in a package.
7. **Moving to General** happens per package, in dependency order (ChuiCore first), and only when:
   the user decides; the license is OSI-approved (ADR-0011); the name re-check passes (ADR-0003);
   and a human has reviewed the code. After that, the package's new versions go to General only.
   What happens when one UUID is in both registries is UNVERIFIED: test it with a throwaway package.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Register in General from day one | Unstable APIs, a 3-day wait for each new package; General is for released software. |
| `Pkg.develop` or URL deps committed in `Project.toml` | Forbidden by `common.md` §2: not reproducible, no compat resolution. |
| `[sources]` with git URLs | Pins a commit rather than a released version (availability version UNVERIFIED). |
| Private repos and a private registry | Needs a deploy key or token in every repo's CI and in TagBot (E-22); the user chose public. |
| JuliaHub private registry | Needs an account and paid features (pricing UNVERIFIED). |
| Registering before CI is green on the pushed commit | It could register a version that does not pass its own tests. |

## Consequences

- Until the approved repos are created and pushed, cross-package CI is impossible: GitHub runners
  cannot reach a `file://` registry.
- Public repos and a public registry: CI and TagBot need no registry tokens.
- Every downstream CI workflow and `integration/` environment must add the registry first.
- Registrations happen from a clean clone, never from a lane worktree.

## Verification

- E-18, E-29: LocalRegistry `src/LocalRegistry.jl` (defaults at lines 57 and 194),
  `docs/register.md`, `docs/create_registry.md`, `docs/registry_ci.md`.
- E-30: `julia-actions/julia-buildpkg` `action.yml`. E-22: TagBot README. E-19/E-20: General README, RegistryCI.
- UNVERIFIED: rewriting registry URLs from file to GitHub; one UUID in two registries;
  `[sources]` version; JuliaHub pricing.

## Revisit when

- A package is ready for General, or the user wants a private registry.
- LocalRegistry gains or loses features (e.g. a 0.6 release).
