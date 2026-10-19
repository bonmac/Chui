# Ecosystem verification log (ADRs 0002–0011)

Recorded 2026-10-19 by the `eco-architect` lane; revised the same day by `eco-reviser` (Chui rename,
critic findings, entries E-23–E-34). Each entry: the claim, the source (Context7 ID / URL / command),
and the output. ADRs cite entries as `E-NN`. Local Julia: `release` = 1.13.2 and 1.11.7 (juliaup;
no `lts` channel). E-01–E-04 ran on 1.11.7; E-23/E-24 re-ran them on 1.13.2.
Local General snapshot: `~/.julia/registries/General.tar.gz` (git-tree-sha1 `eef7f5ca…`, file dated
2026-10-19 11:49): 14,576 package names, 12,701 of them non-JLL.
Scripts used by `eco-reviser` are in its session scratchpad
(`<session scratchpad>/`:
`op13.jl`, `c4.jl`, `empty.jl`, `regdeps.jl`, `s3/`); the outputs are pasted below.

## E-01 `⨟` is a valid infix operator, not defined by Base (runtime)
Command: `julia --startup-file=no op.jl` (script in the lane scratchpad). Output:
```
VERSION = 1.11.7
parse("f ⨟ g") = :(f ⨟ g) head=call args=Any[:⨟, :f, :g]
Base.isoperator(:⨟) = true
Base.isbinaryoperator(:⨟) = true
operator_precedence(:⨟) = 12  (:* => 12, :+ => 11, :∘ => 12, :|> => 9)
operator_associativity(:⨟) = left
isdefined(Base, :⨟) = false
:⨟ in names(Base) = false
codepoint = U+2A1F
parse("a ⨟ b ⨟ c") = (a ⨟ b) ⨟ c
parse("x |> f ⨟ g") = x |> f ⨟ g        # i.e. x |> (f ⨟ g), since 12 > 9
parse("f ⨟ g ∘ h") = (f ⨟ g) ∘ h
parse("a .⨟ b") = a .⨟ b
latex completions for ⨟: ["\\bbsemi"]
```

## E-02 `⨟` absent from Base source on 1.10, 1.12, 1.13 and master
Command: `gh api "repos/JuliaLang/julia/contents/base/{exports,operators}.jl?ref=<ref>"` | `grep -c '⨟'`.
Output: `master`, `release-1.13`, `release-1.12`, `release-1.10`: exports.jl count=0, operators.jl count=0.
(`∘` is exported at exports.jl:257 on master.)

## E-03 CompositionsBase.jl exports `⨟`
Command: `gh api repos/JuliaFunctional/CompositionsBase.jl/contents/src/CompositionsBase.jl`. Output (excerpt):
```
22: const var"⨟" = opcompose
30:     g ⨟ f = f ∘ g
36: export ∘, compose, opcompose
37: @eval export $(Symbol("⨟"))  # for Julia 1.0
```
Registry: CompositionsBase max 0.1.2, `julia = "1"`.

## E-04 `_` is write-only; `c.x` via `getproperty`
Same script as E-01: `_ + 1` → `ErrorException: syntax: all-underscore identifiers are write-only and
their values cannot be used in expressions`; a singleton `c` with `Base.getproperty(::ColRef, s) = (:col, s)`
gives `c.x = (:col, :x)`.

## E-05 Julia versions; local toolchain
- https://julialang.org/downloads/manual-downloads/ (WebFetch 2026-10-19): "Current Stable Release:
  v1.13.2 (October 14, 2026)"; "Long-term Support (LTS) Release: v1.10.12 (August 16, 2026)".
  (A web-search summary said 1.12.6 / 1.10.11; superseded by the live page.)
- `juliaup status` (first run): channels `1.11.7` and `release` (1.11.7, update to 1.13.2 offered); no `lts`.
- `juliaup status` (re-run by eco-reviser): `1.11.7` → 1.11.7+0.aarch64.apple.darwin14;
  `release` (default) → 1.13.2+0.aarch64.apple.darwin14; still no `lts`.
- `ls ~/.julia/registries`: only `General` (no personal registry).

## E-06 `public` keyword is Julia 1.11; Compat.jl shim
- Julia `HISTORY.md` (master, via `gh api`): line 459 under "Julia v1.11 Release Notes": "`public` is a
  new keyword. Symbols marked with `public` are considered public…".
