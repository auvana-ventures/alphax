# AlphaX 1.0 feature freeze

State: **ALPHAX 1.0 FEATURE FREEZE**

Declared: 2026-08-30
Freeze declaration commit: `1cf2ed49f1ab2d586d57189807b7e549b437a883`

This is the authoritative stable boundary after the final feature candidate.
There is no rc.6 feature cycle and no new feature work before `1.0.0`.

## Frozen package and API family

The frozen family is the existing coordinated AlphaX package set:

- `alphax` pure-Dart request/response, policy, SSE, WebSocket, and typed-client
  contracts;
- `alphax_native` native transport selection, native files, and deployment
  façade;
- `alphax_web` browser Fetch/WebSocket deployment façade;
- `alphax_dio` Dio compatibility;
- `alphax_http` `package:http` compatibility;
- `alphax_generator` direct typed REST development tooling;
- `alphax_transform` optional large-JSON transform; and
- `alphax_test` development/test helpers.

The coordinated package versions were prepared at `1.0.0-rc.5` by the release
preparation task and were subsequently published together. The package set,
validation evidence, and hosted-consumer results are recorded in the [rc.5
publication report](ALPHAX_1_0_RC_5_PUBLICATION_REPORT.md).

## Completed rc.5 features

Tasks A–E are complete:

- native/Web entry façades and package-role UX;
- `alphax_http` compatibility;
- first-class SSE;
- first-class WebSocket lifecycle support; and
- direct typed REST generation.

## Bounded optional decisions

- F: the official OpenAPI Generator Mustache template proof is accepted as a
  bounded proof, not a full OpenAPI product;
- G: existing AlphaX byte APIs are sufficient for Protobuf, so the result is a
  documentation-only caller-layer recipe; and
- H: ecosystem compatibility seams are validated with explicit classifications.

OpenAPI multipart/file template expansion and a reusable GraphQL WebSocket
adapter remain post-1.0 candidates. Protobuf does not imply gRPC; gRPC remains
post-1.0.

## Allowed stabilization changes

Only the following work is allowed before stable `1.0.0`:

- correctness and regression fixes;
- security hardening;
- consistency fixes required by the frozen public API;
- supported-platform conformance fixes;
- compatibility regressions;
- documentation and migration corrections;
- package metadata and packaging/build fixes; and
- release validation and publication preparation.

## Prohibited before stable

Do not add a new capability, package, transport engine, protocol integration,
generator family, GraphQL framework, gRPC integration, rc.6 feature backlog, or
new performance campaign. Do not reopen the accepted package architecture or
the rc.5 scope.

## Next release sequence

```text
rc.5 preparation
  → rc.5 publication
  → stabilization only
  → 1.0.0
```

The next task is **ALPHAX 1.0 STABILIZATION AND RELEASE GATE**.
