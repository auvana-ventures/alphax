# Migration guidance

AlphaX 1.0 exposes transport-neutral HTTP primitives. The migration is a
mapping exercise, not a promise of source compatibility or a full Dio adapter.

## From `package:http`

| `package:http` | AlphaX |
| --- | --- |
| `Client` / `BaseClient` | `AlphaXClient` with a selected `AlphaXTransport` |
| `Request` | `AlphaXRequest` |
| `Response` | `AlphaXResponse` |
| `Request.method` | `HttpMethod` |
| `Request.headers` | immutable `AlphaXHeaders` |
| `Request.bodyBytes` | `AlphaXBytesBody` |
| `Request.body` | `AlphaXTextBody` |
| `send()` byte stream | `AlphaXClient.send()` and `AlphaXResponse.stream` |
| `close()` | `AlphaXClient.close()` |

Replace direct response-body assumptions with explicit body consumption. A
response stream is single-consumption, and `AlphaXResponse.completionMetrics`
may be needed for authoritative final protocol metadata.

`package:http` exceptions should be translated at the application boundary to
the public `AlphaXException` categories. AlphaX does not automatically add
retries or authentication behavior.

## From Dio

| Dio | AlphaX |
| --- | --- |
| `Dio` | `AlphaXClient` |
| `Options.method` | `HttpMethod` |
| `Options.headers` | `AlphaXHeaders` |
| `CancelToken` | `AlphaXCancellationToken` |
| `Response<T>` | `AlphaXResponse` plus explicit bytes/text/JSON consumption |
| `ResponseType.stream` | `AlphaXResponse.stream` |
| `onSendProgress` | `AlphaXProgressCallback` on upload |
| `onReceiveProgress` | `AlphaXProgressCallback` on download |
| `FormData` | `AlphaXMultipartBody` and `AlphaXMultipartPart` |
| `download()` | `AlphaXClient.download()` with an `AlphaXFileTarget` |
| `uploadFile()` | `AlphaXClient.upload()` with an `AlphaXFileSource` |
| interceptors | `AlphaXMiddleware` |

Middleware ordering and body ownership are explicit. A single-use streamed
body must not be accidentally replayed by middleware or redirect handling.
AlphaX 1.0 does not include an `alphax_dio` adapter, automatic retry/auth
refresh, cache, telemetry SDK integration, or Dio-specific types in `alphax`.

## Transport selection

Applications should select the platform transport at composition time and keep
the rest of the application on `AlphaXClient` and `alphax` types:

- Android: `AndroidCronetTransport.create()`;
- iOS/macOS: `AppleUrlSessionTransport.create()`;
- Dart-supported fallback: `DartIoTransport()`.

Inspect `client.capabilities` before requesting optional behavior, and inspect
the response completion metrics for the actual negotiated protocol. A protocol
preference is not a guarantee that the provider will use that protocol.
