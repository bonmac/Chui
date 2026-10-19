## Operating rules

- The cross-package suite lives in `benchmarks/`; per-package suites stay in each package repo.
- Run against registered versions, like `integration/`; raw results go to `benchmarks/results/raw/` (gitignored), summaries are committed.
- Report hardware, Julia version, thread count, package versions, cold vs warm (TTFX), median and spread.
- Publish losses as well as wins; competitors run out of process (R via `Rscript`, Python via `uv`).
- Close other heavy processes; one benchmark run at a time per machine.
