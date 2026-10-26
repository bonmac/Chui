- **Changed:**
  - ADR-0011 decision 2 amended (2026-10-20, factory 0.2.7; in force, wording confirmed by the user 2026-10-20):
    - CI compares benchmarks with the factory's `scripts/bench.jl` (`julia scripts/ci.jl bench`,
      HEAD vs the merge base with the PR's base branch), not AirspeedVelocity. AirspeedVelocity
      0.6.6 cannot be installed next to CSV.jl 1.x (every JSON3 release caps Parsers at <= 2.8.8).
    - New: CI now applies `bench.time_tolerance` (still warning-only), `benchmark/Project.toml` is
      required, and the memory table and job summary are gone.
    - Unchanged: the `SUITE` convention, warning-only until baselines settle, and the one-way
      `bench.time_tolerance` value.
    - The stale AirspeedVelocity bullets in decision 2 and Verification are marked superseded.
    - AirspeedVelocity may return if it installs next to CSV.jl 1.x; a new "Revisit when" item says so.
    - No upstream issue is filed (the user's decision).
