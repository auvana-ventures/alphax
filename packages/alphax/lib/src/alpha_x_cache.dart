import 'alpha_x_headers.dart';
import 'alpha_x_method.dart';
import 'alpha_x_metrics.dart';
import 'alpha_x_middleware.dart';
import 'alpha_x_policy_helpers.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_redirect.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';

/// Storage contract for transport-neutral cached responses.
abstract interface class AlphaXCacheStore {
  /// Reads an entry for [uri].
  Future<AlphaXCacheEntry?> read(Uri uri);

  /// Stores [entry] for [uri].
  Future<void> write(Uri uri, AlphaXCacheEntry entry);

  /// Removes an entry.
  Future<void> remove(Uri uri);

  /// Clears all entries.
  Future<void> clear();
}

/// A buffered response stored by an AlphaX cache.
final class AlphaXCacheEntry {
  /// Creates a cache entry.
  AlphaXCacheEntry({
    required this.statusCode,
    required this.headers,
    required List<int> bodyBytes,
    required this.storedAt,
    required this.expiresAt,
  }) : bodyBytes = List<int>.unmodifiable(bodyBytes);

  /// Original response status.
  final int statusCode;

  /// Original response headers.
  final AlphaXHeaders headers;

  /// Buffered response body.
  final List<int> bodyBytes;

  /// Time at which the entry was stored.
  final DateTime storedAt;

  /// Time at which the entry becomes stale.
  final DateTime expiresAt;

  /// Entity tag used for conditional revalidation.
  String? get etag => headers['etag'];

  /// Last-modified value used for conditional revalidation.
  String? get lastModified => headers['last-modified'];

  /// Whether the entry is fresh at [now].
  bool isFresh([DateTime? now]) => (now ?? DateTime.now()).isBefore(expiresAt);
}

/// Bounded in-memory cache storage.
final class AlphaXMemoryCacheStore implements AlphaXCacheStore {
  /// Creates an in-memory cache.
  AlphaXMemoryCacheStore({this.maxEntries = 100}) {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be positive');
    }
  }

  /// Maximum number of entries retained.
  final int maxEntries;
  final Map<Uri, AlphaXCacheEntry> _entries = <Uri, AlphaXCacheEntry>{};

  /// Number of currently stored entries.
  int get length => _entries.length;

  @override
  Future<AlphaXCacheEntry?> read(Uri uri) async => _entries[uri];

  @override
  Future<void> write(Uri uri, AlphaXCacheEntry entry) async {
    _entries.remove(uri);
    while (_entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _entries[uri] = entry;
  }

  @override
  Future<void> remove(Uri uri) async => _entries.remove(uri);

  @override
  Future<void> clear() async => _entries.clear();
}

/// Cache behavior for the in-memory HTTP cache middleware.
final class AlphaXCachePolicy {
  /// Creates cache behavior.
  const AlphaXCachePolicy({
    this.defaultMaxAge = const Duration(minutes: 5),
    this.revalidateStale = true,
  });

  /// Freshness used when a response does not provide an explicit freshness
  /// directive.
  final Duration defaultMaxAge;

  /// Whether stale entries with validators should be revalidated.
  final bool revalidateStale;
}

/// Buffered HTTP cache middleware for GET and HEAD operations.
final class AlphaXCacheMiddleware extends AlphaXMiddleware {
  /// Creates cache middleware.
  AlphaXCacheMiddleware({
    required this.store,
    this.policy = const AlphaXCachePolicy(),
  });

  /// Cache store.
  final AlphaXCacheStore store;

  /// Cache behavior.
  final AlphaXCachePolicy policy;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    if (request.method != HttpMethod.get && request.method != HttpMethod.head) {
      await store.remove(request.uri);
      return next(request);
    }

    final requestDirectives = _directives(request.headers['cache-control']);
    if (requestDirectives.contains('no-store')) {
      return next(request);
    }

    // A cached response cannot prove that this operation negotiated the
    // required protocol. Let the transport perform the request so a concrete
    // completion-time protocol can satisfy (or reject) the requirement.
    if (request.protocolRequirement != null) {
      return next(request);
    }

    final cached = await store.read(request.uri);
    final now = DateTime.now();
    if (cached != null && cached.isFresh(now) && !requestDirectives.contains('no-cache')) {
      return _responseFromEntry(cached, request: request);
    }

    var effectiveRequest = request;
    if (cached != null && policy.revalidateStale) {
      if (cached.etag != null && !request.headers.contains('if-none-match')) {
        effectiveRequest = effectiveRequest.copyWith(
          headers: effectiveRequest.headers.set('if-none-match', cached.etag!),
        );
      } else if (cached.lastModified != null && !request.headers.contains('if-modified-since')) {
        effectiveRequest = effectiveRequest.copyWith(
          headers: effectiveRequest.headers.set('if-modified-since', cached.lastModified!),
        );
      }
    }

