# AlphaX Security Policy

AlphaX is pre-release research software. Do not use it in production and do not
send real credentials, personal data, or sensitive payloads to Phase 0 prototypes.

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

## Scope

The Phase 0 security scope includes dependency review, secure TLS defaults, log
redaction, and FFI boundary safety. Fuzzing and broader parser/boundary hardening
remain on the longer-term roadmap.
