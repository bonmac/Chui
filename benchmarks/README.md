# benchmarks/

The cross-package benchmark suite: workloads that span packages (e.g. ChuiFrames pipelines over
ChuiCore combinators) and comparisons with competitors (R via `Rscript`, Python via `uv`). Each
package's own suite lives in that package repo. Run by the benchmarker when an engine
changes; the benchmark tool and policy are in [ADR-0011](../adr/0011-license-benchmarks-coverage.md).

Planned layout (nothing here yet):

- one script per workload, run against **registered** versions, like `integration/`;
- `results/raw/`: raw output, gitignored;
- committed summaries with hardware, Julia version, threads, package versions, cold vs warm
  (TTFX), median and spread. Losses are published as well as wins.
