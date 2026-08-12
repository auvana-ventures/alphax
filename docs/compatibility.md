# Compatibility Plan

## Current support

The `alphax` package targets Dart `>=3.8.0 <4.0.0` and has no Flutter SDK
constraint. Phase 0 native prototypes target macOS and Linux. The repository does
not claim Android, iOS, Windows, or Web native support yet.

## Planned compatibility

- Android, iOS, macOS, Windows, and Linux after native transport selection and CI.
- Web where a compatible fetch-based capability model can be defined.
- Dio `HttpClientAdapter` compatibility after request/response lifecycle validation.
- Retrofit validation through the Dio adapter rather than a separate generator.

## Compatibility principles

- Preserve normal Dio options, interceptors, cancellation, `FormData`, progress,
  streams, and Retrofit-generated clients where the adapter supports them.
- Do not require native code for ordinary `alphax` contract tests.
- Do not claim a platform until CI builds and tests it.
- Treat transport-specific features as optional capabilities rather than inventing
  unsupported metrics or semantics.
