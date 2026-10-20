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
| [chui-frames-to-chui-core-recursion-schemes.md](chui-frames-to-chui-core-recursion-schemes.md) | R6: `cata`/`ana`/`para` and `Fix` over a user plan functor | open (partly answered by ChuiCore ADR-0001 §3, ADR-0005 §3) |
| [chui-frames-to-chui-core-transducer-substrate.md](chui-frames-to-chui-core-transducer-substrate.md) | R7: release `isstateless`, `foldxl`, `foldparts`, `foldxt`, `aggregate` | open (partly answered by ChuiCore ADR-0003 §4–7; overlaps R3) |
| [chui-frames-to-chui-core-missing-aggregators.md](chui-frames-to-chui-core-missing-aggregators.md) | R8: who owns `missing`-aware aggregators | rejected 2026-10-20 (answered: option A, ChuiFrames owns them; user) |
| [chui-frames-to-chui-core-conflict-banner.md](chui-frames-to-chui-core-conflict-banner.md) | R9: the name-conflict banner utility | open (partly answered by ecosystem ADR-0002, ChuiCore ADR-0005 §1) |
| [chui-frames-to-chui-types-effects-and-streams.md](chui-frames-to-chui-types-effects-and-streams.md) | R10: effect run/cancel, Task/Channel conversions, stream API for a bounded Source | accepted 2026-10-20 (built on ChuiTypes main 6ee5fac under ADR-0008, unreleased; reproducer corrected; CT IDs are R11; stays open while ChuiFrames' Task shim exists) |
| [chui-types-to-coordinator-export-tiers-and-ct-ids.md](chui-types-to-coordinator-export-tiers-and-ct-ids.md) | R11: CT-004 to CT-007 for the runtime and stream names R10 needs; the "Stream as a ChuiFrames Source" amendment (T3) | open |
| [chui-types-to-factory-dod-export-lines.md](chui-types-to-factory-dod-export-lines.md) | R12: dod.jl tiers an export-line-only public-API change as T1 | open |
| [chui-types-to-chui-frames-stream-source-snapshot.md](chui-types-to-chui-frames-stream-source-snapshot.md) | R13: the stream Source snapshots once at construction, bounded and under `timeoutfail` | open |
| [chui-frames-to-coordinator-contract-p3.md](chui-frames-to-coordinator-contract-p3.md) | R14: `chui-frames.md` after phases 2c–3: `drop` and frame equality, CF-004 `var`/`std` → `missing`, CF-018 lazy entry points, CF-008 eager replay (T3) | open |
| [coordinator-to-chui-frames-optimize-replay.md](coordinator-to-chui-frames-optimize-replay.md) | R15: `collect(optimize(q))` replays the optimized plan and can raise a different exception from eager | open |
| [coordinator-to-chui-types-snapshot-and-interrupt-docs.md](coordinator-to-chui-types-snapshot-and-interrupt-docs.md) | R16: the docstrings and ADR-0008 overstate `interrupt!`, `maxelements` and `timeoutfail` | open |
