- **Changed:**
  - ADR-0007 §2 amended (2026-10-20, ChuiCore phase-1 ★):
    - Supposition properties use `@check record=false db=false` plus an explicit `@test`. A failing
      `@check` is not recorded on Julia 1.10, and a SuppositionDB written by 1.13 crashes 1.10.
    - No package commits a `SuppositionDB`.
    - Every law kit has planted-violation tests on the LTS job.
    - ChuiCore's law kits take option (a): stubs plus two extensions.
  - ADR-0009 amended (2026-10-20):
    - ChuiCore's names are tiered exported / public / internal, and exports are exactly the names
      that pass the clash-list test.
    - `partial` is public, not exported.
    - `neutral` (with `curry`, `pure`, `ap`, `fmap`) is public, not exported, per ChuiCore's
      phase-2 clash probe.
    - `neutral(::Type{T})` becomes closed sugar over `neutral(m)`.
    - CompositionsBase is confirmed as the `⨟` binding.
- **Added:**
  - ADR-0012 (Proposed): the CC-001 arity amendment.
    - Chui-added `⨟` methods take two arguments; CompositionsBase's fallback and a downstream
      closing varargs method may be variadic.
    - It carries the exact `chui-core.md` text for the user to apply under T3: CC-001 edits; new
      CC-012 (CompositionsBase binding) and CC-013 (export tiers); the `isstateless`
      per-partition obligation; and rewritten PROVISIONAL items.
  - ADR-0013 (Proposed): the `chui-types.md` obligation 2 amendment, from ChuiTypes ADR-0006.
    - A `Fiber`'s `fetch` throws the original exception; `totask`'s Base `fetch` wraps it.
    - Cancelling `fromtask` runs its canceller, or abandons and counts the task.
    - The error channel is the `Cause`, and `Die` comes back as `Fail` across Tasks.
    - Exact T3 text included.
  - Requests R1–R5 from ChuiTypes to ChuiCore (ChuiTypes ADR-0004 §7) filed in `requests/`, with an
    index in `requests/README.md`.
