# ADR-0007: Transport-neutral TLS policy and SPKI pinning

Status: Accepted

## Context

Platform networking stacks must retain normal certificate-chain, hostname, and
validity checks. AlphaX also needs a small, immutable policy surface for
additional trust anchors and certificate/public-key pinning without exposing
Security, Cronet, or `dart:io` callback types or offering a trust-all escape
hatch.

## Decision

`AlphaXTlsPolicy` provides:

- verified platform-default trust;
- DER trust anchors as additional or replacement trust, where the adapter can
  safely map them;
- host-scoped SHA-256 pins over DER SubjectPublicKeyInfo;
- multiple backup pins for rotation; and
- an opaque `AlphaXClientIdentity` reference for future secure platform
  identity mapping.

Pinning is applied only after ordinary trust-chain, hostname, and certificate
validity evaluation. An expired or untrusted certificate never becomes valid
because a pin matches. A pin mismatch is a normalized
`AlphaXCertificatePinMismatchException`; the adapter never silently falls back
to ordinary trust.

Trust-all/accept-any-certificate callbacks are explicitly excluded from the
public API. Raw private keys are also excluded; client identity references are
opaque and may be rejected when a provider cannot resolve them safely.

The current mappings are:

| Transport | Default trust | Custom anchors | SPKI pins | Client identity |
| --- | --- | --- | --- | --- |
| Dart IO | supported | supported through `SecurityContext` | unsupported; fails explicitly | unsupported; fails explicitly |
| Android Cronet | supported | unsupported by the selected provider API | supported by provider builder | unsupported; fails at initialization |
| Apple URLSession | supported | supported through `SecTrust` | supported through server-trust challenge | unsupported; fails at initialization |

Capability discovery and initialization errors expose these differences. No
transport advertises an unsupported control.

## Consequences

- The public security model remains transport-independent and immutable.
- Pin rotation can be expressed with backup keys.
- Native stacks remain responsible for TLS implementation and security updates.
- Applications must select a transport whose capabilities satisfy their
  configured policy; unsupported policy requests fail closed.

## Validation

Core policy immutability, digest, duplicate-pin, and replacement-trust rules
are unit-tested. Dart IO invalid-certificate behavior is covered. Native builds
compile the Apple trust challenge and Android provider pin configuration;
focused live pin success/mismatch and custom-CA fixtures remain release-gate
validation items for the attached devices/providers.

## Revisit

Revisit if Android exposes a supported dynamic trust-anchor or client-identity
API, or if a future transport can provide safe Dart IO pinning without a
trust-all callback.
