# The name-conflict banner utility: `binding_conflicts` and `conflict_banner` (R9)

- **From → to:** chui-frames → chui-core
- **Status:** open            <!-- partly answered by ecosystem ADR-0002 and ChuiCore ADR-0005 §1; see History -->
- **Urgency:** later (ChuiFrames phase 2 ships its verbs; until the banner is released, a coexistence docs page is the only notice)
- **Contract IDs affected:** PROVISIONAL ("Name-conflict banner" in `chui-core.md`). CC-009, the draft entry for the banner, is `retired` and is never reused: the banner gets the next free CC ID when ChuiCore accepts its API.
- **Adapter used meanwhile:** none in code. ChuiFrames' coexistence docs page (ChuiFrames ADR-0002 rule 6) lists the accepted collisions; ChuiFrames calls no banner from `__init__` until the utility is released (CF-009's last bullet).
- **Reproducer:** with the ChuiCore snapshot under test (names from `chui-core.md`'s recommended shape; replace with the final ones): `julia --startup-file=no -e 'using ChuiCore, Test; module A; export f; f() = 1; end; module B; export f; f() = 2; end; using .A, .B; r = ChuiCore.binding_conflicts(A); @test any(p -> p.first === :f && B in p.second, r); io = IOBuffer(); ChuiCore.conflict_banner(io, A); @test occursin("f", String(take!(io)))'`. RED today: no ChuiCore snapshot, and no branch defines either name (ChuiCore main 3054d7c and its phase-2 branches, 2026-10-20). GREEN on 1.10.12 and 1.13.2. Not run by this lane.

## Problem
ChuiFrames accepts some collisions with other packages' exports (ChuiFrames ADR-0002 rule 6):
DataFrames' `select` and `rename`, and TidierData's `desc`, `across`, `where`, `lag`, `lead`,
`row_number`, `if_else` and `case_when` are different bindings from ChuiFrames'. Users who load
both must qualify them. The brief and ecosystem ADR-0009 §6 say ChuiCore's banner reports such
conflicts on interactive load, so every package uses one utility instead of writing its own.

## Proposed API
`chui-core.md`'s recommended shape, unchanged:
- `ChuiCore.binding_conflicts(mod)::Vector{Pair{Symbol,Vector{Module}}}`: for each name `mod`
  exports, the other loaded modules that export a **different binding** of that name (a
  re-export of the same binding is not a conflict);
- `ChuiCore.conflict_banner(io, mod)` prints them;
- silenced by `CHUI_QUIET_CONFLICTS=1` or `true`;
- each package calls it from `__init__` when `isinteractive()`;
- "other loaded modules" means every module reachable from `Main`, including submodules such as
  the reproducer's `A` and `B`, not only `Base.loaded_modules` (if ChuiCore chooses the narrower
  set, the reproducer uses two test packages instead).

ChuiFrames needs, in addition:
- the check must compare bindings, not rely on Julia's own "both … export" warning, which 1.13
  does not print (E-37, as in CC-012's proposed text);
- the banner must also report modules loaded **after** ChuiFrames, or say in its docs that it
  covers only modules loaded before (`__init__` runs once).

## History
- 2026-10-20 open: drafted in the ChuiFrames phase-1 report (ChuiFrames ADR-0002 rule 6,
  ADR-0014 §4; main c5db1cb); filed by the coordinator lane frames-reqs for the lead.
  **Partly answered at filing:** ownership is ChuiCore's (ecosystem ADR-0002: "The name-conflict
  banner utility | ChuiCore | every package reuses it"); ChuiCore ADR-0005 §1 places it in a
  top-level `banner.jl` (names indicative). **Still open:** the API, the switch and the phase.
  ADR-0012 P6 (accepted) leaves the PROVISIONAL bullet unchanged.
