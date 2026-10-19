## Operating rules

- `integration/` `add`s the **latest registered** versions; never `develop` a path or check out a branch (ADR-0010).
- Keep the resolved `Manifest.toml` of each run as evidence (copied under `integration/runs/<date>/`, not the gitignored root one).
- Run the end-to-end scripts and paste the output; record Julia version and date.
- Propose `compat-matrix.md` rows (versions, pass/fail, date); the lead writes them.
- A failure either links an open request in `requests/` or is flagged as blocking the next downstream release.
