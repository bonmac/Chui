# cl-headings: dod rejects changelog fragments that the fold would refuse

Date: 2026-10-27. Tier T2 (factory/template). Lane `cl-headings`, branch `feat/cl-headings`.

## Problem

`scripts/changelog.jl fold` refuses any fragment containing a Markdown heading line (it would
split the `## Unreleased` section). Fragments must be list items only. But the `changelog`
requirement of `scripts/dod.jl` accepted any non-empty *added* `changelog.d/<name>.md`, so a lane
could pass dod with a fragment that the release fold later rejects. ChuiFrames had 14 such
fragments and the coordinator 5, all found only at fold time.

## Rule

- dod applies the same heading rule as changelog.jl: a line matching `^\s{0,3}#{1,6}(\s|$)`.
- An added fragment (its content at `head`) holding such a line fails `changelog` with a
  message naming `julia scripts/changelog.jl fold` and saying to write list items only.
- This check comes before the `CHANGELOG.md changed` pass: the fold breaks either way.
- The regex is duplicated, as `DoD.FRAGMENT_HEADING`, not reused. In changelog.jl it is inline in
  `problems`, which reads the working tree, not `head`, and including changelog.jl only for it
  would add a module for one line. A comment in dod.jl says so.
- `test_dod.jl` guards the duplication: an identity test that the dod pattern occurs verbatim in
  changelog.jl, plus match and non-match cases (`# A`, `   ## x`, `##` vs `- # x`, `    # code`,
  `#tag`).

## Where it ships

With factory 0.3.0. No `factory/VERSION` bump in this lane; package repos get the check in
their own 0.3.0 sync lanes. The coordinator's synced `scripts/dod.jl` is not changed here.

## Coordinator fragments

`changelog.d/{eco-amend,adr-0011-amend,frames-reqs,requests-p4p3,sync-027}.md` are rewritten as
list items only. Each `### X` heading becomes a top-level `- **X:**` bullet with its items nested
under it, and every fact is kept verbatim. Verified with `changelog.jl fold --dry-run`.

## Tests

Test-first: first a red CLI test on a scratch repo (a `### Added` fragment, then with
`CHANGELOG.md` also changed, then fixed to list items: passes), then the dod.jl change. `julia` and `julia +lts`.
