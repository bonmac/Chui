### Changed

- ADR-0011 decision 2 amended (2026-10-20, factory 0.2.7; the text awaits the user's ★):
  - CI compares benchmarks with the factory's `scripts/bench.jl` (`julia scripts/ci.jl bench`,
    HEAD vs the merge base with the PR's base branch), not AirspeedVelocity. AirspeedVelocity
    0.6.6 cannot be installed next to CSV.jl 1.x (JSON3 1.14.3 caps Parsers at <= 2.8.8).
  - Unchanged: the `SUITE` convention, warning-only until baselines settle, and the one-way
    `bench.time_tolerance` threshold.
  - AirspeedVelocity may return if it installs next to CSV.jl 1.x; a new "Revisit when" item says so.
  - No upstream issue is filed (the user's decision).
