# Factory changelog

Versions of the development-process template. Repos record the version they vendor in
`.factory-version`; `scripts/sync_factory.jl` shows the diff before taking a new one.
A breaking change (a renamed file, a new required field, a stricter guard) bumps the minor
version while below 1.0.

## 0.2.1 (2026-10-19)

Fixes found running the 0.2.0 tests in the coordinator checkout (540 passed, 2 failed,
2 errored, 1 broken there; 665/665 in `factory/template`), plus the first review of the 0.2.0
contract-usage check (S6). No hook, `settings.json` or workflow changes: the only T3 file a
0.2.0 → 0.2.1 sync writes is the sync record `.factory-version` (every sync does).

- **Tests are hermetic across profiles.** The "package profile seeds no roots" hook test uses its
  own empty roots file instead of the checkout's generated `read-only-roots.txt` (the
  coordinator's lists reference-project-b). The repo-wide `check_docs.jl` run and the template's
  `test/contracts/` checks (seeded `USED.md` lists nothing, `upstreams.toml` has
  `[contract_files]`) run only in `factory/template`; a vendored repo already runs both
  scripts on itself in `ci.jl guards`, under its own settings.
- The sync tests no longer report a `@test_skip` ("Broken") in a vendored repo: not running
  there is by design (they test the factory's own copy, which the vendored one matches by hash),
  so an `@info` line says so.
- `check_docs.jl`: in a checkout holding the factory (`factory/MANIFEST.toml`), the backticked
  paths of `factory/*.md` also resolve against `factory/template/` (they name template paths
  such as the template's ADR directory). Removes 4 stale references in the coordinator without
  excluding the factory docs. New blind spot recorded in `.agents/checks.toml`.
- `sync_factory.jl`: a file recorded as managed that the factory now seeds is reported as
  `now-seeded` (it leaves the managed record) instead of `removed-upstream`. Like any seeded
  file it is not updated afterwards, even if the repo never edited it; its `seeded-differs`
  diff shows what the factory's version would change.
- `test_ci.jl`: a checkout without `.factory-version` takes its profile from its shape
  (`factory/MANIFEST.toml` present → coordinator) instead of always `package`.
- **`contract_usage.jl` (review of 0.2.0's S6; each was a false pass):** upstreams named only in
  `[contract_files]` (no URL yet) are grepped too; a commented-out `@testitem` (`#` or
  `#= =#`) is not a test; an ID-named test item without `tags = [:contract]` is an error
  (`ci.jl contracts` runs only those). Also: `Up.:(⨟)` and `using Up: (⨟)` are recognised;
  `#= =#` blocks in code are skipped; `status=stable-ish` is invalid; a fence closes only on its
  own character; a `# ` heading ends an entry; an ID with two entries is an error.
- `check_docs.jl`'s second root applies to backticked paths only, not to Markdown links.
- `/contract-check` names `--contracts`, the upstreams grepped, and a fix for every error the
  script reports; new blind spots (module aliases, docstring mentions, tags on a later line).
  The `contract_steward` body mentions `USED.md` and `contract_usage.jl`, and drafts request
  text instead of writing to the coordinator's `requests/`.

Coordinator follow-ups outside the factory (repo-owned): `.agents/bodies/coord_architect.md`
and `adr/README.md` named the package ADR directory as a repo path; reworded and regenerated.

## 0.2.0 (2026-10-19)

Fixes found while vendoring the coordinator profile.

- **Read-only roots (stricter guard).** `bash_guard.sh` denies any command that would RUN in a
  directory listed in `.agents/factory.toml [bash_guard] read_only_roots`, except cat, head,
  tail, less, grep, rg, find (no -exec/-delete), ls, wc, stat, file, cd/pwd and git
  log/show/diff/status/blame/ls-files. The run directory is the payload cwd, a tracked
  `cd`/`pushd`, `git -C`, `make -C/--directory`, `uv --directory/--project`, or
  `julia --project=`. Catches the 2026-10-19 incident
  (`cd ~/reference-project-b && uv run ...`). The package profile seeds no roots; the
  coordinator seeds reference-project-a, reference-project-b and reference-project-c.
- Review fixes (in the same release): `2>&1`/`>&2`/`&>` are no longer split as command
  separators; `git -c a=b -C dir ...` and `git --no-pager -C dir ...` are seen by both the
  read-only and the outside-root checks, and the denylist sees through git global options
  (`git -c x=y reset --hard` is blocked); `cd -P/-L dir`, `env -C dir` / `env --chdir=dir` are
  followed; read-only roots match case-insensitively (APFS); an indented closing fence closes in
  check_docs; `.agents/factory.toml` value types are validated; `dod.jl --adr-dir` works even
  with an unreadable `.factory-version`; sync repairs a mode-only difference.
- `cd` is now tracked across segments for the outside-the-root write check too
  (`cd /outside && touch f` is blocked), and `git -C dir --no-pager log` is recognised as
  read-only. `normpath` in `_lib.sh` no longer turns globbing back on inside the guard.
- **Guards fail closed** when their script is missing: `settings.json` wraps bash_guard,
  write_guard and dispatch_limit in `sh -c '...'` that exits 2 with a message.
- New seeded, T3-protected `.agents/factory.toml` (per-profile defaults) and generated
  `.claude/hooks/read-only-roots.txt`.
- `check_docs.jl` reads `[check_docs]` from `.agents/factory.toml`: `exclude` globs,
  `external` globs of references allowed to be missing, `ignore_fenced`; plus `--config FILE`.
  The coordinator defaults exclude `research/**`, `reference/**`, `prompts/**`, numbered ADRs
  (`adr/0*`) and `factory/template/**`, allow package paths (`docs/agent/*`, `test/*`, `src/*`,
  `ext/*`, `benchmark/*`) and `.claude/worktrees/*`, and ignore fenced blocks (172 stale
  references on the coordinator before, 0 after).
- MANIFEST profiles gain `overlay` and `adr_dir`. The coordinator profile uses
  `profiles/coordinator/` and `adr_dir = "adr"`, and no longer takes `docs/adr/*` (its `adr/`
  is their source). `.factory-version` records `adr_dir`; `dod.jl` checks ADRs there
  (`--adr-dir` overrides).
- `scripts/test/test_ci.jl` is profile-aware: the template and package profile still require
  every ci.jl job to be called; a coordinator checkout requires the workflows it was given to
  exist and call ci.jl, and `guards` to be called.
- **Contract usage by ID (S6), in the format of contracts/README.md.** New
  `scripts/contract_usage.jl [--contracts DIR] [--strict]`, run by `ci.jl guards`; seeded
  `test/contracts/USED.md` (`- <ID> [— note]` lines; package profile); `upstreams.toml` gains
  `[contract_files]` (vendored copies of the upstream contract files, so a fresh clone checks
  itself). Errors: a listed ID without exactly one `@testitem "<ID> ..."`, a contract test item
  for an unlisted ID, `@test_skip`/`@test_broken` in a contract test, an ID missing from the
  contract files or `status=retired`, a used upstream name whose `names:` line maps to an
  unlisted ID, a used upstream without a contract file. Warnings: `status=deprecated`, a used
  name no stable/deprecated `names:` line covers (an error with `--strict`). `/contract-check`
  refreshes the contract files and runs it with `--strict`. Skipped without USED.md (coordinator).
- Denials from a session rooted in `factory/template` say that the template's hooks apply.
  README: profiles, "start sessions and dispatch lanes from the repo root", and how a first
  vendoring writes T3 files.

Migrating from 0.1.0: the sync seeds `.agents/factory.toml`. Seeded files are never updated,
so an existing `risk.toml` does not gain the new T3 glob `.agents/factory.toml`; add it by hand
(T3 edit). In the coordinator, the 0.1.0 copies under `docs/adr/` are reported as
removed-upstream and are not deleted; remove them by hand.

## 0.1.0 (2026-10-19)

- First version, built in Phase L0 from the study in `research/reference-projects.md`.
- Agent registry with 12 roles, prose bodies, `scripts/gen.jl` (`--check`) generating
  Claude and Codex agent files, `AGENTS.md`, the PR template, protected paths, lane limits and
  `docs/CHECK_COVERAGE.md`.
- Hooks (POSIX sh + jq): bash_guard, write_guard, dispatch_limit, lane_ledger,
  teammate_idle, precompact, session_start; wiring in `.claude/settings.json`.
- Commands: intake, lanes, change-review, contract-check, release-check, test-changed; skill
  lane-lifecycle.
- Scripts: lane (worktrees at `<repo>/.worktrees/<lane>`), dod, ratchet, check_docs, ci, bench,
  sync_factory; tests for every script and hook in `scripts/test/`.
- Workflows: CI (lts/stable/pre matrix, coverage, quality, Runic), Docs, Contracts
  (release blocks, main warns), Benchmark, Guards (generated files, ratchets, doc references,
  factory tests, definition of done), CompatHelper, TagBot.
- JET in its own `test/jet/` environment (stable only); doctest/snapshot items stable only.
