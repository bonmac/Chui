# factory/: the development-process template

A versioned template (`VERSION`, `CHANGELOG.md`) that each package repo vendors, and that the
coordinator repo uses for itself (profile `coordinator`). What was kept from and changed
relative to the three reference projects is in `../adr/0001-reference-projects-kept-and-changed.md`.

## Use it

```sh
# bootstrap a repo (dry run first; nothing is written without --apply)
julia factory/template/scripts/sync_factory.jl --from factory --to ChuiCore.jl
julia factory/template/scripts/sync_factory.jl --from factory --to ChuiCore.jl --apply
# later, from inside the repo: show and then take a newer factory version
julia scripts/sync_factory.jl --from ../factory
julia scripts/sync_factory.jl --from ../factory --apply
# the coordinator itself
julia factory/template/scripts/sync_factory.jl --from factory --to . --profile coordinator
```

After a sync, the repo owns its seeded files (`CLAUDE.md`, `risk.toml`, `ratchets.toml`,
the registry, ...); the factory owns managed files; generated files are rebuilt by
`julia scripts/gen.jl`. `MANIFEST.toml` says which file is which. `.factory-version` records
the version, profile, ADR directory, source commit and the hash of every managed file, so a
local edit is detected as a conflict instead of being overwritten.

### Profiles

A `MANIFEST.toml` profile adapts the template to a kind of repo:

- `exclude`: template paths the profile does not take (the coordinator drops package CI,
  `test/`, and `docs/adr/*`, whose source is the coordinator's own `adr/`).
- `overlay`: a directory under `factory/` whose files replace template files for that profile.
  `profiles/coordinator/` seeds the coordinator's `.agents/factory.toml` (the read-only
  reference roots and the `check_docs` exclusions) and its `risk.toml` (`prompts/*` and
  `contracts/*` T3, `adr/*` and `factory/*` T2); `profiles/package/.agents/factory.toml`
  excludes from `check_docs` the verbatim copies every package carries (`docs/agent/*`,
  `test/contracts/*.md`).
- `adr_dir` (default `docs/adr`): template `docs/adr/*` lands there, `docs/adr/` in seeded
  files and managed `*.md` files is rewritten to it, and it is recorded in `.factory-version`
  so `scripts/dod.jl`'s ADR check looks there. The coordinator uses `adr`.

