import 'dart:async';
import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

final class _ContractTransport extends AlphaXTransport {
  _ContractTransport(this.handler);

  final Future<AlphaXResponse> Function(AlphaXRequest request, int call) handler;
  final List<AlphaXRequest> requests = <AlphaXRequest>[];

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(http11: AlphaXSupport.supported);

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    requests.add(request);
    return handler(request, requests.length);
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    final response = await send(request);
    yield AlphaXResponseStarted(statusCode: response.statusCode, headers: response.headers);
    final bytes = await response.body.readAsBytes();
    if (bytes.isNotEmpty) {
      yield AlphaXResponseChunk(bytes);
    }
    yield AlphaXResponseCompleted(bytesReceived: bytes.length);
  }

  @override
  Future<void> close() async {}
}

final class _DelayedCacheStore implements AlphaXCacheStore {
  _DelayedCacheStore([AlphaXMemoryCacheStore? delegate])
    : delegate = delegate ?? AlphaXMemoryCacheStore();

  final AlphaXMemoryCacheStore delegate;

  @override
  Future<AlphaXCacheEntry?> read(AlphaXCacheKey key) async {
    await Future<void>.delayed(Duration.zero);
    return delegate.read(key);
  }

  @override
  Future<void> write(AlphaXCacheEntry entry) async {
    await Future<void>.delayed(Duration.zero);
    await delegate.write(entry);
  }

  @override
  Future<void> remove(AlphaXCacheKey key) async {
    await Future<void>.delayed(Duration.zero);
    await delegate.remove(key);
  }

  @override
  Future<void> clear() async => delegate.clear();
}

final class _FailingCookieStore implements AlphaXCookieStore {
  _FailingCookieStore({this.failRead = false});

  final bool failRead;

  @override
  Future<List<AlphaXCookie>> readCookies() async {
    if (failRead) {
      throw AlphaXTransportException(
        'cookie store failed',
        cause: 'session=secret-cookie-value',
      );
    }
    return const <AlphaXCookie>[];
  }

  @override
  Future<void> writeCookies(Iterable<AlphaXCookie> cookies) async {
    throw AlphaXTransportException(
      'cookie store failed',
      cause: 'session=secret-cookie-value',
    );
  }

  @override
  Future<void> updateCookies(
    Iterable<AlphaXCookie> Function(List<AlphaXCookie> cookies) transform,
  ) async {
    throw AlphaXTransportException(
      'cookie store failed',
      cause: 'session=secret-cookie-value',
    );
  }

  @override
  Future<void> clear() async {}
}

final class _FailingCacheStore implements AlphaXCacheStore {
  @override
  Future<AlphaXCacheEntry?> read(AlphaXCacheKey key) async => null;

  @override
  Future<void> write(AlphaXCacheEntry entry) async {
    throw StateError('cache store write failed');
  }

  @override
  Future<void> remove(AlphaXCacheKey key) async {}

  @override
  Future<void> clear() async {}
}

AlphaXHeaders _setCookies(Iterable<String> values) => AlphaXHeaders.fromEntries(
  values.map((value) => MapEntry<String, String>('set-cookie', value)),
);

AlphaXHeaders _headers(Map<String, String> values) => AlphaXHeaders(values);

AlphaXCacheEntry _entry({
  required Uri uri,
  HttpMethod method = HttpMethod.get,
  Map<String, String> requestHeaders = const <String, String>{},
  AlphaXHeaders headers = const AlphaXHeaders.empty(),
  List<int> bodyBytes = const <int>[1],
  DateTime? storedAt,
  Duration freshnessLifetime = const Duration(minutes: 5),
  Duration ageAtStore = Duration.zero,
  String? identityKey,
}) => AlphaXCacheEntry(
  key: AlphaXCacheKey(
    method: method,
    uri: uri,
    requestHeaders: requestHeaders,
    identityKey: identityKey,
  ),
  statusCode: 200,
  headers: headers,
  bodyBytes: bodyBytes,
  storedAt: storedAt ?? DateTime.utc(2026, 1, 1),
  freshnessLifetime: freshnessLifetime,
  ageAtStore: ageAtStore,
);

