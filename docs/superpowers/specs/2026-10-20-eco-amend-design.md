# Ecosystem amendments after the ChuiCore phase-1 ★ (eco-amend)

- **Date:** 2026-10-20. **Lane:** eco-amend (coordinator, branch `feat/eco-amend`).
- **Input:** the user's decisions at the ChuiCore phase-1 ★ (all recommendations accepted), and
  ChuiCore's ADR-0001 to 0008 (ChuiCore main 3054d7c, `ChuiCore.jl/docs/adr/`); later inputs: the
  ChuiTypes phase-1 ★ (ChuiTypes ADR-0004, 0006 on main 455c085) and ChuiCore's phase-2 clash probe.

## Goal

Bring the ecosystem ADRs in line with ChuiCore's accepted phase-1 ADRs. Record what changed as
dated amendments, without rewriting the original decisions. Prepare the contract text that the
user must apply under T3.

## Scope

| Change | File | Kind |
|---|---|---|
| (A) Supposition `record=false` + `@test`; planted violations on LTS; kit packaging (a) | `adr/0007-test-framework-and-formatter.md` | dated amendment section, pointers in Status and §2 |
| (B) Export tiers replace "ChuiCore exports `partial`"; `neutral(::Type{T})` is sugar; CompositionsBase confirmed | `adr/0009-shared-vocabulary.md` | dated amendment section; the Consequences line struck through, not deleted |
| (C) CC-001 arity rule, plus the proposed contract text for the settled PROVISIONAL items | `adr/0012-chui-added-opcompose-methods-are-binary.md` (new) | contract ADR, Proposed |
| (D) `chui-types.md` obligation 2 per ChuiTypes ADR-0006 (B1, B2, C3) | `adr/0013-chui-types-adapters-keep-the-exception-object-not-the-task.md` (new) | contract ADR, Proposed |
| (E) ChuiTypes → ChuiCore requests R1–R5 (ChuiTypes ADR-0004 §7) | `requests/chui-types-to-chui-core-*.md`, `requests/README.md` | five request files and an index |
| Index | `adr/README.md` | rows 0012 and 0013; amendment notes for 0007 and 0009 |
| Changelog | `changelog.d/eco-amend.md` | fragment |

Out of scope:
- `contracts/` and `prompts/` (T3: the text is in ADR-0012 and ADR-0013 for the user to apply).
- ChuiCore's own files (ADR-0005's export list is corrected by ChuiCore's phase 2).
- The factory test template (factory-maintainer).

## Design choices

- **Amend CC-001 in place.** ChuiCore 0.0.1 is unreleased, so the change table's retire-and-new-ID
  path protects no one; the alternative is ★ Q1 in ADR-0012.
- **New IDs only where ChuiCore marks an item as ready:**
  - CC-012 (ChuiCore ADR-0006 §5) and CC-013 (ChuiCore ADR-0005 §5) get IDs now.
  - The `isstateless` rule is an *obligation*, because its test needs the v1 transducer set from
    phase 3.
  - The other items stay PROVISIONAL with their decided parts recorded, because their ADRs say
    "after phase 2/3".
- **`neutral` is not exported.** ChuiCore's phase-2 clash probe found that TypeClasses exports
  it, and the lead approved making it public only. This reverses one L0 Consequences line, which
  goes to the user.
- **Obligation 2 stays an obligation.** It is restated (ADR-0013), not promoted, because the
  adapters are not built.
- **CC-012 and CC-013 are rule-only**, with no `names:` lines, so they do not make every `⨟` user
  list them.

## Verification plan

- `julia --startup-file=no scripts/check_docs.jl`, `scripts/check_claims.jl`,
  `scripts/dod.jl --base main`, `scripts/lane audit eco-amend`.
- The assembled `chui-core.md` is checked with `contracts/check.jl` in a scratch copy, together
  with the other contract files and the ADRs.
- A read-only critic reviews the diff before the report.
