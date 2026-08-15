# ADR-0008: Transport-neutral proxy policy semantics

Status: Accepted

## Context

System proxy behavior, explicit proxy configuration, direct connections, proxy
authentication, and QUIC availability differ across Dart IO, Cronet, and
URLSession. Treating an unsupported explicit proxy as a direct connection is a
security and routing error.

## Decision

`AlphaXProxyPolicy` supports:

- `system()` for platform/environment-managed routing;
- `direct()` for an explicit no-proxy route where the provider can enforce it;
- `http(...)` for an explicit HTTP proxy, optionally with Basic credentials;
- `https(...)` as an explicit proxy scheme that is capability-dependent.

An unsupported policy fails with `AlphaXUnsupportedProxyPolicyException`; it
does not silently use the system proxy or direct connection.

The current mappings are:

| Transport | System | Direct | Explicit HTTP | Explicit HTTPS | Basic proxy auth |
| --- | --- | --- | --- | --- | --- |
| Dart IO | supported | supported | supported | unsupported | supported |
| Android Cronet | provider-managed | unsupported by selected API | unsupported by selected API | unsupported | unsupported |
| Apple URLSession | system-managed | supported through session proxy dictionary | supported through HTTP proxy configuration | unsupported by the shared iOS/macOS mapping | supported where URLSession challenges with HTTP Basic |

The Apple adapter accepts only the explicit HTTP scheme. It uses the documented
CFNetwork dictionary key names for both HTTP and HTTPS destinations, so an
HTTPS destination may use HTTP CONNECT through that proxy. This is distinct
from an HTTPS proxy endpoint, which remains rejected as an unsupported policy
scheme on both iOS and macOS.

For an explicit HTTP proxy with Basic credentials, the Apple adapter sends a
hop-by-hop `Proxy-Authorization` value scoped to the selected proxy route and
normalizes a 407 response as `AlphaXProxyAuthenticationException`. The value
is never copied into origin `Authorization` headers or ordinary diagnostics.
The adapter strips it together with other sensitive headers on a cross-origin
redirect.

HTTP/3 is not guaranteed through a proxy. A preferred H3 request may report an
observed H2/H1 fallback; an H3 requirement fails if the final protocol is not
H3 or is unknown.

## Consequences

- Applications can discover and handle routing limitations before sending.
- System proxy support remains platform-managed rather than falsely presented
  as a uniform explicit API.
- The older selected Cronet dependency remains honest about its lack of a
  usable explicit proxy builder path.
- URLSession proxy behavior remains tied to the OS networking stack and must be
  validated on the target OS when a proxy is part of a release deployment.

## Validation

Policy construction and capability mapping are unit-tested; Dart IO explicit
HTTP proxy configuration and credentials are implemented. Native builds and
initialization reject unsupported Cronet/Apple HTTPS policy paths. The focused
macOS fixture recorded system/direct/explicit HTTP routing, trusted HTTPS
CONNECT, Basic success and wrong-credential failure, and unreachable-proxy
failure. A local custom-CA tunnel failed closed with a normalized TLS error;
the trusted CONNECT route is the supported evidence boundary.

## Revisit

Revisit Android explicit/direct proxy support only after the selected Cronet or
HttpEngine provider/API can be pinned to a supported version and tested for
HTTP, HTTPS CONNECT, authentication, and H3 fallback behavior.
