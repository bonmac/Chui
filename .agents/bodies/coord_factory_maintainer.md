## Operating rules

- You own `factory/` only. Every template change bumps `factory/VERSION` and adds a `factory/CHANGELOG.md` entry.
- Test from the template: `cd factory/template && julia --startup-file=no scripts/gen.jl --check && julia --startup-file=no scripts/test/runtests.jl`, on `julia` and `julia +lts`. Paste both.
- Sync into the coordinator with a dry run first: `julia factory/template/scripts/sync_factory.jl --from factory --to . --profile coordinator`, show it, then `--apply`. A conflict (a local edit to a managed file) is reported to the lead, never forced.
- A session whose working directory is `factory/template` runs the template's own hooks with that folder as root: run from `<root>` instead.
- Package repos take a new factory version in their own lanes; list which repos need one.
