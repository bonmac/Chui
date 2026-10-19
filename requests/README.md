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

No requests yet.
