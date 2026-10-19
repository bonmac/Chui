# ADR-0010: Cross-repo workflow

- **Status:** Proposed
- **Date:** 2026-10-19
- **Deciders:** the user, at the L0 ★ checkpoint
- **Scope:** ecosystem (the coordinator repo and every package repo)

## Context

Packages are separate git repos with separate versions (ADR-0002, ADR-0004), and lanes for one
package never edit another (`common.md` §2, §5). The coordinator needs a small, file-based
protocol for three things: asking upstream for features, stating what each package promises, and
checking that released versions work together. The version-0 contracts (L0 step 4) are written
*before* ChuiCore's phase-1 ADRs decide most of its API.

## Decision

| Path | Content | Written by |
|---|---|---|
| `contracts/chui-core.md`, `chui-types.md`, `chui-frames.md` | The API a package promises downstream (format below). | lead / contract-steward; changes need an ADR |
| `requests/<from>-to-<to>-<slug>.md` | A downstream need: the problem, proposed API, urgency, affected contract IDs, the adapter used meanwhile, and its status (`open → accepted → released in vX → adopted`, or `rejected` with a reason). | downstream lane; triaged by the lead each phase |
| `releases.md` | Append-only: date, package, version, registry, commit, contract version, notes. | release-manager |
| `compat-matrix.md` | Which released versions were tested together, with pass/fail and the date of the `integration/` run. | lead |
| `integration/` | An environment that `add`s the **latest registered** versions (never `develop`), plus end-to-end scripts. The resolved `Manifest.toml` is kept per run as evidence. | lead / integration lane |

**Contract file format:**
- **ID prefixes:** `CC-` (chui-core), `CT-` (chui-types), `CF-` (chui-frames); three digits;
  never reused. Retired IDs stay in the file, marked `retired`.
- **Each entry starts with a parseable header line**, matched by
  `^### (C[CTF]-\d{3}) (.+)$`, followed immediately by
  `` `since=<version> status=<stable|deprecated|retired>` ``. Then come the signature, semantics,
  laws and the contract-test name.
- **Version 0 lists only items already decided** by an Accepted ADR: e.g. `⨟` (ADR-0009 §1),
  the Tables.jl guarantee (§3), the Aggregator protocol and `iscommutative` (§5). Until those
  ADRs are Accepted, every contract file carries a **DRAFT banner** ("binding when ADR-0002/0004/
  0007/0009/0010 are Accepted at the L0 ★"), and `contracts/check.jl` enforces it. During the
  draft, entries may change without a contract ADR; a withdrawn entry stays as a `retired` stub
  and its ID is not reused. *Amended 2026-10-19 (critic B1).*
- **Entries that promise named API** carry a `names:` line of qualified names
  (`ChuiCore.partial`), used by `contract-check` to map a downstream's uses to IDs.
- **Everything else** goes in a `## PROVISIONAL` section **without stable IDs**. An item gets an ID
  when the owning package's ADR accepts it.

**Rules:**
1. **Contract tests mirror contracts.** Each downstream repo's `test/contracts/` has one
   `:contract` test item per contract ID it uses. PROVISIONAL items have no contract tests, and
   there are no placeholder (`@test_skip`) items. **Usage is tracked one way only:**
   `test/contracts/USED.md` lists the IDs the repo relies on, and `contract-check` cross-checks it
   against (a) the `@testitem "C?-NNN …"` names in `test/contracts/` (one per listed ID, none
   unlisted), (b) the upstream contract files (each ID exists and is not `retired`), and (c) the
   qualified upstream names grepped from `src/` and `ext/`, mapped to IDs through the contracts'
   `names:` lines (each mapped ID must be listed; an unmapped name is reliance on PROVISIONAL API).
   Details in `contracts/README.md`. *Amended 2026-10-19 (critic S6).*
2. **Their own environment.** The contract jobs resolve upstream in `test/contracts/Project.toml`,
   separate from the package's test environment: once against the latest release (blocking), once
   against upstream `main` (warning), following ADR-0004 rules 4–5.
3. **Request flow:**
   1. downstream writes the request and continues behind its internal adapter module;
   2. the lead triages it;
   3. an upstream lane implements it, and the contract is updated (with an ADR if breaking);
   4. upstream releases (the user confirms) and records it in `releases.md`;
   5. downstream adopts it on its own branch, removes the shim, and marks the request `adopted`.
4. **No commit spans repos.** A two-package change is two commits, upstream first and released.
5. **`integration/` runs every phase** and after each release. A failure blocks the next downstream
   release, unless `compat-matrix.md` records it as a known incompatibility with an open request.
6. **Input to `chui-frames`' first Source entry** (from ADR-0009 §7): names distinct from Tables.jl's
   `schema`/`partitions`, or consistent extensions of them; and a choice between a bounded-only v0
   and a streaming variant. Until ChuiFrames' Source ADR decides, `Source` stays PROVISIONAL.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| GitHub issues for requests | Needs remotes and posting (user confirmation each time). Files work offline and are reviewable; they can be mirrored to issues later. |
| Contracts as Julia code only (an interface package) | Adds a package to the graph. Prose, IDs and contract tests give the same guarantee. |
| Stable IDs for undecided v0 items | Freezes guesses: IDs are permanent, so an undecided item would leave a retired ID behind. |
| Contract tests in the package's own test environment | Swapping the upstream between release and `main` would disturb the package's resolved test env. |
| Git submodules for package repos | Couples coordinator commits to package SHAs. |

## Consequences

- The factory needs a `contract-check` command that parses the header regex and `names:` lines and
  performs rule 1's three cross-checks against `test/contracts/USED.md`.
- The lead carries the triage load each phase; open requests appear in every phase report.

## Verification

- A design decision derived from `prompts/common.md` §2/§5 and `prompts/00-lead.md`.
- E-31 supports the separate-environment and `main`-version rules (via ADR-0004).

## Revisit when

- More than about 10 requests are open at once (consider GitHub issues or projects).
- A future package joins: add its contract file (a new prefix through an ADR) and a matrix column.
