# ADR-0008: Documentation layout

- **Status:** Proposed
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem

## Context

`common.md` requires Documenter.jl sites with doctests, and each repo must build its docs alone
(§2). The packages reference each other heavily: ChuiCore's aggregators appear in ChuiFrames'
aggregation docs, and ChuiTypes' effect runtime in ChuiFrames' I/O docs. Cross-package links must
survive independent releases. Documenter 1.19.0 and DocumenterInterLinks 1.1.0 are registered and
active (E-10, E-12). DocumenterInterLinks resolves `[text](@extref Target)` links against another
project's `objects.inv` inventory, configured with `InterLinks("ChuiCore" => "<docs URL>")` and
`makedocs(plugins = [links])` (E-17).

## Decision

1. **Per-repo docs** in `docs/`, with their own compat-bounded `docs/Project.toml` and `docs/make.jl`.
   Built in CI on stable Julia. Deployed with `deploydocs` to that repo's GitHub Pages (`stable` +
   `dev`) once the user approves pushing.
2. **Layout (Diátaxis-style):**
   ```
   docs/src/
     index.md         what it is, install (incl. `registry add`), a 30-second example
     tutorials/       learning-oriented, runnable end to end
     howto/           task recipes
     explanation/     design, laws, cost model, comparisons; links to ADRs
     reference/       @docs/@autodocs API pages; the laws per typeclass
     changelog.md     included from CHANGELOG.md
   ```
3. **Doctests:**
   - Every exported function's docstring has at least one `jldoctest`. **Exemption:** an API whose
     output is nondeterministic (effect scheduling, concurrency, timing, task ids) may use a plain
     `julia` block instead. The docstring then names the `@testitem` that covers it, and the
     package's `docs/doctest-exemptions.md` lists it.
   - Doctests run **on stable Julia only**: a stable-only CI step calls
     `Documenter.doctest(Pkg; manual = true)`, and the docs build runs them too. Printed types and
     error messages differ between Julia versions, so LTS jobs skip doctests.
   - `doctest = :fix` is never used in CI.
4. **Cross-package links** use DocumenterInterLinks `@extref` against the upstream's **released**
   (`stable`) docs, never `dev`. Links to Julia Base use the same mechanism if docs.julialang.org
   serves an `objects.inv` (UNVERIFIED); otherwise they use plain URLs.
5. **Ecosystem entry point:** the coordinator's `README.md` links every package's docs and the ADR
   index. A combined MultiDocumenter site is deferred.
6. **API stability in docs:** each reference page marks contract items with their ID (ADR-0010).

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| One combined docs site built from all repos | Couples docs builds to several repos' heads; breaks "each repo stands alone". |
| Plain absolute URLs for cross-links | Break silently when pages are renamed; `@extref` fails the build instead. |
| Doctests on every matrix version | Version-dependent printing makes LTS doctests flaky or forces lowest-common-denominator examples. |
| DocumenterVitepress | An extra Node toolchain in CI, with no need shown yet. |

## Consequences

- Docs deployment needs GitHub Pages and a deploy key per repo (user confirmation, like pushes).
- Before an upstream's first docs release, downstream `@extref` targets do not exist. Downstream
  docs use plain text there until then (tracked as a request).
- Doctests no longer check LTS output; the unit tests cover LTS behaviour.

## Verification

- E-10, E-12, E-17 (Context7 `/juliadocs/documenterinterlinks.jl`).
- UNVERIFIED: that Documenter 1.19 writes `objects.inv` by default; that docs.julialang.org
  publishes one; the exact `Documenter.doctest` keyword set.

## Revisit when

- Three or more packages have released docs (evaluate MultiDocumenter).
- A package's tutorials need executed plots or output (consider Literate.jl).
