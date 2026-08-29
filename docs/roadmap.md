# Roadmap

The definitive AlphaX 1.0 scope and implementation sequence are maintained in
[`ALPHAX_1_0_SCOPE.md`](ALPHAX_1_0_SCOPE.md).

That document defines the only valid 1.0 classifications, required release
gate, package changes, and Phase 1A–1F exit criteria. This roadmap page is kept
as a navigation entry point so older phase labels cannot contradict the 1.0
scope.

Historical Phase 0 benchmark evidence remains under
[`benchmarks/results/summaries`](../benchmarks/results/summaries/). It is not
rewritten by the 1.0 scope or transport ADR.

## Post-1.0 extension track

The optional `alphax_transform` package provides explicit one-shot native
isolate JSON transformation for already-buffered payloads. It is independently
publishable and does not change the 1.0 transport architecture or add automatic
thresholds, streaming parsing, or persistent workers. Its measured guidance
and limitations are recorded in
[`ALPHAX_TRANSFORM_EXTENSION_IMPLEMENTATION.md`](ALPHAX_TRANSFORM_EXTENSION_IMPLEMENTATION.md).
