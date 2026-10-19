# Cross-repo requests

A downstream lane that needs something from an upstream package writes one file here and keeps
working behind an internal adapter. It never edits the upstream repo. The rules are in
[ADR-0010](../adr/0010-cross-repo-workflow.md) ("Request flow"); the lead triages this folder at
least once per phase, and open requests appear in every phase report.

## File name

`<from>-to-<to>-<slug>.md`, with package names in lower case, e.g.
`chui-frames-to-chui-core-monoid-merge.md`.

## Format

```markdown
# <one-line need>

- **From → to:** chui-frames → chui-core
- **Status:** open            <!-- open | accepted | released in vX.Y.Z | adopted | rejected -->
- **Urgency:** blocking | soon | later
- **Contract IDs affected:** CC-012 (or "new"; or "PROVISIONAL")
- **Adapter used meanwhile:** module/file in the downstream repo
- **Reproducer:** a command that shows the need (RED before the upstream change, GREEN after); closing the request quotes both runs

## Problem
What the downstream package needs to do, and why the current upstream API does not allow it.

## Proposed API
Signature(s) and semantics; laws if any.

## History
- YYYY-MM-DD open: written by <lane>
```

## Lifecycle

| Status | Set by | Meaning |
|---|---|---|
| `open` | the downstream lane | written; the downstream lane continues behind its adapter |
| `accepted` | the lead (triage) | an upstream lane will implement it; the contract update is planned (an ADR if breaking) |
| `released in vX.Y.Z` | the release-manager | upstream released it (the user confirmed); recorded in [releases.md](../releases.md) |
| `adopted` | the downstream lane | downstream upgraded on its own branch and removed the shim |
| `rejected` | the lead | closed, with the reason in History |

Every status change adds a dated History line. Files are never deleted; history lives in git.

## Open requests

| File | Need | Status |
|---|---|---|
| [chui-types-to-chui-core-typeclass-names.md](chui-types-to-chui-core-typeclass-names.md) | R1: typeclass operation names and encoding | open (partly answered by ChuiCore ADR-0001) |
| [chui-types-to-chui-core-law-kits.md](chui-types-to-chui-core-law-kits.md) | R2: law-kit form, Supposition 1.10 workaround | open (partly covered by ADR-0007 §2 amendment) |
| [chui-types-to-chui-core-transducer-fold.md](chui-types-to-chui-core-transducer-fold.md) | R3: transducer names, type-stable chunk fold | open |
| [chui-types-to-chui-core-first-snapshot.md](chui-types-to-chui-core-first-snapshot.md) | R4: first registered `0.0.x` snapshot | open (needs the user) |
| [chui-types-to-chui-core-memoised-thunks.md](chui-types-to-chui-core-memoised-thunks.md) | R5: memoised thunks | open |
