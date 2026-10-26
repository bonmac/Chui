- **Fixed:**
  - `scripts/dod.jl` (factory/template, ships with 0.3.0): the `changelog` requirement fails an added
    `changelog.d/` fragment that holds a Markdown heading, naming `julia scripts/changelog.jl fold`,
    which refuses such a fragment at release. Before, dod accepted any non-empty added fragment.
    The heading regex is duplicated from `changelog.jl`; `test_dod.jl` keeps the two identical.
  - The coordinator's five headed fragments (`eco-amend`, `adr-0011-amend`, `frames-reqs`,
    `requests-p4p3`, `sync-027`) are rewritten as list items only: each heading becomes a bold
    lead-in bullet with its items nested, every fact unchanged.
