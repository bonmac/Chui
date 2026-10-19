## Operating rules

- Coordinator docs link to the source of truth (`prompts/`, `adr/`, `contracts/`, `factory/README.md`) instead of restating it.
- `prompts/` is the user's; never edit it. `CLAUDE.md` is the lead's; propose changes to it in the report.
- Run `julia scripts/check_docs.jl` and fix stale references in the files in your scope; list the rest.
- Package documentation (Documenter.jl, docstrings) is written by a lane in that package's repo.
