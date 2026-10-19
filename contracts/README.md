# Chui contracts

> **Binding since 2026-10-19.** ADR-0002, ADR-0004, ADR-0007, ADR-0009 and ADR-0010 were
> Accepted at the L0 checkpoint, so the DRAFT banners are gone and every stable entry here changes
> only through the table in "How a contract changes". `check.jl` fails if a contract file carries
> a DRAFT banner while those ADRs are all Accepted, or lacks one while any of them is not.

A contract is the API a Chui package promises to the packages downstream of it. Each file here is
owned by one package; downstream repos test exactly the entries they use. The format and the
workflow come from [ADR-0010](../adr/0010-cross-repo-workflow.md); versioning comes from
[ADR-0004](../adr/0004-versioning-and-compatibility.md).

## Contracts

| File | Prefix | Owner | Consumers | Contract version | Package version it describes |
|---|---|---|---|---|---|
| [`chui-core.md`](chui-core.md) | `CC-` | ChuiCore | ChuiTypes, ChuiFrames (and every future package) | v0 | ChuiCore 0.0.1 (unreleased) |
| [`chui-types.md`](chui-types.md) | `CT-` | ChuiTypes | ChuiFrames (and future packages) | v0 | ChuiTypes 0.0.1 (unreleased) |
| [`chui-frames.md`](chui-frames.md) | `CF-` | ChuiFrames | ChuiStats, ChuiLearn, ChuiSpatial, ChuiPlot (none exist yet) | v0 | ChuiFrames 0.0.1 (unreleased) |

"Contract version v0" means the first edition, written at L0 before the packages' own phase-1
ADRs. It lists only what the ecosystem ADRs already decide; everything else is under
`## PROVISIONAL`.

## Drafts

The draft period ended at the L0 checkpoint (2026-10-19). While the DRAFT banner stood, entries
could change without a contract ADR, because no downstream relied on them. IDs were still
**never reused**: an entry withdrawn during the draft stays in its file as a short stub with
`status=retired` and a "Withdrawn before the contract became binding" line naming where its
content went (CC-003, CC-008, CC-009, CT-001, CT-002 at the critic review of 2026-10-19). The
user decided at L0 that these stubs stay. From now on only the change table below applies.

## Entry format (ADR-0010)

- **IDs:** `CC-` (chui-core), `CT-` (chui-types), `CF-` (chui-frames), then three digits. IDs are
  assigned in order and **never reused**. A retired entry stays in its file with
  `status=retired`.
- **Header:** every entry starts with a line matching

  ```
  ^### (C[CTF]-\d{3}) (.+)$
  ```

  followed **immediately** by a line of the form

  ```
  `since=<version> status=<stable|deprecated|retired>`
  ```

  `since` is the owning package's version that first ships the entry (`0.0.1` for v0).
- **Body** of a stable entry, in this order:
  - **Statement:** the signature and semantics, precisely;
  - **Laws** (where there are any);
  - **`names:`** (where the entry promises named API): one line listing the qualified names it
    covers, e.g. ``names: `ChuiCore.init`, `ChuiCore.partial` ``. `contract-check` uses these
    lines to map a downstream's qualified uses to entry IDs (below). Rule-only entries have none.
  - **Example:** a minimal Julia snippet;
  - **`test:`** a line naming the contract test item downstream repos write, and what it checks.
- **PROVISIONAL:** undecided items go in a `## PROVISIONAL` section, as plain bullets or
  `####` sub-headings, **without IDs**. They have no contract tests. An item moves out of
  PROVISIONAL, and gets the next free ID, only when the owning package's ADR accepts it.
