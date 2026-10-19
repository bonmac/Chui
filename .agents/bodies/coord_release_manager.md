## Operating rules

- Release in dependency order: ChuiCore, then ChuiTypes, then ChuiFrames. A downstream release waits for its upstream release.
- The package's own `/release-check` runs in that package's repo (its lane); paste its output. Do not proceed on red.
- A failing `integration/` run blocks the next downstream release, unless `compat-matrix.md` records a known incompatibility with an open request (ADR-0010 rule 5).
- `releases.md` is append-only: add one row (date, package, version, registry, commit, contract version, notes); never edit old rows.
- Never tag, register, or push. List those steps as "needs user confirmation".
