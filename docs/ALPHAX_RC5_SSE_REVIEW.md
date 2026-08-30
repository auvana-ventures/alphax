# AlphaX rc.5 SSE review

Task 50 adds first-class Server-Sent Events parsing as a small pure-Dart
sub-library over the existing AlphaX response stream. It does not add a
transport, request helper, reconnect loop, or new package.

## 1. Final public API

The public API is intentionally two types from `package:alphax/sse.dart`:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax/sse.dart';

final response = await client.send(
  AlphaXRequest(
    method: HttpMethod.get,
    uri: uri,
    headers: AlphaXHeaders({'accept': 'text/event-stream'}),
  ),
);

await for (final event in response.stream.transform(AlphaXSseParser())) {
  print(event.data);
}
```

`AlphaXSseEvent` is the immutable parsed event model. `AlphaXSseParser` is a
reusable `StreamTransformer<List<int>, AlphaXSseEvent>`. There is no SSE client,
connection, request, response, options, or transport wrapper.

## 2. Event model

```dart
const AlphaXSseEvent({
  required String data,
  String? event,
  String? id,
  int? retry,
});
```

`event == null` represents the standard `message` default. `id == null` means
the dispatched block had no valid ID field; `id == ''` preserves an empty
`id:` field. `retry` is an optional non-negative integer in wire milliseconds,
which preserves the SSE wire representation without inventing a scheduling
policy.

## 3. Parser state machine

The parser creates fresh state for every bound source stream:

```text
bytes → strict streaming UTF-8 decoder → code units
      → line buffer / pending CR state
      → event data, event type, id, retry fields
      → blank line → AlphaXSseEvent
