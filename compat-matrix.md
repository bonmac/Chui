# Compatibility matrix

Which released versions were tested together by an [`integration/`](integration/README.md) run,
written by the lead from the integration-tester's report
([ADR-0010](adr/0010-cross-repo-workflow.md)). A failure blocks the next downstream release unless
the row records it as a known incompatibility with an open request in [requests/](requests/README.md).
Future packages add a column through an ADR.

| Run date | Julia | ChuiCore | ChuiTypes | ChuiFrames | Result | Manifest | Known incompatibility / request |
|---|---|---|---|---|---|---|---|