    final response = await next(effectiveRequest);
    if (response.statusCode == 304 && cached != null) {
      await drainAlphaXResponse(response);
      final merged = _mergeHeaders(cached.headers, response.headers);
      final refreshed = _entryFromResponse(
        AlphaXResponse(
          statusCode: cached.statusCode,
          headers: merged,
          bodyBytes: cached.bodyBytes,
          protocol: response.protocol,
          requestedProtocol: response.requestedProtocol,
          requiredProtocol: response.requiredProtocol,
          protocolFallback: response.protocolFallback,
          metrics: response.metrics,
          completionMetrics: response.completionMetrics,
          redirects: response.redirects,
        ),
        now,
      );
      if (refreshed != null) {
        await store.write(request.uri, refreshed);
        return _responseFromEntry(refreshed, response: response, request: request);
      }
      return _responseFromEntry(cached, response: response, request: request);
    }

    final entry = await _entryFromResponseAsync(response, now);
    if (entry != null) {
      await store.write(request.uri, entry);
      return _responseFromEntry(entry, response: response, request: request);
    }
    return response;
  }

  Future<AlphaXCacheEntry?> _entryFromResponseAsync(
    AlphaXResponse response,
    DateTime now,
  ) async {
    if (!_isCacheable(response) ||
        _directives(response.headers['cache-control']).contains('no-store')) {
      return null;
    }
    if (response.headers.contains('vary') && response.headers['vary']!.trim() == '*') {
      return null;
    }
    final bytes = response.body.bufferedBytes ?? await response.body.readAsBytes();
    return _entryFromResponse(
      AlphaXResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        bodyBytes: bytes,
        protocol: response.protocol,
        requestedProtocol: response.requestedProtocol,
        requiredProtocol: response.requiredProtocol,
        protocolFallback: response.protocolFallback,
        metrics: response.metrics,
        completionMetrics: response.completionMetrics,
        redirects: response.redirects,
      ),
      now,
    );
  }

  AlphaXCacheEntry? _entryFromResponse(AlphaXResponse response, DateTime now) {
    if (!_isCacheable(response)) {
      return null;
    }
    final directives = _directives(response.headers['cache-control']);
    final maxAge = _maxAge(directives) ?? policy.defaultMaxAge;
    if (maxAge <= Duration.zero) {
      return null;
    }
    return AlphaXCacheEntry(
      statusCode: response.statusCode,
      headers: response.headers,
      bodyBytes: response.body.bufferedBytes ?? const <int>[],
      storedAt: now,
      expiresAt: now.add(maxAge),
    );
  }

  bool _isCacheable(AlphaXResponse response) => switch (response.statusCode) {
    200 || 203 || 204 || 300 || 301 || 404 || 410 => true,
    _ => false,
  };

  AlphaXResponse _responseFromEntry(
    AlphaXCacheEntry entry, {
    AlphaXResponse? response,
    AlphaXRequest? request,
  }) => AlphaXResponse(
    statusCode: entry.statusCode,
    headers: entry.headers,
    bodyBytes: entry.bodyBytes,
    protocol: response?.protocol ?? AlphaXProtocol.unknown,
    requestedProtocol: response?.requestedProtocol ?? request?.protocolPreference,
    requiredProtocol: response?.requiredProtocol,
    protocolFallback: response?.protocolFallback,
    metrics: response?.metrics ?? const AlphaXRequestMetrics(),
    completionMetrics: response?.completionMetrics,
    redirects: response?.redirects ?? const <AlphaXRedirectInfo>[],
  );

  Set<String> _directives(String? header) => header == null
      ? <String>{}
      : header
            .split(',')
            .map((part) => part.trim().toLowerCase())
            .where((part) => part.isNotEmpty)
            .toSet();

  Duration? _maxAge(Set<String> directives) {
    for (final directive in directives) {
      if (!directive.startsWith('max-age=')) {
        continue;
      }
      final seconds = int.tryParse(directive.substring('max-age='.length));
      if (seconds == null || seconds < 0) {
        return Duration.zero;
      }
      return Duration(seconds: seconds);
    }
    return null;
  }

  AlphaXHeaders _mergeHeaders(AlphaXHeaders cached, AlphaXHeaders update) {
    var merged = cached;
    for (final entry in update.entries) {
      merged = merged.set(entry.key, entry.value);
    }
    return merged;
  }
}
