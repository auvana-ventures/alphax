# AlphaX Post-1.0 Roadmap

Status: Planning boundary, not a release commitment

This document separates future exploration from the frozen 1.0 product path.
AlphaX 1.0.0-rc.5 is the final feature release candidate. After rc.5, the
project moves directly into stable-1.0 stabilization; there is no rc.6 feature
cycle.

Only separately approved post-1.0 work belongs here. Items are candidates, not
promised versions or an ordered backlog.

## rc.5 optional-scope resolution

The bounded optional rc.5 items are closed and are not an rc.6 backlog:

- F — the official OpenAPI Generator template proof was accepted. Expanding it
  into broader model, multipart, or file policies is a 1.1 candidate;
- G — existing AlphaX byte APIs are sufficient for Protobuf, so the result is a
  caller-owned documentation recipe with no AlphaX Protobuf package; and
- H — the approved ecosystem seams were validated with explicit classifications.

The reusable GraphQL WebSocket adapter was proved only at the caller layer and
remains a post-1.0 compatibility candidate. gRPC remains post-1.0 and is not
implied by the Protobuf result. See the
[feature-freeze boundary](ALPHAX_1_0_FEATURE_FREEZE.md) and the
[bounded-optionals review](ALPHAX_RC5_BOUNDED_OPTIONALS_REVIEW.md).

## Candidate areas

### 1.1 candidates

- expand the bounded OpenAPI template proof if it proves useful;
- improve direct generator ergonomics and generated-client coverage;
- add more ecosystem consumer fixtures;
- improve GraphQL transport/link compatibility without building a GraphQL
  framework;
- add optional Protobuf ergonomics only where repeated mapping is demonstrated;
- refine WebSocket/SSE policy and lifecycle behavior based on real consumers;
- address a concrete package-role or pure-Dart server packaging need if one is
  demonstrated.

### 1.x candidates

- provider-specific improvements backed by actual demand and capability evidence;
- additive observability extensions;
- additional platform integrations with an accepted architecture decision;
- compatibility work for maintained ecosystems when a stable injection seam exists.

### Future feasibility candidates

- AlphaX integration with the official Dart gRPC channel/transport seam;
- any package-role redesign or core/package split;
- advanced H3/provider controls such as DoH, 0-RTT, migration, or custom DNS;
- measured performance work after a production problem is established.

## Explicit boundaries

The post-1.0 roadmap does not authorize implementation. It does not reopen the
accepted Cronet/HttpEngine, URLSession, Dart IO, or Web Fetch architecture. It
does not authorize a second networking engine, FFI/shared-memory transport, or
zero-copy project.

New requests discovered during stabilization are classified as release-blocking
only when they prevent correctness, security, frozen API coherence, packaging,
compatibility, or supported-platform validation. All other requests belong here
or are discarded.

## References

- [AlphaX rc.5 scope lock](ALPHAX_1_0_RC_5_SCOPE_LOCK.md)
- [ADR-0011: rc.5 final feature candidate](decisions/0011-rc5-final-feature-candidate.md)
- [AlphaX rc.5 architecture plan](ALPHAX_1_0_RC_5_ARCHITECTURE_AND_ECOSYSTEM_PLAN.md)