- Compat.jl README: "`@compat public foo, bar` marks `foo` and `bar` as public in Julia 1.11+ and is a
  no-op in Julia 1.10 and earlier. (since Compat 3.47.0, 4.10.0)".
- 1.11.7: `Meta.parse("public foo, bar")` → `public foo, bar`; `isdefined(Base, :ispublic)` → true.

## E-07 Pkg compat semantics (0.x)
Context7 `/websites/pkgdocs_julialang_v1` (pkgdocs.julialang.org/v1/compatibility): `^0.2.3` → `[0.2.3, 0.3.0)`,
`^0.0.3` → `[0.0.3, 0.0.4)`, `^0` → `[0.0.0, 1.0.0)`; "a package may set version = "0.2.4" when it has
feature additions compared to 0.2.3 as long as it remains backward compatible with 0.2.0."

## E-08 Package extensions / weakdeps need Julia 1.9
Context7 `/websites/pkgdocs_julialang_v1` (toml-files, creating-packages): "Extensions require Julia 1.9+";
"Weak dependencies require Julia 1.9+"; extension code in `ext/<Name>.jl`.

## E-09 Pkg workspaces need Julia 1.12
Same source: "Workspaces require Julia 1.12+"; `[workspace] projects = ["test", "docs", …]`.

## E-10 Latest registered versions and Julia compat (local General snapshot)
Command: extract `<L>/<Pkg>/{Versions,Compat}.toml` from `General.tar.gz`, `sort -V`.
| Package | Max version | Julia compat of latest line |
|---|---|---|
| LocalRegistry | 0.5.7 | 1.6.0–1 |
| Supposition | 0.3.5 | 1.8.0–1 |
| TestItemRunner / TestItems | 1.3.2 / 1.1.0 | 1 |
| JuliaFormatter | 2.14.0 | 1.10.0–1 |
| Runic | 1.13.0 | 1.10.0–1 |
| Aqua | 0.8.18 | 1 |
| JET | 0.12.3 | 1.12.0–1 |
| ExplicitImports | 1.15.0 | 1.10.0–1 (for ≥1.13) |
| Documenter | 1.19.0 | 1.6.0–1 |
| DocumenterInterLinks | 1.1.0 | — |
| MultiDocumenter / DocumenterVitepress | 0.8.1 / 0.3.8 | — |
| Tables / Arrow | 1.14.0 / 2.8.1 | — |
| PrecompileTools | 1.3.4 | — |
| RegistryCI | 11.0.0 | — |

## E-11 JET ↔ Julia compat (corrected)
JET `J/JET/Compat.toml` in the snapshot, every `julia` entry (`awk` over section headers):
```
["0.7.15 - 0.8.21"] julia = "1.9"        ["0.8.22 - 0.9.18"] julia = "1.10"
["0.9.19 - 0.9"]    julia = "1.11"       ["0.10 - 0.10.14"]  julia = "1.12"
["0.10.15 - 0.10"]  julia = "1.12"       ["0.11 - 0.11.3"], ["0.11.4 - 0.11.6"] julia = "1.12"
["0.12 - 0"]        julia = "1.12.0 - 1"
```
Older lines (≤ 0.11) each pin **one** Julia minor. **JET 0.12 does not**: its compat is `[1.12, 2)`,
so it covers 1.12, 1.13 and later 1.x until a JET release narrows it. Latest version is 0.12.3.
Consequence: no JET 0.12 on 1.10/1.11; the 1.10 line is 0.9.0–0.9.18. (The first version of this entry
said every line pins one minor; that was wrong for 0.12.)

## E-12 Repository activity (`gh api repos/<r>`, 2026-10-19)
Supposition.jl pushed 2025-11-02 (latest release v0.3.5, 2024-07-27); TestItemRunner.jl (now
`julia-testitems/`) 2026-09-14; Runic.jl 2026-10-06; JuliaFormatter.jl (now `JuliaEditorSupport/`)
2026-09-06; LocalRegistry.jl 2026-08-12; Aqua.jl 2026-09-17; JET.jl 2026-10-15; ExplicitImports.jl
2026-06-21; Documenter.jl 2026-10-16; DocumenterInterLinks.jl 2026-10-14; MultiDocumenter.jl
2026-08-19; Registrator.jl 2026-10-02; TagBot 2026-10-05. None archived.

