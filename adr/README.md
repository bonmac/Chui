# Ecosystem ADRs

Architecture Decision Records for the Chui ecosystem (decisions that span packages).
Package-internal decisions live in each package's `<Package>.jl/docs/adr/`. New ADRs start from
[`0000-template.md`](0000-template.md); evidence for factual claims is in
[`../research/ecosystem-verification.md`](../research/ecosystem-verification.md).
★ marks a question only the user can answer.

| # | Title | Status |
|---|---|---|
| 0000 | [Template](0000-template.md) | — |
| 0001 | [What we kept and what we changed from the three reference projects](0001-reference-projects-kept-and-changed.md) | Proposed (factory lane) |
| 0002 | [Package boundaries and dependency direction](0002-package-boundaries-and-dependency-direction.md) | Proposed |
| 0003 | [Repository and package names](0003-repo-names.md) | Proposed |
| 0004 | [Versioning and compatibility policy](0004-versioning-and-compatibility.md) | Proposed (★ brief 20 `v0.1.0-DEV`) |
| 0005 | [Registry strategy](0005-registry-strategy.md) | Proposed (★ create/push gate) |
| 0006 | [Minimum Julia version](0006-minimum-julia-version.md) | Proposed (★ 1.10 vs 1.12) |
| 0007 | [Test framework, quality checks and formatter](0007-test-framework-and-formatter.md) | Proposed (★ formatter) |
| 0008 | [Documentation layout](0008-documentation-layout.md) | Proposed |
| 0009 | [Shared vocabulary](0009-shared-vocabulary.md) | Proposed (★ `c` export style) |
| 0010 | [Cross-repo workflow](0010-cross-repo-workflow.md) | Proposed |
| 0011 | [License, benchmark tool and coverage floor](0011-license-benchmarks-coverage.md) | Proposed (★ all three) |
