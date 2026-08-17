# Waypoint reference app

Waypoint is a small travel-planning app that shows AlphaX in a realistic
Flutter interface. It is the repository's reference app; if you only want the
smallest smoke test, start with [`examples/basic`](../basic/README.md).

## Run the app

Waypoint starts in demo mode. Demo mode uses local, in-memory fixture data, so
you do not need a server, an account, credentials, or an internet connection.

From the repository root:

```sh
cd examples/waypoint
flutter pub get
flutter run
```

If Flutter finds more than one device, list them with `flutter devices`, then
choose one with `flutter run -d <device-id>`. Waypoint includes Android, iOS,
macOS, Linux, and Windows hosts. AlphaX 1.0 does not support Web.

## What to explore

- **Trips** shows a travel dashboard and trip details. Open a trip to see its
  overview, itinerary, checklist, and document actions. The document actions
  exercise streamed download and upload APIs.
- **Discover** searches and filters saved places. Starting a new search cancels
  the previous search safely.
- **Live activity** starts and stops a streamed itinerary feed, demonstrating
  progressive response events and cancellation.
- **Transport lab** displays the selected data source, transport capabilities,
  TLS and proxy policy summaries, H3 preference with truthful fallback, and a
  fail-closed H3 requirement.

The layout uses side navigation on wide windows and bottom navigation on
smaller screens.

## Try the Dio adapter

The default client is AlphaX's direct client. To send the app's ordinary data
requests through Dio's `HttpClientAdapter` boundary instead, run:

```sh
flutter run --dart-define=WAYPOINT_CLIENT=dio
```

This still uses the local demo transport unless you also enable network mode.
It demonstrates Dio backed by `AlphaXDioAdapter`; it does not claim complete
Dio compatibility. File transfers and protocol probes continue to use the
shared AlphaX client directly.

## Optional network mode

Network mode is for connecting Waypoint to a fixture server. A small server is
bundled for local desktop testing, and no credentials are required by the app.
Start it from this directory:

```sh
dart run fixture_server/server.dart --host 127.0.0.1 --port 8080
```

In a second terminal, run Waypoint against it:

```sh
flutter run \
  --dart-define=WAYPOINT_MODE=network \
  --dart-define=WAYPOINT_BASE_URL=http://127.0.0.1:8080/
```

For a shared or physical-device fixture, replace the URL with a reachable
HTTPS base URL. To combine network mode with the Dio adapter, add
`--dart-define=WAYPOINT_CLIENT=dio`.

The fixture server must provide these routes relative to the base URL:

| Method | Route | Expected result |
| --- | --- | --- |
| `GET` | `/api/home` | JSON home data containing trips, places, and activities |
| `GET` | `/api/search?q=<text>` | JSON containing a `places` list |
| `GET` | `/api/trips/<id>` | JSON for one trip |
| `GET` | `/api/activity` | A newline-delimited streamed response containing activity JSON objects |
| `GET` | `/api/trips/<id>/itinerary` | Itinerary bytes for the download action |
| `POST` | `/api/documents` | Accept the uploaded travel-note bytes |
| `GET` | `/api/probe` | Any successful response for protocol inspection |

The easiest response shapes to copy are the local fixtures in
[`demo_waypoint_transport.dart`](lib/data/demo_waypoint_transport.dart). The
activity endpoint uses newline-delimited JSON so transport chunk boundaries do
not need to match application messages.

If network setup cannot be created—for example, if the base URL is missing—the
app opens in safe demo mode and shows a message. Errors returned later by a
configured server are shown in the app rather than silently replaced with demo
responses.

## Security and protocol notes

Network mode keeps AlphaX's secure platform TLS defaults. Do not disable
certificate verification. Plain HTTP is suitable only for an isolated local
fixture; use HTTPS with a valid certificate for device or shared testing.

Do not put production tokens, passwords, private keys, pins, proxy credentials,
or personal travel data in this example or in `--dart-define` values. Dart
defines are build configuration, not secret storage, and the fixture routes are
not an authentication design.

H3 preference is not a guarantee. Android Cronet and Apple URLSession may use
H1, H2, or H3 according to the provider, server, proxy, and network. Linux and
Windows use the H1-only Dart IO fallback, whose negotiated protocol cannot be
reported authoritatively. The **Require H3** action intentionally fails closed
unless H3 is actually observed. Demo mode performs no real TLS or protocol
negotiation; its deterministic transport reports H1 and demonstrates fallback
semantics locally.
