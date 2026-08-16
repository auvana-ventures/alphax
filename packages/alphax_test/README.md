# alphax_test

`alphax_test` is for people writing tests for AlphaX transports or
applications. It is not needed by a normal application that only sends HTTP
requests.

## Add it only for tests

After the RC is published:

```sh
dart pub add --dev alphax_test
```

While this RC is unpublished, add the repository path from a package in this
workspace:

```yaml
dev_dependencies:
  alphax_test:
    path: ../alphax_test
```

## What it provides

The package provides deterministic fake transports, responses, streams,
delays, failures, cancellation, file fixtures, request recording, and reusable
transport-conformance tests. A fake transport lets a test check application
behavior without contacting the internet.

Example:

```dart
import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:test/test.dart';

void main() {
  test('uses a fake response without a network connection', () async {
    final client = AlphaXClient(
      transport: FakeAlphaXTransport(
        response: AlphaXResponse(statusCode: 200, bodyBytes: <int>[1, 2, 3]),
      ),
    );
    addTearDown(client.close);

    final response = await client.get(Uri.https('example.com', '/test'));

    expect(await response.readAsBytes(), <int>[1, 2, 3]);
  });
}
```

The helpers do not require Flutter or a native engine. Adapter packages can run
the same conformance suite against their transport implementations.
