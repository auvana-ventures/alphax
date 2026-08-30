# AlphaX rc.5 entry façade review

Task 48 implements the additive rc.5 entry façades within the locked scope in
[`docs/ALPHAX_1_0_RC_5_SCOPE_LOCK.md`](ALPHAX_1_0_RC_5_SCOPE_LOCK.md) and
[`ADR-0011`](decisions/0011-rc5-final-feature-candidate.md). The published
`1.0.0-rc.4` API remains the compatibility baseline. No package versions were
changed and no rc.5 package was published.

## 1. Native façade API

`alphax_native` now exports `createAlphaXClient()`:

```dart
import 'package:alphax_native/alphax_native.dart';

final client = await createAlphaXClient();
```

The supported construction parameters are the existing client middleware and
transport-construction policies:

```dart
Future<AlphaXClient> createAlphaXClient({
  Iterable<AlphaXMiddleware> middleware = const <AlphaXMiddleware>[],
  AlphaXTlsPolicy tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
  AlphaXProxyPolicy proxyPolicy = const AlphaXProxyPolicy.system(),
});
```

The factory calls the existing `createAlphaXTransport()` once, awaits its
initialization, and passes the result to exactly one `AlphaXClient`. It does not
duplicate platform selection or add request-level configuration parameters.

## 2. Web façade API

`alphax_web` exports the same obvious name with a synchronous browser-backed
construction call:

```dart
import 'package:alphax_web/alphax_web.dart';

final client = createAlphaXClient();
```

Its supported parameters are middleware and the existing browser Fetch
credential mode:

```dart
AlphaXClient createAlphaXClient({
  Iterable<AlphaXMiddleware> middleware = const <AlphaXMiddleware>[],
  bool withCredentials = false,
});
```

The factory constructs exactly one `WebFetchTransport` and exactly one
`AlphaXClient`. TLS, proxy routing, CORS, redirects, connection reuse, and
negotiated protocol remain browser-owned. The Web façade does not expose native
file paths, native TLS/proxy controls, or an H2/H3 capability claim.

## 3. Naming decision

Both integration packages use `createAlphaXClient()`. The imports establish the
deployment context, so the identical name provides the clearest autocomplete
and lets platform-specific application setup differ only at the package import
and deployment boundary. `createAlphaXWebClient()` was not needed, and no
`AlphaXNativeClient` or `AlphaXWebClient` wrapper was introduced.

## 4. Re-export decision

Both entry libraries re-export the broad public surface from
`package:alphax/alphax.dart`:

```dart
export 'package:alphax/alphax.dart';
```

This reuses the canonical core declarations, so there is no duplicate type
identity, export cycle, or manually maintained copy of core symbols. The core
package remains unchanged in dependency direction and remains pure Dart. No
core `src` library is exported. Existing local adapter exports remain in the
integration packages for rc.4 compatibility; they are not substitutes for the
canonical core export.

The native and Web tests compile requests, bodies, headers, middleware,
cancellation, timeouts, protocols, TLS/proxy policies, errors, and metrics
through their single integration entry imports.

## 5. Dependency declaration result

The normal native consumer can declare only `alphax_native` as its direct
AlphaX runtime dependency (plus the Flutter SDK dependency required by the
application). The normal Web consumer can declare only `alphax_web` as its
direct AlphaX runtime dependency. Neither requires a direct `alphax` entry
merely to use the public API.

`alphax_native` already depends on `alphax`; `alphax_web` already depends on
`alphax` and `http`. No manifest or version change was needed.

## 6. Clean consumer result

Two clean temporary consumer projects were created outside the repository.
The native project had one direct AlphaX package dependency, one
`package:alphax_native/alphax_native.dart` import, one `await
createAlphaXClient()` call, a GET, and `close()`. `flutter pub get`,
`flutter analyze`, and `flutter build bundle --debug` passed. Its lockfile
classified `alphax_native` as direct and `alphax` as transitive.

The Web project had one direct AlphaX package dependency, one
`package:alphax_web/alphax_web.dart` import, one synchronous
`createAlphaXClient()` call, and `close()`. `dart pub get`, `dart analyze`, and
`dart compile js` passed. Its lockfile classified `alphax_web` as direct and
`alphax` as transitive.

