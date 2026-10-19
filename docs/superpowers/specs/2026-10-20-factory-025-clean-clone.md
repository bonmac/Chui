# Spec: factory 0.2.5, checks that pass in a fresh clone

Status: Implemented (lane factory-025, awaiting the lead's merge) · Date: 2026-10-20 · Tier: T2

## Goal

`julia scripts/ci.jl guards` and `julia scripts/ci.jl format` must give the same result in a fresh
clone (as GitHub Actions sees it) as in a dev checkout, for every repo that takes the factory: the
coordinator and each package. A freshly synced repo must pass both with no local files present.

## The bugs, with the CI evidence

The first GitHub Actions runs (2026-10-19) failed where every local run passed. Three of the bugs
share one cause: gitignored, machine-local files (`.claude/hooks/read-only-roots.txt`, rendered by
`scripts/gen.jl`, and `.agents/factory.local.toml`) exist in a dev checkout and not in a clone.

1. **check_docs reported a gitignored path as stale.** In the coordinator (bonmac/Chui) and in a
   package: `HANDOFF.md:9: missing .claude/hooks/read-only-roots.txt` and similar lines in
   factory/CHANGELOG.md, factory/README.md and changelog.d → `check_docs.jl: 5 stale references`,
   `ci.jl guards: FAILED`. Reproduced in a clean clone of the coordinator at b9a3c3c.
2. **The gen.jl drift test depended on the host's roots file.** ChuiCore.jl CI:
   `test_gen.jl:91`, `Evaluated: !(first((true, "gen.jl --check: OK (30 files)\n")))`. In a clone
   `--check` skips the absent local output, so the expected drift was never seen. Reproduced in a
   clean clone of the pushed ChuiCore.jl: 1188 passed, 1 failed.
3. **The hook tests ran the real `.claude/hooks`.** The coordinator's `factory.toml` sets
   `require_read_only_roots = true`, so in a clone (no roots file) bash_guard fails closed on every
   command: 222 failures in the coordinator's own test run (60 in `hooks` on the 0.2.4 tree). CI
   never got that far because check_docs failed first. Found by the lane's fresh-clone simulation,
   not by CI.
4. **Runic.** The `Runic` job (`ci.jl format`, Runic --check, ADR-0007) failed in ChuiCore.jl and
   ChuiTypes.jl. Every diff was in factory-managed `scripts/*.jl` and `scripts/test/*.jl`
   (`gh run view 39329293823 -R bonmac/ChuiCore.jl --log-failed`: `diff --git a/_common.jl ...`).
   27 of the template's 30 Julia files were not Runic-formatted.

## Fixes

1. `scripts/check_docs.jl`: a reference that does not resolve passes when the path is untracked
   and a tracked `.gitignore` ignores it with a non-negated pattern (`git check-ignore -v`, as a
   file and as a directory, in each root the reference may resolve in). `.git/info/exclude` and a
   global excludes file differ per machine and do not count; a tracked file deleted in the work
   tree is still reported.
2. `scripts/test/test_gen.jl`: `gen_sandbox` drops the host's local files and renders the roots
   file from the committed config; the test asserts the drift is reported, and that an absent
   roots file is skipped (only `limits.env` may also drift in a coordinator).
3. `scripts/test/test_hooks.jl`, `test_bash_guard.jl`: tests run `TEST_HOOKS` by default, a copy
   with no roots and not required; the settings.json wiring test runs its command against a
   scratch project holding that copy. Tests that need roots build their own (`hooks_with_roots`).
4. Every template Julia file is formatted with Runic v1.13.0 (the version CI installs). No file is
   excluded and the check is not narrowed. Formatting grew `test_hooks.jl` past the 400-line
   `scripts/*.jl` ratchet (which may only fall), so its lane-lifecycle and settings.json testsets
   moved verbatim to a new managed file, `factory/template/scripts/test/test_hooks_lifecycle.jl`, first; `checks.toml` points those
   hooks at it.

## New check_docs blind spot

Recorded in `.agents/checks.toml` → `docs/CHECK_COVERAGE.md`: a reference to an untracked path that
a tracked `.gitignore` ignores passes whether or not it exists, so a typo that still matches an
ignore pattern is not caught (a glob such as `*.parquet`, or an unanchored directory pattern such
as `dev/`, which matches at any depth). Outside a git checkout nothing counts as ignored.

## Verification

- Each new test was first run against the 0.2.4 tree and failed there: check_docs (2 failed,
  1 errored); the gen test (the CI failure above, in a fresh clone); the hook tests (60 failures in
  `hooks` in a fresh coordinator clone).
- Template tests (`cd factory/template && julia scripts/test/runtests.jl`): 1356/1356 on Julia
  1.13.2 and on 1.10.12 (1346 in 0.2.4). `gen.jl --check`, `ratchet.jl` OK; Runic `--check` on the
  template exits 0.
- Fresh-clone simulation (no local files, no FACTORY_* vars), each synced to 0.2.5, committed and
  cloned afresh:

  | Repo | `ci.jl guards` | `ci.jl format` |
  |---|---|---|
  | scratch coordinator (this branch) | OK (template tests 1149/1149) | FAILED, coordinator-owned files only (`contracts/*.jl`, `reference/prototype/**`); the coordinator has no CI format job |
  | scratch copy of the pushed ChuiCore.jl | OK (1199/1199) | OK |
  | package bootstrapped into an empty repo | OK (1199/1199) | OK |

- Open for the lead: Runic-format or exclude the coordinator's own `contracts/` (T3) and
  `reference/prototype/` Julia files if the coordinator ever runs `ci.jl format`.
- Not covered: real CI runs (they need a push), the real syncs (separate lanes per repo).