- **Obligations (not entries):** ecosystem rules that bind design now but cannot be tested until
  PROVISIONAL names exist (chui-types' effect-runtime rules). No IDs, no tests, no placeholder
  test items; each becomes an entry when its names are accepted.

## Julia code blocks

`check.jl` parses every ```` ```julia ```` block in these files on the running Julia. A block
whose preceding line contains `(Base only)` uses only Base and the standard libraries; `check.jl`
also **executes** it, and it must carry at least one expectation comment `# -> <value>`: the
value of the top-level expression on that line (or the expression the comment ends) must print,
with `repr`, exactly as `<value>`. A missing expectation or a mismatch is an error. Run it on both
supported Julia versions (ADR-0006):

```sh
julia --startup-file=no contracts/check.jl contracts
julia +lts --startup-file=no contracts/check.jl contracts
julia --startup-file=no contracts/test_check.jl        # negative tests for check.jl itself
```

## How downstream repos mirror contracts

- **One test item per ID used.** A downstream repo's `test/contracts/` contains one
  `@testitem` tagged `:contract` per contract ID it relies on, named after the ID, e.g.

  ```julia
  @testitem "CC-001 ⨟ composes left to right" tags = [:contract] begin
      using ChuiCore
      @test (sin ⨟ cos)(1.0) == cos(sin(1.0))
  end
  ```

- **`test/contracts/USED.md` is the one usage-tracking mechanism** (ADR-0010 rule 1). It lists
  every contract ID the repo relies on, one per line as `- CC-004` (an optional ` — note` may
  follow). The factory's `contract-check` cross-checks three sources and fails on any mismatch:
  1. **USED.md ↔ test items:** every listed ID has exactly one `@testitem` whose name starts
     with `"<ID> "` in `test/contracts/`, and every such test item's ID is listed;
  2. **USED.md ↔ contracts:** every listed ID exists in the upstream contract file and is
     `stable` or `deprecated` (a `retired` ID is an error; a `deprecated` one a warning);
  3. **code ↔ USED.md:** qualified upstream names grepped from the repo's `src/` and `ext/`
     (`ChuiCore.partial`, `ChuiCore.:⨟`, and names brought in by `using/import ChuiCore: …`) are
     mapped to IDs through the contracts' `names:` lines; each mapped ID must be listed in
     USED.md, and a used name that no stable entry's `names:` line covers is reported as reliance
     on PROVISIONAL or unpromised API (a warning, or an error under `--strict`).

  PROVISIONAL items are never tested. Rule-only entries (no `names:` line, e.g. CC-010) are
  listed by hand when the repo relies on them.
- **Tests that need PROVISIONAL names.** A stable entry's rules may be stated with names that are
  still PROVISIONAL (chui-frames' verbs, `lazy`/`collect`). Its contract test uses the names
  **exported by the upstream release under test**; when an accepted ADR renames them, that is a
  contract change, and the downstream rewrites the test items in the release that adopts the
  rename (the warning-only run against upstream `main` shows the break first). No placeholder or
  `@test_skip` items: an ID is either tested for real or not listed in USED.md.
- **Its own environment.** `test/contracts/Project.toml` is separate from `test/Project.toml`.
  It depends on the upstream packages under test, `Test`, `TestItems`/`TestItemRunner`, and
  nothing from the downstream package's own test environment. CI runs it twice per upstream
  (ADR-0004 rule 5):
  1. against the **latest registered release** of the upstream: **blocking**;
  2. against **upstream `main`** (`Pkg.develop` of the git URL, in CI only): **warning only**.
- **Pinned to what was tested.** In the 0.0.x range every release is breaking for Pkg, so the
  downstream `[compat]` names the exact upstream snapshots its contract tests passed against
  (ADR-0004 rule 1).

## How a contract changes

| Change | What has to happen |
|---|---|
| A PROVISIONAL item is decided | The owning package's ADR accepts it; the lead (contract-steward) gives it the next free ID with `since=<next version>` and writes its `test:` line. No downstream change is needed until a downstream starts using it. |
| A new, compatible stable entry | Added with the next free ID and `since=<the release that ships it>`. |
| A breaking change to a stable entry | 1. A **contract ADR** in the root repo naming the entry, the change, the migration and the affected downstreams. 2. Where feasible (from 0.1 on), a **deprecation** release first: the entry becomes `status=deprecated` and the old API keeps working through `Base.@deprecate`/`Base.depwarn` for one minor cycle. 3. The **breaking release**: the minor bump below 1.0, the major bump from 1.0 (ADR-0004 rule 1), with a `CHANGELOG.md` entry. The old entry becomes `status=retired`; the new behaviour gets a **new ID**. 4. `releases.md` and `compat-matrix.md` are updated; each downstream adopts it on its own branch. |
| A downstream needs something new | A request in `requests/<from>-to-<to>-<slug>.md` (ADR-0010 rule 3). The downstream keeps working behind its internal adapter until the upstream release lands. |

Rules that always hold: no commit spans repos; upstream releases first; once binding, contract
files change only through an ADR (ADR-0010).