## 7. Lifecycle ownership

The returned client owns the one transport created for it. A caller reuses that
client for all requests in its scope and calls `client.close()` when the scope
ends. `AlphaXClient` retains its existing idempotent close future and closes its
transport exactly once. No request creates a client or transport, and no hidden
global singleton or provider cache was added.

Deterministic tests cover one selected native transport, one browser transport,
repeated close, request-after-close, direct transport-after-close, and close
ownership. The native test also verifies the existing platform initialization
method is called once when the selected provider uses the native channel.

## 8. Initialization/error behavior

The native façade awaits `createAlphaXTransport()` directly. Provider
initialization errors therefore fail client creation with the existing
transport error semantics; there is no silent fallback and no partially
initialized client. The test suite covers a platform provider failure and an
invalid custom trust-anchor failure. If the client constructor itself were to
fail after transport creation, the façade closes that transport and rethrows
the original error with its stack trace.

The Web façade has no asynchronous provider initialization. Browser Fetch
construction is synchronous, and browser dispatch/error behavior remains the
existing `WebFetchTransport` behavior.

## 9. rc.4 compatibility

The following rc.4 construction paths remain valid and were preserved or
tested:

```dart
AlphaXClient(transport: ...);
createAlphaXTransport();
DartIoTransport();
AndroidCronetTransport.create();
AppleUrlSessionTransport.create();
WebFetchTransport();
```

Custom `AlphaXTransport` implementations can still be injected directly. The
existing transport selection tests and native platform builds remain green;
the new façade is additive and does not deprecate any rc.4 constructor or
factory.

## 10. Advanced/custom transport path

The progressive configuration model is now:

```dart
// Simple native setup.
final client = await createAlphaXClient();

// Configured native setup.
final configured = await createAlphaXClient(
  middleware: <AlphaXMiddleware>[AlphaXRetryMiddleware()],
  tlsPolicy: const AlphaXTlsPolicy.platformDefault(),
  proxyPolicy: const AlphaXProxyPolicy.system(),
);

// Explicit and custom transport escape hatches.
final explicit = AlphaXClient(transport: DartIoTransport());
final custom = AlphaXClient(transport: MyTransport());
```

Web uses `createAlphaXClient(middleware: ..., withCredentials: ...)` when its
browser controls are sufficient and retains
`AlphaXClient(transport: WebFetchTransport())` or a custom transport when
explicit assembly is required. Timeout, cancellation, redirect policy,
protocol preference/requirement, and progress remain request-level concerns.

## 11. Before/after UX metrics

Metrics count the minimal documented deployment-path setup, not optional
packages or request code. “Setup/construction calls” counts transport/client
construction calls in the minimal example.

### Native Flutter

| Metric | rc.4 | rc.5 |
| --- | ---: | ---: |
| AlphaX dependency declarations | 2 | 1 |
| AlphaX imports | 2 | 1 |
| setup/construction calls | 2 | 1 |
| manual transport creation | yes | no |
| platform branching | no | no |
| portable configuration | yes | yes |
| explicit transport escape hatch | yes | yes |

rc.4 required `alphax` plus `alphax_native`, two imports, and
`AlphaXClient(transport: await createAlphaXTransport())`. rc.5 replaces that
assembly with one direct integration dependency, one import, and one factory
call while preserving the explicit path.

### Browser Web

| Metric | rc.4 | rc.5 |
| --- | ---: | ---: |
| AlphaX dependency declarations | 2 | 1 |
| AlphaX imports | 2 | 1 |
| setup/construction calls | 2 | 1 |
| manual transport creation | yes | no |
| platform branching | no | no |
| portable configuration | yes | yes |
| explicit transport escape hatch | yes | yes |

rc.4 required `alphax` plus `alphax_web`, two imports, and explicit
`AlphaXClient(transport: WebFetchTransport())`. rc.5 uses one direct package,
one import, and synchronous `createAlphaXClient()` while retaining explicit
browser/custom transport construction.

## 12. Documentation changes

Updated current-facing material to lead with deployment paths and the simplest
native setup:

- root [`README.md`](../README.md): install guidance, deployment-path table,
  first quick start, progressive configuration, and package-role framing;
