# AlphaX Security Policy

AlphaX `1.0.0` is the current stable release. This policy covers the published
AlphaX package family; older development snapshots and release candidates are
not supported for production use. Do not send real credentials, personal data,
or sensitive payloads to benchmark fixtures or development-only harnesses.

## Reporting a vulnerability

Report suspected vulnerabilities privately to `engineering@auvana.ventures`.
Include the affected package and version or commit, platform/provider, safe
reproduction steps, impact, and any non-sensitive proof of concept. Do not
open a public issue or include live secrets before maintainers have assessed the
report.

Maintainers will acknowledge receipt, coordinate a fix and disclosure date,
and credit the reporter when the reporter agrees. If email is unavailable, use
the repository's private security-reporting channel rather than a public issue.

## Transport security defaults

- TLS certificate-chain, hostname, and validity verification remains enabled by
  default for Dart IO, Android Cronet, and Apple URLSession.
- AlphaX has no trust-all or accept-any-certificate callback. Test-only custom
  trust configuration must remain explicit and must not become a release
  default.
- Native errors are normalized for application handling; credentials, full
  bodies, private keys, and proxy secrets are not logged by default.
- Android Cronet and Apple URLSession use platform-managed TLS providers. The
  selected provider's capability limits are reported and unsupported policies
  fail closed.

## Pinning and trust configuration

SPKI pins are host-scoped SHA-256 values and are checked only after ordinary
certificate validation. Configure a primary and one or more backup pins before
rotating a production key. A pin match cannot override an expired, invalid, or
untrusted certificate. Pin mismatch is a normalized failure; the transport does
not silently fall back to ordinary trust.

Custom trust anchors are supported only where the selected provider advertises
them. Dart IO SPKI pinning, Android custom anchors with the selected Cronet
provider, and mTLS/client identity mapping are explicit unsupported boundaries
in 1.0; none is emulated by disabling verification.

## Proxy and credential handling

Proxy credentials are hop-by-hop and must not be copied into origin headers,
telemetry, exception text, or debug logs. An explicit proxy policy that the
selected provider cannot honor fails closed; AlphaX never silently switches to
direct or system routing. HTTP CONNECT to an HTTPS destination is distinct from
an explicit HTTPS-proxy endpoint, which is not supported uniformly in 1.0.

## Release and dependency hygiene

Published packages ship no signing certificates, private keys, development-team
values, benchmark endpoints, or machine-specific paths in production defaults.
Android Cronet is resolved through the platform dependency graph, and Apple
uses system URLSession frameworks; no third-party native binary is copied into
the AlphaX package. Security-sensitive changes require tests, documentation,
and maintainer review before publication.
