# ADR-0003: Repository and package names

- **Status:** Accepted (2026-10-19, user at the L0 checkpoint)
- **Date:** 2026-10-19
- **Deciders:** the user (who chose the names), at the L0 ★ checkpoint
- **Scope:** ecosystem

## Context

The first family name, `Junta*`, failed General's AutoMerge: names may not start with "Ju", and
`Junta` was within Damerau–Levenshtein (DL) distance 2 of `Juno`, `Jute`, `Jinja` and `Luna`
(E-20, E-21). The user chose new names on 2026-10-19. These are the AutoMerge rules for a **new
package**, from RegistryCI `AutoMerge/src/guidelines.jl` at master `0cb8b7615c` (E-20):

| Rule | Source lines |
|---|---|
| The name is at least 5 characters long | 243 (`_AUTOMERGE_NEW_PACKAGE_MINIMUM_NAME_LENGTH = 5`), 251–257 |
| It does not contain "julia", start with "Ju", or end with "jl" | 274–285 (`meets_julia_name_check`) |
| It starts with an upper-case letter, uses ASCII alphanumerics only, and is not all upper-case | 694–712 (`meets_normal_capitalization`) |
| The repo URL ends with `/Name.jl.git` | 716–740 (`guideline_repo_url_requirement`) |
| Distance check against every registered non-JLL name: DL ≤ 2 fails; DL ≤ 1 on lower-cased names fails; a visual-distance score `sqrt_normalized_vd` ≤ 2.5 fails when DL ≤ 4 | 565–616 (`meets_distance_check`, defaults at 575–577) |
| All of the above apply to new packages | 1337–1340 and 1373 (`get_automerge_guidelines(::NewPackage)`) |

The distance check runs against the registry *at registration time*. Once ChuiCore is in General,
it is one of the "other packages", so **sibling names must also be far apart.**

## Decision

1. **Package names** (module name = package name):

   | Package | Role | Former name |
   |---|---|---|
   | `ChuiCore` | functional-programming core | Junta |
   | `ChuiTypes` | data types, effects, streams | JuntaADT |
   | `ChuiFrames` | data frames | JuntaDF |
   | `ChuiStats`, `ChuiLearn`, `ChuiSpatial`, `ChuiPlot` | future packages | JuntaStat, JuntaML, JuntaSF, JuntaPlot |

   "The Chui ecosystem" names the family. Contract files are `contracts/chui-core.md`,
   `chui-types.md` and `chui-frames.md`.
2. **Every new name must pass, before anything is created under it:**
   - at least 5 characters, ASCII, CamelCase starting upper-case, not all upper-case;
   - no "julia" anywhere, no "Ju" prefix, no "jl" suffix;
   - OSA Damerau–Levenshtein > 2, and lower-cased DL > 1, against **every General name and every
     sibling name**, checked with the lead's script (E-21).

   `ChuiPlots` was rejected under this rule (DL 2 from `ChainPlots`).
3. **Repo names:** `<Name>.jl`, one GitHub repo per package, under the owner the user picks. The
   remote URL must end in `/<Name>.jl.git`.
4. **Local layout:** `<root>/<Name>.jl/`, each its own git repo. The coordinator ignores them with
   `.gitignore` pattern `/Chui*.jl/`. Lane worktrees live in `<root>/<Name>.jl/.worktrees/<lane>/`.
5. **Personal registry:** repo and registry name `ChuiRegistry` (ADR-0005). It is not a package,
   so the AutoMerge name rules do not apply to it.
6. **The background session name is `chui`** (`claude --bg -n chui`, `claude attach chui`). It is
   an operator handle, not a package name. *(Amended 2026-10-28, user decision: the original rule
   kept the pre-rename handle `junta`; `prompts/README.md` and `prompts/common.md` §5 now say
   `chui`. A session started as `junta` keeps that name until it is restarted.)*

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep `Junta*` and ask General maintainers for a manual merge | Every first registration needs a human override of a rule that exists to avoid confusion with official Julia packages; the user chose to rename instead. |
| `ChuiPlots` | DL 2 from `ChainPlots` (E-21). |
| Repos without `.jl` (`chui-frames`) | Fails AutoMerge's repo-URL rule (lines 716–740). |
| A monorepo with subdirectories | Contradicts ADR-0002. |

## Consequences

- All briefs, prompts, contracts and `.gitignore` patterns use the Chui names (renamed in this pass).
- Each future package name is re-checked against the then-current General snapshot before its repo is created.

## Verification

- E-20: guidelines.jl line references above (fetched with `gh api` 2026-10-19).
- E-21: `julia names.jl Registry.toml ChuiCore ChuiTypes ChuiFrames ChuiStats ChuiLearn ChuiSpatial
  ChuiPlot ChuiRegistry` over 14,576 General names: no name within DL ≤ 2 (or lower-cased DL ≤ 1)
  of a General name or of a sibling; all names are 8–12 characters long.
- **UNVERIFIED:** the visual-distance check (`sqrt_normalized_vd`) was not run for any name.

## Revisit when

- Before each first General registration: re-run E-21 and the visual-distance check against the current registry.
- RegistryCI changes `guidelines.jl` name rules.