`.agents/factory.toml` (seeded, T3) holds the repo's own settings: `[bash_guard]
read_only_roots` (rendered by `gen.jl` into `.claude/hooks/read-only-roots.txt`; inside those
directories bash_guard lets only read-only commands run) and `[check_docs]` (`exclude`,
`external`, `ignore_fenced`). In a checkout that holds the factory (the coordinator),
`check_docs.jl` also resolves the backticked paths of `factory/*.md` against `factory/template/`,
since these files describe the template's layout.

### Start sessions and dispatch lanes from the repo root

Claude Code takes hooks from the session's project directory. A session or lane started with
its working directory inside `factory/template/` gets the TEMPLATE's `.claude/settings.json`
and hooks, with `ROOT = factory/template`: the coordinator's write boundary, protected paths and
read-only roots do not apply, and writes to the rest of the coordinator are blocked as
"outside the repo root". Start sessions in the coordinator root (or a worktree of it) and
dispatch lanes from there; run the template's own tests with `cd factory/template && julia ...`
inside a Bash call, which does not change the session root. A denial from a template-rooted
session says so.

### First vendoring: writing T3 files

The seeded `risk.toml` makes `.agents/agent-registry.toml`, `.agents/factory.toml`,
`.agents/bodies/*`, `.agents/checks.toml`, `.claude/agents/*`, `.codex/agents/*`, `risk.toml`,
`ratchets.toml`, `.claude/settings.json`, `.claude/hooks/*`, `.github/workflows/*`,
`.factory-version` and the gate scripts (`scripts/dod.jl`, `ratchet.jl`, `gen.jl`,
`check_docs.jl`, `contract_usage.jl`, `ci.jl`, `_common.jl`) T3, and `write_guard.sh` blocks
Edit/Write to them.
A first vendoring writes them anyway because `sync_factory.jl --apply` runs as a Julia process
from Bash, which write_guard does not see; only the Edit/Write tools are blocked. To tailor
those files afterwards (a new repo's registry, the coordinator's read-only roots), either:

1. the user starts the session with `FACTORY_ALLOW_T3=1` in its environment for that
   bootstrap (an inline `FACTORY_ALLOW_T3=1 cmd` does not reach the hooks), then restarts
   without it; or
2. the user makes the edit, or explicitly authorises a lane to make it, and the PR carries an
   ADR (or cites one) as `dod.jl` requires for T3.

Either way the change lands through a reviewed PR labelled T3.

## Layout (paths inside `template/` are repo-root paths)

| Path | What | Owner |
|---|---|---|
| `CLAUDE.md` → `AGENTS.md` | short instructions; AGENTS.md generated | seeded → generated |
| `.agents/agent-registry.toml`, `.agents/bodies/*.md` | 12 roles: data + prose | seeded / managed |
| `.agents/factory.toml` → `.claude/hooks/read-only-roots.txt` | read-only roots, check_docs settings | seeded (per profile) → generated |
| `.claude/agents/*.md`, `.codex/agents/*.toml` | generated agent files | generated |
| `.agents/checks.toml` → `docs/CHECK_COVERAGE.md` | "prevented by X" + blind spots | managed → generated |
| `.claude/commands/*.md` | intake, lanes, change-review, contract-check, release-check, test-changed | managed |
| `.claude/skills/lane-lifecycle/` | dispatch / idle / close / roster rules | managed |
| `.claude/hooks/*.sh`, `.claude/settings.json` | bash_guard, write_guard, dispatch_limit, lane_ledger, teammate_idle, precompact, session_start, and the sourced `_lib.sh`, `_bash_guard_lib.sh`, `_read_only_roots.sh`; guards fail closed if their script or a library is missing | managed |
| `risk.toml` → `protected-paths.txt`, PR template | tiers T0–T3, protected paths | seeded → generated |
| `ratchets.toml` | coverage up, sizes and bench tolerance down | seeded |
| `scripts/*.jl`, `scripts/lane` | gen, dod, ratchet, check_docs, contract_usage, ci, bench, lane, sync_factory | managed |
| `test/contracts/USED.md`, `test/contracts/upstreams.toml` | contract IDs relied on; upstream URLs and contract-file copies | seeded (package) |
| `test/contracts/Project.toml`, `test/contracts/runtests.jl` | the contract tests' own environment and runner (`ci.jl contracts`) | seeded (package) |
| `test/jet/Project.toml`, `test/jet/runjet.jl` | JET's own environment (`ci.jl jet`, stable only) | seeded (package) |
| `scripts/test/` | tests for every script and hook | managed |
| `.github/workflows/*.yml` | CI, Docs, Contracts, Benchmark, Guards, CompatHelper, TagBot | managed |
| `docs/adr/0000-template.md` | copy of the coordinator's `adr/0000-template.md` (lands in the profile's `adr_dir`) | managed |
| `../profiles/<profile>/` | overlay files for a profile (outside `template/`): `coordinator`, `package` | per profile |

## Design choices

- **Hooks are POSIX sh + jq.** A hook runs on every tool call. Measured on this machine
  (2026-10-19): `julia --startup-file=no -e 'using TOML'` takes 0.12–0.16 s warm, `sh` + `jq`
  takes under 10 ms; `bash_guard.sh` takes about 60 ms per call in the test suite, which counts
  process spawning from Julia. jq ships with macOS (`/usr/bin/jq`) and GitHub's Ubuntu runners.
  Guards fail closed without jq, and `settings.json` runs each guard through
  `sh -c '... exit 2'` so a missing guard script blocks (exit 2) instead of failing open with
  exit 127; the wrapper works whether the hook shell is sh, bash, zsh or fish. Advisory hooks
  fail open. Hooks read `risk.toml` and the
  registry through small generated files (`protected-paths.txt`, `limits.env`), so the TOML
  files stay the single source.
- **Scripts are Julia, stdlib only** (TOML, SHA, Test), so they run before any environment is
  instantiated and need no Python.
- **One CI entry point:** every workflow step that runs Julia calls `julia scripts/ci.jl <job>`;
  `scripts/test/test_ci.jl` fails if a workflow calls an unknown job or runs other Julia code,
  or if a job is never called.
- **Unit tests are hermetic; repo-wide checks are `ci.jl guards` steps.** `scripts/test/` builds
  its own scratch repos, hook copies and roots files, so it passes in any profile. The
  template-only self-checks (no stale references in the template, the seeded `USED.md` lists
  nothing) and the sync tests run only in `factory/template`; a vendored repo checks its own
  docs and contract usage through `check_docs.jl` and `contract_usage.jl` in `ci.jl guards`.
- JET runs from its own env `test/jet/` in a stable-only `jet` job (JET 0.12 needs Julia >= 1.12, so it
  cannot sit in `test/Project.toml` for the LTS job); `:doctest`/`:snapshot` items are stable-only too.
  Contract tests run from their own env `test/contracts/` (the coordinator's `contracts/README.md`),
  so they resolve the upstream release (or upstream main) independently of `test/Project.toml`.
- **Tracked environments are never rewritten.** `ci.jl docs`, `jet` and `contracts` copy the
  env's `Project.toml` to a scratch directory, `Pkg.develop` the checkout (or upstream main) into
  the copy, and run there. Developing in place wrote an absolute `[sources]` path into the
  tracked file on Julia >= 1.11 (common.md §2 forbids committing one).
- **Hooks stay under the 150-line budget of the seeded `ratchets.toml`** by moving code into
  sourced libraries rather than by a per-file exception: a `.` source costs no fork, and a
  per-file rule would be a raised limit that the ratchet only lets fall afterwards.
- Julia versions and the formatter follow ADR-0006 (`lts`, `1`, `pre`) and ADR-0007 (Runic,
  TestItemRunner, Supposition). Both ADRs are Proposed; if they change, edit `CI.yml` and
  `scripts/ci.jl` (format job), then bump `VERSION`.

## Test it

```sh
cd factory/template
julia --startup-file=no scripts/gen.jl --check
julia --startup-file=no scripts/test/runtests.jl
julia --startup-file=no scripts/check_docs.jl --external docs/agent/ECOSYSTEM.md,docs/agent/BRIEF.md,.factory-version
(cd .claude/hooks && shellcheck -x -S warning *.sh)
uvx --from actionlint-py actionlint .github/workflows/*.yml
# the coordinator's doc references with the coordinator profile's defaults
julia --startup-file=no scripts/check_docs.jl --root ../.. --config ../profiles/coordinator/.agents/factory.toml
```