## E-13 Supposition.jl API
Context7 `/seelengrab/supposition.jl` (README): `using Test, Supposition`; `intgen = Data.Integers{Int8}()`;
`@check function foo(i=intgen) … end`; `@check bar(Data.Floats{Float16}())`; `@check broken=true …`;
Hypothesis-inspired, shrinking, deterministic replay; `@check` returns a `SuppositionReport`.

## E-14 TestItemRunner
https://www.julia-testitems.org/ and /guide/pkg-test: `using TestItemRunner` + `@run_package_tests`;
`@run_package_tests filter=ti->!(:skipci in ti.tags)`; filter receives `(filename, name, tags::Vector{Symbol})`;
`@testitem "CSV parsing" tags=[:parser] begin … end`; `@testmodule`, `@testsnippet` exist.
Not stated on pages fetched: module isolation per item (UNVERIFIED).

## E-15 Runic.jl
https://github.com/fredrikekre/Runic.jl README (WebFetch): no configuration ("rules set in stone");
install `Pkg.Apps.add("Runic")` (Julia ≥ 1.12) or legacy shared env; CLI `--check`, `--diff`, `--inplace`;
GitHub Action `fredrikekre/runic-action@v1`; pre-commit `fredrikekre/runic-pre-commit`; no line-length
limit ("No. Use your Enter key or refactor your code."). Registered: Runic 1.13.0 (E-10).

## E-16 JuliaFormatter v2 status
https://discourse.julialang.org/t/ann-juliaformatter-v2-updates/137818 (2026-06-26): "Since early this
year JuliaFormatter hasn't been actively maintained"; moved to an organisation; v2.10 "likely ready for
production" with Default or Blue styles with some options disabled; SciML/YAS not yet reliable; maintainer
calls Runic "very well-written".

## E-17 DocumenterInterLinks
Context7 `/juliadocs/documenterinterlinks.jl`: `links = InterLinks("name" => "https://…/")`, passed to
`makedocs(plugins = [links])`; Markdown `[`Documenter.makedocs`](@extref)`; inventories via `objects.inv`.

## E-18 LocalRegistry.jl API
`gh api repos/GunnarFarneback/LocalRegistry.jl/contents/docs/{create_registry,register,migration_from_general}.md`:
- `create_registry(name_or_path, repository_url; description, push, branch, git_config)`; by name →
  created in `~/.julia/registries` and "automatically available as an installed registry";
  `repository_url` "should be the URL to an existing but empty repository".
- `register(package = nothing; registry, commit, push, repo, ignore_reregistration, allow_package_dirty,
  gitconfig, create_gitlab_mr)`; package must be a git working copy without uncommitted changes;
  "There is no checking that the package's dependencies are available in some registry";
  LocalRegistry "should never be a dependency of the package you want to register".
- docs folder also has `registry_ci.md`: read later, see E-29.
- README: `pkg"registry add <repository url>"` once per installation; requires git ≥ 1.8.5.

## E-19 General registry README
https://github.com/JuliaRegistries/General/blob/master/README.md (WebFetch): Registrator required for
GitHub/GitLab-hosted packages; waits: new package 3 days, new version 15 min; OSI-approved license
required; "your package cannot depend on other packages that are unregistered"; LLM-generated code must
be reviewed by a human maintainer before submission.

## E-20 AutoMerge rules (source)
`gh api repos/JuliaRegistries/RegistryCI.jl/contents/AutoMerge/src/guidelines.jl`; master is
`0cb8b7615c` (2026-10-10T01:08:16Z, `gh api …/commits/master`). Line references:
```
243:  const _AUTOMERGE_NEW_PACKAGE_MINIMUM_NAME_LENGTH = 5
251-257: meets_name_length: length(pkg) >= 5, else "Name is not at least 5 characters long"
274-285: guideline_julia_name_check / meets_julia_name_check:
         occursin("julia", lowercase(pkg)); startswith(pkg, "Ju") → "Package name starts with \"Ju\"."; endswith(lowercase(pkg), "jl")
565-616: meets_distance_check(pkg, other_packages; DL_lowercase_cutoff=1, DL_cutoff=2, sqrt_normalized_vd_cutoff=2.5)
         — compares against get_all_pkg_names(registry_master; keep_jll=false); vd check only when dl <= 4
694-712: guideline_normal_capitalization: r"^[A-Z][A-Za-z0-9]*?$", not all upper-case
716-740: guideline_repo_url_requirement: "Repo URL ends with `/PackageName.jl.git`."
859-873: guideline_version_number_no_prerelease
1319-1376: get_automerge_guidelines(::NewPackage; …) lists, among others,
         1337 normal_capitalization, 1338 name_length, 1339 julia_name_check, 1340 repo_url_requirement,
         1341 version_number_no_prerelease, 1373 distance_check (run last)
```
Compat: `julia` and every dep need finite upper bounds (`meets_compat_for_julia` line 39,
`meets_compat_for_all_deps` line 122). `AutoMerge/configs/General.AutoMerge.toml`:
`new_package_waiting_minutes = 4320`, `new_version_waiting_minutes = 10`.