```

A CR is held until the next code unit so a CRLF pair is treated as one
terminator, including when the pair crosses source chunks. A blank line
dispatches the current data block and resets block-local fields. Comments and
unknown fields do not change that state.

## 4. UTF-8 handling

Input is decoded with Dart's strict streaming `Utf8Decoder`, so incomplete
multibyte code points can cross arbitrary source chunks and malformed UTF-8 is
a terminal `FormatException`. The decoder, rather than the SSE parser, retains
the incomplete code point. One leading UTF-8 BOM is ignored; a BOM later in the
stream remains data. This follows the [WHATWG SSE parsing and UTF-8
algorithm](https://html.spec.whatwg.org/multipage/server-sent-events.html#parsing-an-event-stream).

## 5. Line-ending behavior

LF, CRLF, and CR are recognized. A CR followed by LF, even across chunks, is
one line ending and cannot double-dispatch. A trailing CR is processed as a
line terminator before stream completion.

## 6. Field semantics

The first colon separates field name and value. Exactly one leading ASCII space
after that colon is removed; other whitespace is preserved. A non-comment line
without a colon is processed with the complete line as its field name and an
empty value. Field names are compared literally. `data`, `event`, `id`, and
`retry` are recognized; all other fields are ignored. Lines beginning with `:`
are comments and never create events.

## 7. ID and retry semantics

Multiple `data` fields append one LF separator each; the final separator is
removed when dispatching. An `id` value containing U+0000 is ignored. A valid
empty ID is retained as `''`; an absent ID remains `null`. `retry` is retained
only when it contains ASCII digits and fits the public integer representation;
invalid values are ignored.

The parser deliberately exposes fields from the current dispatched block and
does not retain connection-level last-event-id or reconnection-time state. It
does not send `Last-Event-ID`, schedule a retry, or reconnect. The caller owns
those decisions.

## 8. Event dispatch

Events dispatch only on an empty line when at least one `data` field has been
seen. A `data:` field therefore dispatches an event with empty data, while
comments, field-only blocks, and blank lines before data do not produce phantom
events. Multiple events in one source chunk and events fragmented across any
number of chunks are supported.

## 9. End-of-stream behavior

Pending data at EOF is discarded unless a terminating blank line was received,
as required by the SSE algorithm. A final line terminator alone is not a blank
line. A trailing CR is processed first, so a stream ending after the second CR
in `data: value\r\r` dispatches the event.

## 10. Error semantics

Malformed UTF-8 and configured parser-limit violations terminate the parsed
stream with `FormatException`. An upstream AlphaX response-stream error is
propagated with its original error identity and stack trace; buffered partial
event data is not dispatched after that terminal error. Unknown or invalid SSE
fields are not errors.

## 11. Cancellation

SSE uses normal AlphaX request cancellation. The request's
`AlphaXCancellationToken` is checked before dispatch and by the selected
transport while the response is active. Cancelling during an incomplete UTF-8
sequence or partial field terminates the response stream without a late event.
Cancelling the parsed subscription uses ordinary Dart stream cancellation and
there is no second SSE cancellation system.

## 12. Backpressure and buffering

`AlphaXSseParser` is an `async*` stream transformer over the source stream. It
does not eagerly read the response, create an unbounded event queue, or add a
second transport buffer. Dart pause/resume and cancellation flow through the
transformer to the AlphaX response stream. One current line and one current
event data buffer are retained.

## 13. Memory and abuse limits

The defaults are deliberately generous:

| Buffer | Default |
| --- | ---: |
| One line | 1 MiB of Dart string code units |
| One event's data | 8 MiB of Dart string code units, including inserted separators |

The constructor permits callers to lower or raise those limits. A limit
violation is deterministic and terminal. These limits prevent an endless line
or data block from growing parser-owned memory without imposing an arbitrary
small payload ceiling.

## 14. Native validation

`packages/alphax_native/test/sse_stream_test.dart` uses a local `HttpServer`
with the production-capable `DartIoTransport`. It sends a chunked
`text/event-stream` response containing BOM, comments, multiline Unicode data,
CRLF/LF boundaries, named events, IDs, and retry. It also verifies active
cancellation with a partial UTF-8 sequence and pre-dispatch cancellation.

Result: three native SSE tests passed, and the full `alphax_native` Flutter test
suite passed.

## 15. Web validation

A disposable Flutter Web fixture ran under Chrome against a local CORS-enabled
HTTP SSE server. The fixture used only `package:alphax_web/alphax_web.dart`,
the Web `createAlphaXClient()` façade, browser Fetch response streaming, and
`AlphaXSseParser`. The server split Unicode and event framing across small
chunks.

Result: the Chrome Web SSE fixture passed. The test validates Fetch streaming,
not browser `EventSource` behavior. CORS, TLS, proxy routing, connection
behavior, and protocol negotiation remain browser-owned.

## 16. Library and export decision

`package:alphax/sse.dart` is the dedicated public sub-library. The default
`package:alphax/alphax.dart` surface remains unchanged to keep the core import
small and preserve intentional modularity.

`alphax_native.dart` and `alphax_web.dart` additionally re-export
`package:alphax/sse.dart`. They already re-export the canonical `alphax.dart`
surface, and this additive export creates no cycle, duplicate type identity,
ambiguous symbol, or `src` export. Native and Web users can therefore use the
parser with their one deployment-family import when desired. Pure-Dart users
can import the SSE sub-library directly.

## 17. Documentation and example

Updated:

- root `README.md` with an SSE section and deployment-boundary notes;
- `docs/USAGE_AND_CUSTOMIZATION.md` with parser, cancellation, limits, and
  native/Web authority guidance;
- `packages/alphax/README.md` with the canonical parser example;
- `packages/alphax_native/README.md` and `packages/alphax_web/README.md` with
  their one-import re-export paths;
- `packages/alphax/example/sse.dart`, the compile-checked direct AlphaX example;
- the interoperability table to classify SSE as a supported parser sub-library.

No content-type gate was added to the pure parser, and no SSE request helper
was added. Callers can set `Accept: text/event-stream`, inspect response
headers, and apply application-specific status/content-type policy themselves.

## 18. Package impact

Only the existing `alphax` runtime package gained SSE implementation code and
the dedicated public library. `alphax_native` and `alphax_web` gained additive
re-export/test coverage. No new runtime package or dependency was added. No
changes were made to `AlphaXTransport.send`, streaming windows, native
transports, `alphax_http`, the Dio adapter, or the transform helper.

Package versions remain unchanged and no rc.5 package was published.

## 19. Dry-run and archive inspection

The affected package dry-runs included the new `sse.dart`, parser source, and
compile-checked example in the `alphax` archive. The native/Web archives contain
only their intended source, tests, and public entry changes; no fixture server,
browser build output, benchmark data, local path, secret, or signing material
is shipped.

| Package | Compressed archive | Warnings |
| --- | ---: | ---: |
| `alphax` | 59 KB | 0 |
| `alphax_native` | 97 KB | 0 |
| `alphax_web` | 13 KB | 0 |

All three post-commit `dart pub publish --dry-run` commands exited successfully.
No package was published.

## 20. Validation

The consolidated validation set passed:

- `dart format` for all changed Dart files;
- workspace `dart analyze` and affected `flutter analyze` checks;
- all seven package test suites (`alphax`, `alphax_native`, `alphax_dio`,
  `alphax_test`, `alphax_transform`, `alphax_web`, and `alphax_http`);
- focused SSE parser and native stream tests;
- Chrome Web Fetch SSE fixture with CORS;
- Dartdoc for `alphax`, `alphax_native`, and `alphax_web`;
- Markdown lint for changed Markdown with repository baseline HTML/line-length
  rules disabled;
- affected package dry-runs and archive inspection;
- dependency graph, secret/signing/path, and generated-output audits;
- `git diff --check`.

No performance benchmark was run. Native mobile platform builds were not
expanded because Task C changes only a re-export/test surface in the integration
packages and does not alter platform transport code.

## 21. Remaining limitations

- There is no automatic reconnect, retry loop, reconnection delay scheduler, or
  automatic `Last-Event-ID` header.
- The parser does not retain connection-level last-event-id or retry state.
- A response must end an event with a blank line for dispatch; incomplete EOF
  data is discarded.
- Strict malformed UTF-8 and line/event-data limits are terminal parser errors.
- The parser does not validate HTTP status or `Content-Type`; that remains a
  caller/request-layer decision.
- AlphaX capabilities, negotiated protocol, fallback metadata, completion
  metrics, native file paths, rich progress, rich timeout phases, and full
  request-level protocol controls remain unavailable through a parser event
  stream unless the caller uses the underlying AlphaX response directly.
- Web uses Fetch streaming rather than EventSource; CORS and all browser-owned
  networking behavior still apply.

## 22. Exact next task

Return for maintainer review. The next locked feature after approval is Task D —
first-class WebSocket. Do not begin WebSocket implementation, generator work,
OpenAPI, Protobuf, GraphQL framework, gRPC, or broader ecosystem work in Task C.

RC5 SSE READY
