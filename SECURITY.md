# AlphaX Security Policy

AlphaX is pre-release software. Do not use unreleased packages in production and
do not send real credentials, personal data, or sensitive payloads to benchmark
fixtures or development-only harnesses.

## Reporting

Please report suspected vulnerabilities privately to the repository maintainers
before opening a public issue. Include the affected package/version or commit,
platform, reproduction steps, impact, and any safe proof of concept. Do not include
live secrets.

## Security defaults

- TLS certificate verification must remain enabled by default.
- Certificate or verification bypass must be explicit, difficult to enable
  accidentally, and must never be a release default.
- Authorization headers and full request/response bodies must not be logged by
  default.
- Native pointer ownership, cancellation, shutdown, and callback lifetimes require
  tests and documented ownership.
- Native dependencies must be versioned, audited, and updated through reviewed
  changes.

## Transport security behavior

- Android Cronet and Apple URLSession use platform certificate verification by
  default. Dart IO uses Dart platform verification by default.
- Apple URLSession strips `Authorization`, `Proxy-Authorization`, and `Cookie`
  on cross-origin redirects. Android delegates this behavior to the selected
  Cronet provider and must pass the release-gate assertion before it is a
  release claim. Applications should still avoid placing long-lived
  credentials in redirectable requests.
- System proxy behavior is inherited where the platform provides it. AlphaX
  does not expose explicit per-session proxy configuration or proxy credentials
  in the current release candidate.
- Certificate pinning, custom trust configuration, and mTLS are not a uniform
  AlphaX 1.0 API. Their absence must be treated as a release limitation, not
  emulated by disabling verification.

## Scope

The release-hardening security scope includes dependency review, secure TLS
defaults, redirect credential stripping, log redaction, release configuration
separation, and native callback/ownership safety. Fuzzing and broader
parser/boundary hardening remain outside the 1.0 release gate.