## E-21 Package names vs. General (Chui names)
The lead's script: `julia names.jl Registry.toml <names…>`. `names.jl` and the extracted `reg/Registry.toml` are in
`<session scratchpad>/`.
The script uses OSA Damerau–Levenshtein over all 14,576 names (a superset of AutoMerge's non-JLL list), flagging DL ≤ 2 or
lower-cased DL ≤ 1, and the same against the sibling candidates on the command line. Re-run by eco-reviser on Julia 1.13.2:
```
General names: 14576
ChuiCore    len=8 exists=false close=[] siblings≤2=[]
ChuiTypes   len=9 exists=false close=[] siblings≤2=[]
ChuiFrames  len=10 exists=false close=[] siblings≤2=[]
ChuiStats   len=9 exists=false close=[] siblings≤2=[]
ChuiLearn   len=9 exists=false close=[] siblings≤2=[]
ChuiSpatial len=11 exists=false close=[] siblings≤2=[]
ChuiPlot    len=8 exists=false close=[] siblings≤2=[("ChuiPlots", 1)]   ← only because ChuiPlots was also passed
ChuiRegistry len=12 exists=false close=[] siblings≤2=[]
ChuiPlots   len=9 exists=false close=[("ChainPlots", 2, 2)] …            ← rejected name
```
NOT run: the visual-distance check (`sqrt_normalized_vd`), so it is UNVERIFIED.
History: the first pass (`dl.jl`, 12,701 non-JLL names) found `Junta` within DL 2 of Luna, Jinja, Jute
and Juno, and every `Junta*` name failed the "Ju" rule. That is why the family was renamed.

## E-22 TagBot custom registries
`gh api repos/JuliaRegistries/TagBot/contents/README.md`: "If you're using a custom registry, add the
`registry` input: `registry: MyOrg/MyRegistry`"; public registries need nothing else; private ones need
`registry_token` or an SSH key.

## E-23 `⨟` on Julia 1.13.2; precedence gotcha
`julia +release --startup-file=no op13.jl`:
```
VERSION = v"1.13.2"
Base.operator_precedence(:⨟) = 12
Base.operator_associativity(:⨟) = :left
isdefined(Base, :⨟) = false
:⨟ in names(Base) = false
Meta.show_sexpr(Meta.parse("c.x .> 3 ⨟ g")) → (:call, :.>, (:., :c, (:quote, :x)), (:call, :⨟, 3, :g))
Meta.show_sexpr(Meta.parse("x |> f ⨟ g"))   → (:call, :|>, :x, (:call, :⨟, :f, :g))
isdefined(Base, :ScopedValues) = true; isdefined(Base, :ispublic) = true
```
So `c.x .> 3 ⨟ g` is `c.x .> (3 ⨟ g)`. Results are the same on 1.11.7 (precedence 12, left, not in Base).

## E-24 Reassigning an imported `c` (1.11.7 vs 1.13.2)
`c4.jl`: `module M; struct R end; const c = R(); export c; end; using .M; println(c); c = 1`.
```
1.13.2: Main.M.R()  /  toplevel assign after use ok: c=1          (silently shadows)
1.11.7: Main.M.R()  /  ERROR: LoadError: cannot assign a value to imported variable M.c from module Main
```
Assigning *before* the first use works on both (`c = 5` → ok). With an explicit `using ..M: c`, assignment
errors on both: 1.13.2 "cannot assign a value to imported variable M.c from module V"; 1.11.7
"cannot assign a value to imported variable V.c". `@eval global c = 1` after use: ok on 1.13.2, error on 1.11.7.
1.10.12 (run by the lead after `juliaup add lts`): `module M; export c; const c = 42; end; using .M; c; c = 1` gives `cannot assign a value to imported variable M.c from module Main`, the same as 1.11. Also `isdefined(Base, :ScopedValues)` is `false` on 1.10.12, which confirms E-25.

## E-25 ScopedValues: Base 1.11+, backport for 1.10
- Julia `HISTORY.md` (master, raw.githubusercontent.com): line 454 "Julia v1.11 Release Notes"; line 463
  "`ScopedValue` implements dynamic scope with inheritance across tasks ([#50958])"; 1.10 notes start at line 743.
- Runtime: `isdefined(Base, :ScopedValues)` → true on 1.11.7 and 1.13.2.
- ScopedValues.jl (`vchuravy/ScopedValues.jl` `src/ScopedValues.jl`): `if isdefined(Base, :ScopedValues)`
  then `import Base.ScopedValues: ScopedValue, with, @with, Scope, get`, i.e. it re-exports Base's on 1.11+.
  Registry: ScopedValues 1.6.2, `julia = "1.8.0 - 1"`.

## E-26 ExplicitImports public-name checks fall back to `isexported`
`src/improper_qualified_accesses.jl` (raw.githubusercontent.com, main), lines 83–86:
```
function public_or_exported(mod::Module, name::Symbol)
    return isdefined(Base, :ispublic) ? Base.ispublic(mod, name) :
           Base.isexported(mod, name)
end
```
It is used by `check_all_qualified_accesses_are_public` (checks.jl:444/472) and
`check_all_explicit_imports_are_public` (checks.jl:727/750). `src/deprecated.jl:69` defaults
`report_non_public=VERSION >= v"1.11-"`. Test functions (`src/test_explicit_imports.jl`): `test_no_implicit_imports`,
`test_no_stale_explicit_imports`, `test_all_explicit_imports_via_owners`, `test_all_explicit_imports_are_public`,
`test_all_qualified_accesses_via_owners`, `test_all_qualified_accesses_are_public`, `test_no_self_qualified_accesses`,
`test_explicit_imports`. So on 1.10, a name marked only with `@compat public` (a no-op) counts as non-public.

## E-27 Transducers.jl dependency weight
`julia regdeps.jl <General> closure Transducers`. Deps.toml ranges are applied to the latest version, and
transitive deps are taken at their latest versions; stdlibs are excluded. An approximation, not a resolve.
```
Transducers 0.4.85 direct registered deps: ["Accessors", "ArgCheck", "BangBang", "Baselet", "CompositionsBase",
  "ConstructionBase", "DefineSingletons", "InitialValues", "MicroCollections", "SplittablesBase", "Tables"]
transitive registered (non-stdlib) deps at latest versions: 20
```
Plus stdlibs `Distributed` and `Logging`.

## E-28 CompositionsBase dependents
`julia regdeps.jl <General> dependents CompositionsBase`:
```
CompositionsBase dependents (any version): 11
CompositionsBase dependents (latest version): 11 ["Accessors", "AccessorsExtra", "DictArrays", "ExpressBase",
  "KernelFunctions", "PlutoTables", "RadiationDetectorDSP", "Transducers", "TransformVariables", "Wflow", "WhyNotEqual"]
CompositionsBase 0.1.2 direct registered deps: []
```
`opcompose` is the ASCII name; `⨟` is `const var"⨟" = opcompose` (E-03).

## E-29 LocalRegistry defaults, repo URL, consistency tests
- `src/LocalRegistry.jl` (`gh api`): line 57 `create_registry(...; push = false, ...)`; line 194
  `register(...; commit = true, push = true, ...)`, so **register pushes by default**.
- `docs/register.md`: "`push::Bool`: Whether to push the commits to the upstream repository. Default is true …
  It cannot be set to `true` if … `commit` is `false`." "`repo` … If it is a new package, look up the URL from the
  package's `git remote`." A temporary clone is used when `commit` and `push` are both true.
- `docs/create_registry.md`: the URL "can also be a bare repository on local storage"; "use the File URI scheme,
  e.g. `file:///home/user/registry`"; for no upstream, "set `repository_url` to `"."`"; `push = false` lets you
  review before pushing.
- `docs/registry_ci.md`: `withenv("JULIA_PKG_UNPACK_REGISTRY" => "true") do RegistryCI.test(path_to_your_registry,
  registry_deps = ["General"]) end`; a sample GitLab CI job does the same.

## E-30 julia-buildpkg `localregistry` input
`gh api repos/julia-actions/julia-buildpkg/contents/action.yml`: input `localregistry`: "Add local registries hosted
on GitHub. Specified by providing the url (https/ssh) to the repositories as a newline (\n) seperated list. User is
responsible for setting up the necessary SSH-Keys". The script runs `Pkg.Registry.add()` (defaults) first, then
adds each URL.

## E-31 Pkg rejects a dev'd upstream outside downstream compat
Scratchpad `s3/`: `Up` version 0.0.4 and `Down` with `[compat] Up = "0.0.3"`, both `Pkg.develop`ed into one env
(Julia 1.13.2, `JULIA_PKG_OFFLINE=true`):
```
ERROR: Unsatisfiable requirements detected for package Up [11111111]:
 ├─Up [11111111] is fixed to version 0.0.4
 └─restricted to versions 0.0.3 by Down [22222222] — no versions left
```
After setting `Up` to version 0.0.3: `+ Up v0.0.3 ../Up` / `resolved OK with Up 0.0.3`.

## E-32 ReTestItems.jl
Context7 `/juliatesting/retestitems.jl` (`_autodocs/api-reference/01-runtests.md`, `02-testitem.md`, `configuration.md`):
- `runtests(...; nworkers, nworker_threads, worker_init_expr, testitem_timeout, retries, memory_threshold, name, tags, report, …)`;
- `nworkers`: `0` = sequential in the current process; `1` = a new process; `≥ 2` = parallel across processes;
- `testitem_timeout`: default 30·60 s, "Only applied when `nworkers > 0`"; per-item `timeout=` takes precedence;
- "Test-item code runs as top-level code in a new module";
- only files named `*_test.jl` / `*_tests.jl` (plus `*_testsetup.jl`) are included; `@testitem … retries=2 timeout=60 skip=…`.
- Registry: ReTestItems 1.35.3, `julia = "1.8.0 - 1"`. `gh api repos/JuliaTesting/ReTestItems.jl`: pushed 2026-09-14,
  archived=false. (The README fetch timed out; the docs above come from Context7.)

## E-33 Compat.jl, benchmark tools (registry + activity)
```
Compat 4.18.1            | ["4.17 - 4"] julia = "1.6.0 - 1"
AirspeedVelocity 0.6.6   | ["0.6.4 - 0"] julia = "1.10.0 - 1"
PkgBenchmark 0.2.15      | ["0.2.2 - 0"] julia = "1"
BenchmarkTools 1.8.0     | ["1.6.1 - 1"] julia = "1.6.0 - 1"
MilesCranmer/AirspeedVelocity.jl pushed=2026-10-15 archived=false
JuliaCI/PkgBenchmark.jl pushed=2026-03-13 archived=false
```
Runic `["1.4.4 - 1"] julia = "1.10.0 - 1"`, so Runic does not pin a Julia minor.

## E-34 Base/Core exports; empty-input reductions; float associativity (Julia 1.13.2 **and 1.10.12**)
*Corrected 2026-10-19 (critic B2, S12).* The first run (1.13.2 only) was wrong for 1.10: there
`maximum`/`minimum`/`extrema(Float64[])` and `reduce(max, Float64[])` throw `MethodError`, not
`ArgumentError`, and `IO`/`Task`/`Ref` are exported by Core, not Base. Command (lane
`contracts-fixer`, script in its scratchpad
`<session scratchpad>/e34.jl`):
`julia +release --startup-file=no e34.jl; julia +lts --startup-file=no e34.jl`. Output:
```
VERSION 1.13.2 | exported by Base / Core: IO=1/1 Task=1/1 Ref=1/1 Some=1/0 Option=0/0
sum 0.0 | prod 1.0 | count 0 | any false | all true | maximum throws ArgumentError | minimum throws ArgumentError | extrema throws ArgumentError | first throws BoundsError | last throws BoundsError | mean NaN | mean Int NaN | var NaN | std NaN | reduce(+) 0.0 | reduce(max) throws ArgumentError | reduce((a,b)->a) throws ArgumentError | maximum(abs) 0.0 | sum(abs2) 0.0 |
(0.1 + 0.2) + 0.3 == 0.1 + (0.2 + 0.3) → false
(1e308 + 1e308) - 1e308 = Inf   1e308 + (1e308 - 1e308) = 1.0e308
VERSION 1.10.12 | exported by Base / Core: IO=0/1 Task=0/1 Ref=0/1 Some=1/0 Option=0/0
sum 0.0 | prod 1.0 | count 0 | any false | all true | maximum throws MethodError | minimum throws MethodError | extrema throws MethodError | first throws BoundsError | last throws BoundsError | mean NaN | mean Int NaN | var NaN | std NaN | reduce(+) 0.0 | reduce(max) throws MethodError | reduce((a,b)->a) throws MethodError | maximum(abs) 0.0 | sum(abs2) 0.0 |
(0.1 + 0.2) + 0.3 == 0.1 + (0.2 + 0.3) → false
(1e308 + 1e308) - 1e308 = Inf   1e308 + (1e308 - 1e308) = 1.0e308
```
Consequences used by the contracts: the empty-input exception type is version-dependent (so
`chui-core.md` CC-006 fixes Chui's own types); `reduce(+, Float64[])` and `maximum(abs, Float64[])`
return `0.0` (so `ReduceM`/`MapM` are exempt from matching Base); `IO`/`Task`/`Ref` must be
checked against Base **or** Core (CT-003).

## E-35 Prototype behaviour the frame contract changes or relies on (1.13.2 and 1.10.12)
Command: the critic's `proto.jl` (critic scratchpad
`<session scratchpad>/proto.jl`,
which `include`s `reference/prototype/Tidy.jl`), re-run by `contracts-fixer` with
`julia --startup-file=no proto.jl` and `julia +lts --startup-file=no proto.jl`. The lines below are identical on
both versions except error-message text (the script's "eager max empty" line, omitted here,
differs by exception type exactly as in E-34). Output (1.13.2, error messages truncated):
```
c.x == c.x            true
(c.x .+ 1) == same    false
isequal(sum(c.x),same)false
hash eq (c.x .+1)     false
Dict key (c.x .+ 1)   false
c.x > 1               THROWS MethodError: no method matching isless(::Int64, ::Main.Tidy.Col)
c.x + 1               THROWS MethodError: no method matching +(::Main.Tidy.Col, ::Int64)
!c.x                  THROWS MethodError: no method matching !(::Main.Tidy.Col)
c.x in [1,2]          false
c.x == 1              false
mutate(z = c.x == 1)  (x = [1, 2, 3], g = ["a", "b", "a"], z = Bool[0, 0, 0])
filter(c.x == 1)(t)   THROWS MethodError: no method matching filter(::Bool, ::Tbl)
mutate(u=c.x|>unique) (x = [1, 1, 2], u = [1, 2])
NamedTuple input      THROWS MethodError: no method matching (::Main.Tidy.FilterStep)(::@NamedTuple{x::Vector{Int64}})
eager var             [2.139922160430262e-34]
lazy var morsel=3     [2.1185229388259596e-34]
eltypes eager/lazy    (Real, Float64)
group order eager/lazy (["a", "b"], ["a", "b"])
```
Also from `base.jl` (same scratchpad), both versions: `filter(false)` returns
`Base.Fix1{typeof(filter), Bool}(filter, false)`; `isequal(0, 0.0)` and `isequal(1, 1.0)` are
`true`. From `names.jl` (fixer scratchpad), both versions: `isequal((a=[1], b=[2.0]), (a=[1.0], b=[2]))`
is `true` and `isequal((a=1, b=2), (b=2, a=1))` is `false` (NamedTuple `isequal` compares names
and order, not element types). Used by `chui-frames.md` Definitions, CF-001, CF-005, CF-006, CF-008.

## E-36 Float-law counterexamples and the per-aggregator tolerance (1.13.2 and 1.10.12)
The counterexamples are executed, with value expectations, by `contracts/check.jl` from the
`(Base only)` block in `chui-core.md` CC-004 (output lines `ok chui-core.md:195 …` to `:207`,
identical on both versions; see the check outputs in the lane report). Key values:
`sum([1.0, 1e16, -1e16]) == 0.0` but the split `[1.0] | [1e16, -1e16]` gives `1.0`; prototype var
on `fill(0.1, 10)`: eager `2.139922160430262e-34`, lazy (morsel 3) `2.1185229388259596e-34`
(the same value as the Chan merge of the split `1:1 | 2:10`), Chan split `1:3 | 4:10`
`3.937456775191682e-34`. `isapprox` with default tolerances rejects eager vs lazy (`false`); the
CC-004 rule (`atol = √eps·sum(abs, v)` for Sum, `√eps·mean(abs2, v)` for variance,
`√(√eps·mean(abs2, v))` for std, `rtol = √eps`) accepts all three.
Moments with an empty side (`chan.jl`, fixer scratchpad), both versions: the prototype's
`partial(Moments, Float64[])` throws (`ArgumentError` on 1.13.2, `MethodError` on 1.10.12), and
merging a zero-count state `(0, NaN, 0.0)` with the state of `[1.0, 2.0]` gives `(2, NaN, NaN)`.
So Moments needs a "no value yet" state (CC-006).

## E-37 Parse shapes, `public` on 1.10, name availability, clashing exports (1.13.2 and 1.10.12)
Command: `julia +release --startup-file=no e37.jl; julia +lts --startup-file=no e37.jl` (fixer
scratchpad). Output:
```
VERSION 1.13.2
parse a ⨟ b ⨟ c args: Any[:⨟, :(a ⨟ b), :c]   a * b * c args: Any[:*, :a, :b, :c]
Expr compare: true true true
public parses: true
gated public: ok
exported by Base or Core: neutral=false mempty=false partial=false papply=false absorb=false step!=false init=false final=false combine=false iscommutative=false identity=true
two bindings, use of foo -> throws UndefVarError; extended Base.filter -> 1
WARNING: both B and A export "foo"; uses of it in module Main must be qualified
VERSION 1.10.12
parse a ⨟ b ⨟ c args: Any[:⨟, :(a ⨟ b), :c]   a * b * c args: Any[:*, :a, :b, :c]
Expr compare: true true true
public parses: ParseError
gated public: ok
exported by Base or Core: neutral=false mempty=false partial=false papply=false absorb=false step!=false init=false final=false combine=false iscommutative=false identity=true
two bindings, use of foo -> throws UndefVarError; extended Base.filter -> 1
```
(The `WARNING` line is 1.10's stderr, printed before its stdout; 1.13.2 prints no warning.)
"Expr compare" checks `Meta.parse("c.x .> 3 ⨟ g") == :(c.x .> (3 ⨟ g))`,
`Meta.parse("x |> f ⨟ g") == :(x |> (f ⨟ g))`, `Meta.parse("f ⨟ g ∘ h") == :((f ⨟ g) ∘ h)`.
"gated public" is `@static if VERSION >= v"1.11" eval(Meta.parse("public zz")) end`.
Consequences: `⨟` is binary (nested calls), unlike n-ary `*`; `public` needs a version gate on
1.10; a "both … export" warning test is vacuous on 1.13; method extension is never a clash.

## E-38 DataFrames exports `combine` (Context7)
Context7 `/juliadata/dataframes.jl` (v1.7.0 docs, the manual page split_apply_combine.md): after
`using DataFrames, CSV, Statistics`, the docs call `combine(iris_gdf, :PetalLength => mean)`
unqualified, and document `combine(gdf::GroupedDataFrame, args...; kwargs...)`. So `combine` is
an exported DataFrames name (inferred from unqualified use after `using`; the export list itself
was not fetched). Used by `chui-core.md` PROVISIONAL "Export list".

## UNVERIFIED items (collected)
- Visual-distance (`sqrt_normalized_vd`) check for every Chui name (ADR-0003).
- Pkg/LocalRegistry handling of pre-release versions (ADR-0004).
- Rewriting registry package URLs from `file://` to GitHub; one UUID in two registries; `[sources]`
  availability version; JuliaHub pricing (ADR-0005).
- `[workspace]` ignored cleanly on 1.10; the LTS user share (ADR-0006).
- Whether TestItemRunner runs each `@testitem` in its own module; one test tree under both TestItemRunner
  and ReTestItems (ADR-0007).
- Documenter 1.19 writes `objects.inv` by default; **docs.julialang.org serves an `objects.inv`**;
  `Documenter.doctest` keywords (ADR-0008).
- Which of CompositionsBase's 11 dependents re-export `⨟` (ADR-0009).
- MIT's share of General; AirspeedVelocity's CI action inputs and `SUITE` conventions; the
  julia-processcoverage output format (ADR-0011).
- Resolved since the first pass: LocalRegistry `registry_ci.md` (E-29); ReTestItems status (E-32);
  ExplicitImports test function names (E-26). Dropped: General maintainers' willingness to override "Ju" (moot after the rename).