void main() {
  final uri = Uri.https('example.com', '/items');
  final fixedNow = DateTime.utc(2026, 1, 1, 12);

  group('cookie store', () {
    test('matches domain and host-only cookies correctly', () async {
      final jar = AlphaXCookieJar();
      await jar.storeFromResponse(
        Uri.https('api.example.com', '/login'),
        _setCookies(<String>[
          'domain-cookie=1; Domain=example.com; Path=/',
          'host-cookie=1; Path=/',
        ]),
        now: fixedNow,
      );

      expect(
        await jar.cookieHeaderFor(Uri.https('api.example.com', '/')),
        'domain-cookie=1; host-cookie=1',
      );
      expect(await jar.cookieHeaderFor(Uri.https('other.example.com', '/')), 'domain-cookie=1');
    });

    test('applies path matching without prefix confusion', () async {
      final jar = AlphaXCookieJar();
      await jar.storeFromResponse(
        uri,
        _setCookies(<String>['api=1; Path=/api']),
        now: fixedNow,
      );

      expect(await jar.cookieHeaderFor(Uri.https('example.com', '/api/items')), 'api=1');
      expect(await jar.cookieHeaderFor(Uri.https('example.com', '/apix')), isNull);
    });

    test('expires cookies and does not return expired values', () async {
      final jar = AlphaXCookieJar();
      await jar.storeFromResponse(
        uri,
        _setCookies(<String>['short=1; Max-Age=1']),
        now: fixedNow,
      );

      expect(
        await jar.cookieHeaderFor(uri, now: fixedNow.add(const Duration(seconds: 2))),
        isNull,
      );
    });

    test('replaces and deletes a cookie by name, domain, and path', () async {
      final jar = AlphaXCookieJar();
      await jar.storeFromResponse(uri, _setCookies(<String>['session=old; Path=/']), now: fixedNow);
      await jar.storeFromResponse(uri, _setCookies(<String>['session=new; Path=/']), now: fixedNow);
      expect(await jar.cookieHeaderFor(uri), 'session=new');

      await jar.storeFromResponse(uri, _setCookies(<String>['session=gone; Max-Age=0; Path=/']));
      expect(await jar.cookieHeaderFor(uri), isNull);
    });

    test('enforces Secure and retains HttpOnly as storage metadata', () async {
      final jar = AlphaXCookieJar();
      await jar.storeFromResponse(
        uri,
        _setCookies(<String>['secure=1; Secure; HttpOnly']),
        now: fixedNow,
      );

      expect(await jar.cookieHeaderFor(Uri.http('example.com', '/')), isNull);
      expect(await jar.cookieHeaderFor(uri), 'secure=1');
      expect(jar.cookies.single.httpOnly, isTrue);
    });

    test('serializes concurrent Set-Cookie updates', () async {
      final jar = AlphaXCookieJar();
      await Future.wait(<Future<void>>[
        jar.storeFromResponse(uri, _setCookies(<String>['session=first; Path=/'])),
        jar.storeFromResponse(uri, _setCookies(<String>['session=second; Path=/'])),
      ]);

      expect(await jar.cookieHeaderFor(uri), 'session=second');
    });

    test('clear supports logout and removes every cookie', () async {
      final jar = AlphaXCookieJar();
      await jar.storeFromResponse(uri, _setCookies(<String>['session=secret; Path=/']));
      await jar.clear();

      expect(await jar.cookieHeaderFor(uri), isNull);
      expect(jar.cookies, isEmpty);
    });

    test('surfaces asynchronous store failures without leaking credentials', () async {
      final transport = _ContractTransport(
        (_, __) async => AlphaXResponse(
          statusCode: 200,
          headers: _setCookies(<String>['session=secret-cookie-value; Path=/']),
        ),
      );
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[AlphaXCookieMiddleware(_FailingCookieStore())],
      );

      Object? error;
      try {
        await client.get(uri);
      } catch (caught) {
        error = caught;
      }
      expect(error, isA<AlphaXTransportException>());
      expect(error.toString(), isNot(contains('secret-cookie-value')));
    });

    test('surfaces asynchronous cookie read failures', () async {
      final client = AlphaXClient(
        transport: _ContractTransport(
          (_, __) async => AlphaXResponse(statusCode: 200),
        ),
        middleware: <AlphaXMiddleware>[
          AlphaXCookieMiddleware(_FailingCookieStore(failRead: true)),
        ],
      );

      await expectLater(client.get(uri), throwsA(isA<AlphaXTransportException>()));
    });
  });

  group('variant-aware private cache', () {
    test('keys entries by method and URI', () async {
      final store = AlphaXMemoryCacheStore();
      await store.write(_entry(uri: uri, method: HttpMethod.get));

      expect(await store.read(AlphaXCacheKey(method: HttpMethod.get, uri: uri)), isNotNull);
      expect(await store.read(AlphaXCacheKey(method: HttpMethod.head, uri: uri)), isNull);
    });

    test('keeps Accept-Language and Accept variants separate', () async {
      final transport = _ContractTransport((request, _) async {
        final language = request.headers['accept-language'] ?? 'none';
        final accept = request.headers['accept'] ?? 'none';
        return AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{
            'cache-control': 'max-age="60", private',
            'vary': 'Accept-Language, Accept',
          }),
          bodyBytes: utf8.encode('$language:$accept'),
        );
      });
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );

      final english = await client.get(
        uri,
        headers: _headers(<String, String>{
          'accept-language': 'en',
          'accept': 'application/json',
        }),
      );
      final french = await client.get(
        uri,
        headers: _headers(<String, String>{
          'accept-language': 'fr',
          'accept': 'application/json',
        }),
      );
      final englishAgain = await client.get(
        uri,
        headers: _headers(<String, String>{
          'accept-language': 'en',
          'accept': 'application/json',
        }),
      );

      expect(await english.readAsString(), 'en:application/json');
      expect(await french.readAsString(), 'fr:application/json');
      expect(await englishAgain.readAsString(), 'en:application/json');
      expect(transport.requests, hasLength(2));
    });

    test('does not reuse Vary star responses', () async {
      final transport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'max-age=60', 'vary': '*'}),
          bodyBytes: <int>[call],
        ),
      );
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );

      await client.get(uri);
      await client.get(uri);

      expect(transport.requests, hasLength(2));
    });

    test('handles quoted Cache-Control max-age and private responses', () async {
      final transport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{
            'cache-control': 'max-age="60", private',
          }),
          bodyBytes: <int>[call],
        ),
      );
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );

      await client.get(uri);
      await client.get(uri);

      expect(transport.requests, hasLength(1));
    });

    test('does not store no-store or no-cache responses for direct reuse', () async {
      final noStoreTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'no-store'}),
          bodyBytes: <int>[call],
        ),
      );
      final noStoreClient = AlphaXClient(
        transport: noStoreTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );
      await noStoreClient.get(uri);
      await noStoreClient.get(uri);
      expect(noStoreTransport.requests, hasLength(2));

      final noCacheTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'no-cache, max-age=60'}),
          bodyBytes: <int>[call],
        ),
      );
      final noCacheClient = AlphaXClient(
        transport: noCacheTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );
      await noCacheClient.get(uri);
      await noCacheClient.get(uri);
      expect(noCacheTransport.requests, hasLength(2));
    });

    test('uses Age conservatively and supports Expires freshness', () async {
      final ageTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{
            'cache-control': 'max-age=60',
            'age': '3600',
          }),
          bodyBytes: <int>[call],
        ),
      );
      final ageClient = AlphaXClient(
        transport: ageTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );
      await ageClient.get(uri);
      await ageClient.get(uri);
      expect(ageTransport.requests, hasLength(2));

      final expiresTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{
            'date': 'Sun, 06 Nov 2099 08:49:37 GMT',
            'expires': 'Sun, 06 Nov 2099 09:49:37 GMT',
          }),
          bodyBytes: <int>[call],
        ),
      );
      final expiresClient = AlphaXClient(
        transport: expiresTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );
      await expiresClient.get(uri);
      await expiresClient.get(uri);
      expect(expiresTransport.requests, hasLength(1));
    });

    test('uses s-maxage only for an explicitly shared cache', () async {
      final transport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'max-age=0, s-maxage=60'}),
          bodyBytes: <int>[call],
        ),
      );
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(
            store: AlphaXMemoryCacheStore(),
            policy: const AlphaXCachePolicy(scope: AlphaXCacheScope.shared),
          ),
        ],
      );

      await client.get(uri);
      await client.get(uri);

      expect(transport.requests, hasLength(1));
    });

    test('revalidates ETag and merges 304 metadata', () async {
      final transport = _ContractTransport((request, call) async {
        if (call == 1) {
          return AlphaXResponse(
            statusCode: 200,
            headers: _headers(<String, String>{
              'cache-control': 'max-age=0',
              'etag': 'old',
              'date': 'Sun, 06 Nov 2099 08:49:37 GMT',
            }),
            bodyBytes: utf8.encode('cached'),
          );
        }
        if (call == 2) {
          expect(request.headers['if-none-match'], 'old');
          return AlphaXResponse(
            statusCode: 304,
            headers: _headers(<String, String>{
              'cache-control': 'max-age=60',
              'etag': 'new',
              'date': 'Sun, 06 Nov 2099 08:49:37 GMT',
            }),
          );
        }
        fail('The refreshed entry should be served from cache');
      });
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );

      final first = await client.get(uri);
      final second = await client.get(uri);
      final third = await client.get(uri);

      expect(await first.readAsString(), 'cached');
      expect(await second.readAsString(), 'cached');
      expect(second.headers['etag'], 'new');
      expect(await third.readAsString(), 'cached');
      expect(transport.requests, hasLength(2));
    });

    test('revalidates Last-Modified when no ETag exists', () async {
      final transport = _ContractTransport((request, call) async {
        if (call == 1) {
          return AlphaXResponse(
            statusCode: 200,
            headers: _headers(<String, String>{
              'cache-control': 'max-age=0',
              'last-modified': 'Sun, 06 Nov 2099 08:49:37 GMT',
            }),
            bodyBytes: utf8.encode('cached'),
          );
        }
        expect(request.headers['if-modified-since'], 'Sun, 06 Nov 2099 08:49:37 GMT');
        return AlphaXResponse(
          statusCode: 304,
          headers: _headers(<String, String>{'cache-control': 'max-age=60'}),
        );
      });
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );

      await client.get(uri);
      await client.get(uri);

      expect(transport.requests, hasLength(2));
    });

    test('bypasses credentials by default and separates explicit identities', () async {
      final defaultTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'max-age=60'}),
          bodyBytes: <int>[call],
        ),
      );
      final defaultClient = AlphaXClient(
        transport: defaultTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );
      await defaultClient.get(
        uri,
        headers: _headers(<String, String>{'authorization': 'Bearer a'}),
      );
      await defaultClient.get(
        uri,
        headers: _headers(<String, String>{'authorization': 'Bearer b'}),
      );
      expect(defaultTransport.requests, hasLength(2));

      final cookieTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'max-age=60'}),
          bodyBytes: <int>[call],
        ),
      );
      final cookieClient = AlphaXClient(
        transport: cookieTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );
      await cookieClient.get(
        uri,
        headers: _headers(<String, String>{'cookie': 'session=a'}),
      );
      await cookieClient.get(
        uri,
        headers: _headers(<String, String>{'cookie': 'session=b'}),
      );
      expect(cookieTransport.requests, hasLength(2));

      final store = AlphaXMemoryCacheStore();
      final identityTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'max-age=60'}),
          bodyBytes: <int>[call],
        ),
      );
      final userA = AlphaXClient(
        transport: identityTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(
            store: store,
            policy: const AlphaXCachePolicy(identityKey: 'user-a'),
          ),
        ],
      );
      final userB = AlphaXClient(
        transport: identityTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(
            store: store,
            policy: const AlphaXCachePolicy(identityKey: 'user-b'),
          ),
        ],
      );
      await userA.get(uri, headers: _headers(<String, String>{'authorization': 'Bearer a'}));
      await userB.get(uri, headers: _headers(<String, String>{'authorization': 'Bearer b'}));
      expect(identityTransport.requests, hasLength(2));

      final varyAuthorizationTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{
            'cache-control': 'max-age=60',
            'vary': 'Authorization',
          }),
          bodyBytes: <int>[call],
        ),
      );
      final varyAuthorizationClient = AlphaXClient(
        transport: varyAuthorizationTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(
            store: AlphaXMemoryCacheStore(),
            policy: const AlphaXCachePolicy(identityKey: 'user-a'),
          ),
        ],
      );
      await varyAuthorizationClient.get(
        uri,
        headers: _headers(<String, String>{'authorization': 'Bearer a'}),
      );
      await varyAuthorizationClient.get(
        uri,
        headers: _headers(<String, String>{'authorization': 'Bearer a'}),
      );
      expect(varyAuthorizationTransport.requests, hasLength(2));
    });

    test('does not cache responses that set cookies', () async {
      final transport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _setCookies(<String>[
            'session=$call; Path=/',
          ]).set('cache-control', 'max-age=60'),
          bodyBytes: <int>[call],
        ),
      );
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );

      await client.get(uri);
      await client.get(uri);

      expect(transport.requests, hasLength(2));
    });

    test('enforces private and public behavior for a shared scope', () async {
      final privateTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'private, max-age=60'}),
          bodyBytes: <int>[call],
        ),
      );
      final privateClient = AlphaXClient(
        transport: privateTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(
            store: AlphaXMemoryCacheStore(),
            policy: const AlphaXCachePolicy(scope: AlphaXCacheScope.shared),
          ),
        ],
      );
      await privateClient.get(uri);
      await privateClient.get(uri);
      expect(privateTransport.requests, hasLength(2));

      final publicTransport = _ContractTransport(
        (_, call) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'public, max-age=60'}),
          bodyBytes: <int>[call],
        ),
      );
      final publicClient = AlphaXClient(
        transport: publicTransport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(
            store: AlphaXMemoryCacheStore(),
            policy: const AlphaXCachePolicy(scope: AlphaXCacheScope.shared),
          ),
        ],
      );
      await publicClient.get(uri);
      await publicClient.get(uri);
      expect(publicTransport.requests, hasLength(1));
    });

    test('invalidates GET and HEAD variants after every mutation method', () async {
      for (final method in <HttpMethod>[
        HttpMethod.post,
        HttpMethod.put,
        HttpMethod.patch,
        HttpMethod.delete,
      ]) {
        final transport = _ContractTransport((request, call) async {
          if (request.method == method) {
            return AlphaXResponse(statusCode: 204);
          }
          return AlphaXResponse(
            statusCode: 200,
            headers: _headers(<String, String>{'cache-control': 'max-age=60'}),
            bodyBytes: <int>[call],
          );
        });
        final client = AlphaXClient(
          transport: transport,
          middleware: <AlphaXMiddleware>[
            AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
          ],
        );

        await client.get(uri);
        await client.get(uri);
        await client.send(AlphaXRequest(method: method, uri: uri));
        await client.get(uri);

        expect(transport.requests, hasLength(3), reason: method.value);
      }
    });

    test('does not repopulate a mutation-invalidated entry from an in-flight GET', () async {
      final requestStarted = Completer<void>();
      final releaseGet = Completer<void>();
      final transport = _ContractTransport((request, call) async {
        if (request.method == HttpMethod.get && call == 1) {
          requestStarted.complete();
          await releaseGet.future;
          return AlphaXResponse(
            statusCode: 200,
            headers: _headers(<String, String>{'cache-control': 'max-age=60'}),
            bodyBytes: utf8.encode('stale-get'),
          );
        }
        if (request.method == HttpMethod.post) {
          return AlphaXResponse(statusCode: 204);
        }
        return AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'max-age=60'}),
          bodyBytes: utf8.encode('fresh-get'),
        );
      });
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: AlphaXMemoryCacheStore()),
        ],
      );

      final get = client.get(uri);
      await requestStarted.future;
      await client.post(uri);
      releaseGet.complete();
      expect(await (await get).readAsString(), 'stale-get');

      final followUp = await client.get(uri);
      expect(await followUp.readAsString(), 'fresh-get');
      expect(transport.requests, hasLength(3));
    });

    test('keeps the in-memory cache bounded and skips oversized entries', () async {
      final store = AlphaXMemoryCacheStore(maxEntries: 2, maxBytes: 3);
      await store.write(_entry(uri: Uri.https('example.com', '/one'), bodyBytes: <int>[1, 2]));
      await store.write(_entry(uri: Uri.https('example.com', '/two'), bodyBytes: <int>[3, 4]));
      await store.write(_entry(uri: Uri.https('example.com', '/three'), bodyBytes: <int>[5]));

      expect(store.length, 2);
      expect(store.totalBytes, 3);
      await store.write(
        _entry(uri: Uri.https('example.com', '/large'), bodyBytes: <int>[1, 2, 3, 4]),
      );
      expect(
        await store.read(
          AlphaXCacheKey(method: HttpMethod.get, uri: Uri.https('example.com', '/large')),
        ),
        isNull,
      );
    });

    test('mutation removal clears variants across identity scopes', () async {
      final store = AlphaXMemoryCacheStore();
      await store.write(_entry(uri: uri, identityKey: 'user-a'));
      await store.write(_entry(uri: uri, identityKey: 'user-b'));

      await store.remove(AlphaXCacheKey(method: HttpMethod.get, uri: uri));

      expect(
        await store.read(
          AlphaXCacheKey(method: HttpMethod.get, uri: uri, identityKey: 'user-a'),
        ),
        isNull,
      );
      expect(
        await store.read(
          AlphaXCacheKey(method: HttpMethod.get, uri: uri, identityKey: 'user-b'),
        ),
        isNull,
      );
    });

    test('serializes custom async store writes without losing variants', () async {
      final store = _DelayedCacheStore();
      final transport = _ContractTransport((request, _) async {
        final language = request.headers['accept-language']!;
        return AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{
            'cache-control': 'max-age=60',
            'vary': 'Accept-Language',
          }),
          bodyBytes: utf8.encode(language),
        );
      });
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[AlphaXCacheMiddleware(store: store)],
      );

      await Future.wait(<Future<AlphaXResponse>>[
        client.get(uri, headers: _headers(<String, String>{'accept-language': 'en'})),
        client.get(uri, headers: _headers(<String, String>{'accept-language': 'fr'})),
      ]);

      expect(
        await store.read(
          AlphaXCacheKey(
            method: HttpMethod.get,
            uri: uri,
            requestHeaders: <String, String>{'accept-language': 'en'},
          ),
        ),
        isNotNull,
      );
      expect(
        await store.read(
          AlphaXCacheKey(
            method: HttpMethod.get,
            uri: uri,
            requestHeaders: <String, String>{'accept-language': 'fr'},
          ),
        ),
        isNotNull,
      );
    });

    test('surfaces custom store failures', () async {
      final transport = _ContractTransport(
        (_, __) async => AlphaXResponse(
          statusCode: 200,
          headers: _headers(<String, String>{'cache-control': 'max-age=60'}),
        ),
      );
      final client = AlphaXClient(
        transport: transport,
        middleware: <AlphaXMiddleware>[
          AlphaXCacheMiddleware(store: _FailingCacheStore()),
        ],
      );

      await expectLater(client.get(uri), throwsA(isA<StateError>()));
    });
  });

  test('parses HTTP-date Retry-After without expanding retry policy', () {
    final policy = AlphaXRetryPolicy(
      initialDelay: const Duration(seconds: 1),
      maxDelay: const Duration(seconds: 5),
    );
    final response = AlphaXResponse(
      statusCode: 503,
      headers: _headers(<String, String>{'retry-after': 'Sun, 06 Nov 2099 08:49:37 GMT'}),
    );

    expect(
      policy.delayFor(retryNumber: 1, response: response, error: null),
      const Duration(seconds: 5),
    );
  });
}
