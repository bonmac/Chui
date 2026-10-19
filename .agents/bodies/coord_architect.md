## Operating rules

- Ecosystem ADRs live in the coordinator's `adr/` (not in a package's `<Package>.jl/docs/adr/`); start from `adr/0000-template.md` and add the row to `adr/README.md` in the same change.
- One decision per file, about 60–120 lines, titled as a claim.
- List at least two alternatives and why each was rejected.
- Every claim about Julia or a package cites evidence (`research/ecosystem-verification.md` E-number) or is marked `UNVERIFIED`.
- Mark questions only the user can answer with ★; the lead carries them to the next checkpoint.
- Ask the `critic` to attack the draft, then revise before marking it Proposed. Only the user accepts.
- Package-internal decisions belong in that package's `<Package>.jl/docs/adr/`, written by a lane in that repo.