- [`docs/USAGE_AND_CUSTOMIZATION.md`](USAGE_AND_CUSTOMIZATION.md): native/Web
  entry flows, configured factories, explicit escape hatches, and lifecycle;
- [`alphax_native` README](../packages/alphax_native/README.md): one-import
  native setup, configured factory, and advanced transport controls;
- [`alphax_web` README](../packages/alphax_web/README.md): one-import browser
  setup, browser truth, and explicit transport controls; and
- compile-tested [`native example`](../packages/alphax_native/example/main.dart)
  and [`Web example`](../packages/alphax_web/example/main.dart).

The docs do not describe rc.5 as published and do not describe planned
features as implemented.

## 13. Package dry-runs and archive inspection

Both affected integration packages passed their publish dry-runs:

- `flutter pub publish --dry-run --ignore-warnings` in `packages/alphax_native`:
  archive inspection listed the new façade, examples, tests, platform sources,
  and a 96 KB compressed archive. The only warning was the expected dirty-git
  warning for the task-owned changes.
- `dart pub publish --dry-run --ignore-warnings` in `packages/alphax_web`:
  archive inspection listed the new façade, example, tests, and browser/stub
  transports, with a 12 KB compressed archive. The only warning was the
  expected dirty-git warning for the task-owned changes.

No generated, benchmark, signing, or unrelated work was included by the
task-owned package changes.

## 14. Validation

The consolidated validation pass completed with these results:

- Dart formatting passed for all changed Dart files (`11 files, 0 changed`).
- `bash tooling/scripts/analyze_dart_packages.sh` passed for all package
  analyses, including the Flutter native package and Web package.
- `bash tooling/scripts/test_packages.sh` passed all six package suites:
  `alphax`, `alphax_dio`, `alphax_native`, `alphax_test`, `alphax_transform`,
  and `alphax_web`.
- The native package suite passed 46 tests after the re-export compile-surface
  assertion was added; the Web suite passed 6 tests.
- Native consumer compilation passed; Web consumer JavaScript compilation
  passed.
- `flutter build apk --debug` passed in `examples/waypoint`.
- `flutter build macos --debug` passed in `examples/waypoint`.
- `flutter build ios --debug --no-codesign` passed in `examples/waypoint`.
- `dart test -p chrome` passed all 6 Web tests.
- `dart doc --dry-run` passed for `alphax`, `alphax_native`, and `alphax_web`
  with zero warnings and errors.
- Markdown structural lint passed with the repository's existing MD013
  line-length and MD033 inline-HTML rules disabled; the default lint output
  contains those pre-existing README/table style findings. A relative-link
  audit found that all checked internal Markdown targets resolve.
- Dependency inspection with `flutter pub deps`/`dart pub deps` confirmed the
  existing direction: integration packages depend on `alphax`; `alphax` does
  not depend on either integration package.
- Secret/signing/path audit found no credentials, signing artifacts, or personal
  absolute paths in the task-owned changes. The only matches were intentional
  documentation placeholders such as `token-from-app` and `/tmp/archive.bin`.
- `git diff --check` passed for the task-owned changes.
- No performance benchmark was run, as required by Task 48.

The Android/macOS/iOS builds emitted the existing Flutter warning that the
native plugin does not yet support Swift Package Manager; CocoaPods/Xcode and
Gradle builds completed successfully. No version, tag, release, or publication
operation was performed.

## 15. Remaining limitations

- rc.5 is implemented in the source tree but remains unpublished at the
  existing `1.0.0-rc.4` package version until the dedicated release task.
- `alphax` remains pure Dart and transport-independent. The existing pure-Dart
  built-in-provider packaging gap is recorded as POST_1_0; no `alphax_io` was
  created.
- Web TLS, proxy routing, CORS, redirects, credentials, and protocol
  negotiation remain browser-owned. Web protocol metadata remains `unknown`,
  and no H2/H3 claim was added.
- The native plugin's Swift Package Manager warning remains outside Task 48
  scope; the validated CocoaPods/Xcode path is intact.

## 16. Exact next task

Return for maintainer review. After approval, the next locked task is **Task B:
`alphax_http` compatibility**. Do not begin SSE, WebSocket, generator, or other
later work as part of Task 48.

RC5 ENTRY FACADE READY
