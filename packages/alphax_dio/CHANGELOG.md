# Changelog

## 1.0.1 - 2026-08-31

- Refreshed stable adapter metadata and documentation links; no runtime or
  public API changes.

## 1.0.0 - 2026-08-30

- First stable Dio adapter release. The existing Retrofit → Dio → AlphaX
  compatibility path remains unchanged from rc.5.

## 1.0.0-rc.5 - 2026-08-30

- Coordinated the existing Dio 5.x adapter with the final rc.5 package family;
  no adapter runtime behavior changed after rc.4.
- Revalidated the supported Retrofit/Dio path and an injectable official
  OpenAPI-generated Dio client through `AlphaXDioAdapter`.

## 1.0.0-rc.4 - 2026-08-29

- Aligned package metadata with the coordinated AlphaX `1.0.0-rc.4` release;
  no runtime changes were made since `rc.3`.

## 1.0.0-rc.3 - 2026-08-17

- Added a runnable example showing Dio requests routed through
  `AlphaXDioAdapter` and a deterministic AlphaX transport.

## 1.0.0-rc.2 - 2026-08-17

- Corrected the theme-aware README logo URLs to absolute repository assets so
  pub.dev and other Markdown renderers load both SVG variants.

## 1.0.0-rc.1 - 2026-08-17

- Added `AlphaXDioAdapter`, a focused Dio 5.x `HttpClientAdapter` backed by an
  injected `AlphaXClient`.
- Mapped Dio request streams, headers, methods, cancellation, timeouts,
  redirects, progress, response streams, and normalized AlphaX errors.
- Exposed actual and completion-time protocol/metrics metadata through typed
  adapter keys and Dio's standard HTTP-version extra.
- Documented composition with AlphaX retry, authentication, cookie, cache, and
  resilience middleware configured on the injected client.
- Added deterministic adapter lifecycle, response-stream, cancellation,
  timeout, redirect, progress, and protocol tests.

### Known limitations

- This is not full Dio source/API compatibility. Dio interceptors and standard
  request/response transformation remain Dio-owned; AlphaX owns transport and
  policy behavior.
- TLS, trust anchors, SPKI pins, proxy policy, and middleware are configured on
  the injected `AlphaXClient`; the adapter does not invent per-request native
  policy controls.
- Browser support is provided by the separate `alphax_web` Fetch adapter; this
  Dio bridge does not change browser platform rules.
- AlphaX policy middleware is opt-in and bounded: retries are replay-aware,
  the supplied cookie/cache stores are in-memory while custom persistence
  remains caller-owned through stable store seams, authentication state is
  caller-owned, and resilience is generic rather than vendor-specific.
