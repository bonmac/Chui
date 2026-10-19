# Package brief template: <PackageName>.jl (filled in by the lead)

The lead session hands this brief to the agents working on **<PackageName>.jl**.
- **Upstream:** <list, with the contracts consumed>, through released versions only.
- **Downstream:** <list, or "none yet">.

Lanes for this package edit and commit only in `<root>/<PackageName>.jl`.

**Read first:**
- `docs/agent/ECOSYSTEM.md`.
- The consumed contracts in `<root>/contracts/` (carry contract tests for them).
- The research report for this package: `<root>/research/<package>.md`.
- `HANDOFF.md`.

## Scope
<Filled in from the research report: the inspiration sources, parity targets, the shared grammar with the other Chui packages, integration points with ChuiFrames (tidy data in, tidy data out), and pluggable adapters.>

## Independence
<Which parts can be built before upstream features exist; the internal adapter module; cross-repo requests.>

## Testing and benchmarks
<Package-specific differential tests (reference implementations in R/Python via Rscript/uv), golden-output tests, benchmarks and budget.>

## Phases
1. Research and ADRs. ★ Report to the lead before implementing.
2. … 
N. Docs. Then v0.1.0, after the user confirms; record it in `<root>/releases.md`.

## Done means
<A checklist in the style of the other package briefs.>
