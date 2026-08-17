# Compatibility Plan

## Current release-candidate support

The `alphax` package targets Dart `>=3.8.0 <4.0.0` and has no Flutter SDK
constraint. The 1.0 platform strategy is:

- Android API 24+: Cronet/HttpEngine provider, H1/H2/H3 where the selected
  provider and network path support them;
- iOS 15+ and macOS 12+: Foundation URLSession, H1/H2/H3 where the OS and
  network path support them;
- Linux and Windows: Dart IO H1 fallback;
- Web: use the separate `alphax_web` Browser Fetch adapter. Ordinary HTTP is
  supported, but browser protocol metadata is unknown and concrete protocol
  requirements fail closed.

Protocol capability, request preference, actual negotiated protocol, and
fallback are separate values. H3 preference does not guarantee H3 use.

Dio `HttpClientAdapter` compatibility remains optional to the native transport
gate and is implemented as a focused `alphax_dio` boundary over an injected
`AlphaXClient`. It is not full Dio API compatibility; Retrofit usage is not
validated as a separate 1.0 guarantee.

## Compatibility principles

- Preserve normal Dio options, interceptors, cancellation, `FormData`, progress,
  streams, and Retrofit-generated clients where the adapter supports them.
- Do not require native code for ordinary `alphax` contract tests.
- Do not claim a platform until CI builds and tests it.
- Treat transport-specific features as optional capabilities rather than inventing
  unsupported metrics or semantics.
