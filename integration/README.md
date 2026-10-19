# integration/

An end-to-end environment that checks the **released** Chui packages work together
([ADR-0010](../adr/0010-cross-repo-workflow.md), rule 5). Run by the integration-tester every
phase and after each release; results become rows in [compat-matrix.md](../compat-matrix.md).

Planned contents (none exist yet; there is no `Project.toml` until the first package is registered):

- `Project.toml`: `add`s the **latest registered** versions of each package. Never `develop` a
  path or a branch: this environment tests what users get.
- End-to-end scripts that use the packages together (core combinators → types → frames).
- `runs/<date>/Manifest.toml`: the resolved manifest of each run, kept as evidence. The root
  `integration/Manifest.toml` is gitignored.
