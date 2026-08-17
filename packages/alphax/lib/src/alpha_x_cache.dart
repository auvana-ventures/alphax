import 'alpha_x_headers.dart';
import 'alpha_x_http_date.dart';
import 'alpha_x_method.dart';
import 'alpha_x_metrics.dart';
import 'alpha_x_middleware.dart';
import 'alpha_x_policy_helpers.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_redirect.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';

/// Scope used when interpreting private/public cache directives.
enum AlphaXCacheScope {
  /// A cache owned by one AlphaX client or application session.
  private,

  /// A caller-owned shared cache with intermediary-like responsibilities.
  shared,
}

/// Method, URI, request-variant, and optional identity key for a cache entry.
///
/// A lookup key contains the request header values available for `Vary`
/// matching. A stored entry retains only the values selected by its response's
/// `Vary` header. The built-in middleware never places authorization, cookie,
/// or proxy-authorization values in this map.
final class AlphaXCacheKey {
  /// Creates a variant-aware cache key.
  AlphaXCacheKey({
    required this.method,
    required this.uri,
    Map<String, String> requestHeaders = const <String, String>{},
    this.identityKey,
  }) : requestHeaders = _normalizeRequestHeaders(requestHeaders);

  /// HTTP method.
  final HttpMethod method;

  /// Request URI, including its query parameters.
  final Uri uri;

  /// Header values available to response-variant matching.
  final Map<String, String> requestHeaders;

  /// Opaque caller-provided identity scope for authenticated private caches.
  ///
  /// This value is not a credential. It should be stable for one identity and
  /// changed when the application changes identity. The default middleware
  /// does not set it unless [AlphaXCachePolicy.identityKey] is configured.
  final String? identityKey;
}

/// A transport-neutral cache storage seam.
///
/// [read] must return only an entry whose method, URI, identity scope, and
/// stored response-declared `Vary` fields match [key]. [write] must retain the
/// entry's variant key and serialize concurrent writes. [remove] invalidates
/// every variant for the method and URI in [key]; its request-header and
/// identity values are intentionally ignored for mutation invalidation.
///
/// AlphaX does not provide a persistence implementation. Applications may
/// implement this contract over memory, disk, a database, encrypted storage,
/// or a platform secure store, and must own durability, access control,
/// corruption handling, and encryption decisions.
abstract interface class AlphaXCacheStore {
  /// Reads the matching response variant for [key].
  Future<AlphaXCacheEntry?> read(AlphaXCacheKey key);

  /// Stores [entry], including its variant key and response metadata.
  Future<void> write(AlphaXCacheEntry entry);

  /// Removes all variants for [key]'s method and URI.
  Future<void> remove(AlphaXCacheKey key);

  /// Clears all entries.
  Future<void> clear();
}

/// A buffered response stored by an AlphaX cache.
final class AlphaXCacheEntry {
  /// Creates a cache entry with response-derived freshness metadata.
  AlphaXCacheEntry({
    required this.key,
    required int statusCode,
    required this.headers,
    required List<int> bodyBytes,
    required DateTime storedAt,
    required Duration freshnessLifetime,
    Duration ageAtStore = Duration.zero,
  }) : statusCode = _validateStatus(statusCode),
       bodyBytes = List<int>.unmodifiable(bodyBytes),
       storedAt = storedAt.toUtc(),
       freshnessLifetime = _nonNegative(freshnessLifetime),
       ageAtStore = _nonNegative(ageAtStore),
       vary = List<String>.unmodifiable(_parseVary(headers)),
       responseDate = parseAlphaXHttpDate(headers['date']),
       requiresRevalidation = _parseCacheControl(headers['cache-control']).contains('no-cache');

  /// The method, URI, request variant, and identity scope of this entry.
  final AlphaXCacheKey key;

  /// Original response status.
  final int statusCode;

  /// Original response headers, including cache metadata and validators.
  final AlphaXHeaders headers;

  /// Buffered response body.
  final List<int> bodyBytes;

  /// Time at which the entry was stored.
  final DateTime storedAt;

  /// Freshness lifetime derived from Cache-Control, Expires, or policy.
  final Duration freshnessLifetime;

  /// Age already accumulated when this response was stored.
  final Duration ageAtStore;

  /// Request-header names selected by the response's Vary header.
  final List<String> vary;

  /// Parsed response Date, when valid.
  final DateTime? responseDate;

  /// Whether the response must be revalidated before reuse.
  final bool requiresRevalidation;

  /// Entity tag used for conditional revalidation.
  String? get etag => headers['etag'];

  /// Last-modified value used for conditional revalidation.
  String? get lastModified => headers['last-modified'];

  /// Whether the response declared `must-revalidate`.
  bool get mustRevalidate =>
      _parseCacheControl(headers['cache-control']).contains('must-revalidate');

  /// Whether the response declared `private`.
  bool get isPrivate => _parseCacheControl(headers['cache-control']).contains('private');

  /// Whether the response declared `public`.
  bool get isPublic => _parseCacheControl(headers['cache-control']).contains('public');

  /// Current apparent age at [now].
  Duration currentAge([DateTime? now]) {
    final current = (now ?? DateTime.now()).toUtc();
    final resident = current.difference(storedAt);
    return ageAtStore + (resident.isNegative ? Duration.zero : resident);
  }

  /// Whether the entry may be served without a network revalidation.
  bool isFresh([DateTime? now]) => !requiresRevalidation && currentAge(now) < freshnessLifetime;

  /// Approximate wall-clock expiration derived from the stored age.
  DateTime get expiresAt {
    final remaining = freshnessLifetime - ageAtStore;
    return storedAt.add(remaining.isNegative ? Duration.zero : remaining);
  }
}

/// Bounded in-memory cache storage.
///
/// Entries are evicted in insertion order when either bound is exceeded.
/// Entries larger than [maxBytes] are ignored rather than allowing one
/// response to defeat the configured memory bound.
final class AlphaXMemoryCacheStore implements AlphaXCacheStore {
  /// Creates an in-memory cache.
  AlphaXMemoryCacheStore({
    this.maxEntries = 100,
    this.maxBytes = 10 * 1024 * 1024,
  }) {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be positive');
    }
    if (maxBytes < 1) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'Must be positive');
    }
  }

  /// Maximum number of variants retained.
  final int maxEntries;

  /// Maximum total body bytes retained.
  final int maxBytes;

  final List<AlphaXCacheEntry> _entries = <AlphaXCacheEntry>[];

  /// Number of currently stored variants.
  int get length => _entries.length;

  /// Total body bytes currently retained.
  int get totalBytes => _entries.fold<int>(0, (total, entry) => total + entry.bodyBytes.length);

  @override
  Future<AlphaXCacheEntry?> read(AlphaXCacheKey key) async {
    for (final entry in _entries.reversed) {
      if (_sameIdentityResource(entry.key, key) && _matchesVariant(entry, key)) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<void> write(AlphaXCacheEntry entry) async {
    if (entry.bodyBytes.length > maxBytes) {
      return;
    }

    final sameIdentity = _entries
        .where((existing) => _sameIdentityResource(existing.key, entry.key))
        .toList(growable: false);
    final incomingVary = entry.vary.toSet();
    if (sameIdentity.any(
      (existing) =>
          existing.vary.toSet().difference(incomingVary).isNotEmpty ||
          incomingVary.difference(existing.vary.toSet()).isNotEmpty,
    )) {
      _entries.removeWhere((existing) => _sameIdentityResource(existing.key, entry.key));
    } else {
      _entries.removeWhere(
        (existing) =>
            _sameIdentityResource(existing.key, entry.key) &&
            existing.vary.toSet().containsAll(incomingVary) &&
            incomingVary.containsAll(existing.vary) &&
            _sameHeaders(existing.key.requestHeaders, entry.key.requestHeaders),
      );
    }

    _entries.add(entry);
    while (_entries.length > maxEntries || totalBytes > maxBytes) {
      _entries.removeAt(0);
    }
  }

  @override
  Future<void> remove(AlphaXCacheKey key) async {
    _entries.removeWhere((entry) => _sameResource(entry.key, key));
  }

  @override
  Future<void> clear() async => _entries.clear();
}

/// Cache behavior for the private HTTP cache middleware.
final class AlphaXCachePolicy {
  /// Creates cache behavior.
  const AlphaXCachePolicy({
    this.defaultMaxAge = const Duration(minutes: 5),
    this.revalidateStale = true,
    this.scope = AlphaXCacheScope.private,
    this.identityKey,
  });

  /// Freshness used when a response has no explicit freshness directive.
  final Duration defaultMaxAge;

  /// Whether stale entries with validators should be conditionally revalidated.
  final bool revalidateStale;

  /// Whether the store is private to an application/client or intentionally shared.
  final AlphaXCacheScope scope;

  /// Stable, non-secret identity scope for credentialed private responses.
  ///
  /// Requests carrying `Authorization` or `Cookie` bypass the cache unless
  /// this value is configured. The application must change the value or clear
  /// the store when the authenticated identity changes.
  final String? identityKey;
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

  Future<void> _storeTail = Future<void>.value();
  int _invalidationGeneration = 0;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    if (request.method != HttpMethod.get && request.method != HttpMethod.head) {
      if (_isMutation(request.method)) {
        _invalidationGeneration++;
        await _invalidate(request.uri);
      }
      return next(request);
    }

    final requestDirectives = _parseCacheControl(request.headers['cache-control']);
    if (requestDirectives.contains('no-store') ||
        request.protocolRequirement != null ||
        !_requestMayUseCache(request)) {
      return next(request);
    }

    // A cached response cannot prove that this operation negotiated the
    // required protocol. Let the transport perform the request so a concrete
    // completion-time protocol can satisfy (or reject) the requirement.
    final requestGeneration = _invalidationGeneration;
    await _storeTail;
    final lookupKey = _lookupKey(request);
    final cached = await store.read(lookupKey);
    final now = DateTime.now().toUtc();
    final requestForcesRevalidation =
        requestDirectives.contains('no-cache') || _maxAge(requestDirectives) == Duration.zero;
    if (cached != null && cached.isFresh(now) && !requestForcesRevalidation) {
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
    final responseTime = DateTime.now().toUtc();
    final invalidatedWhileInFlight = requestGeneration != _invalidationGeneration;
    if (response.statusCode == 304 && cached != null) {
      await drainAlphaXResponse(response);
      final merged = _mergeHeaders(cached.headers, response.headers);
      final refreshed = _entryFromResponse(
        request: request,
        response: AlphaXResponse(
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
        now: responseTime,
        bodyBytes: cached.bodyBytes,
      );
      if (refreshed != null) {
        if (!invalidatedWhileInFlight) {
          await _enqueueStore(() => store.write(refreshed));
        }
        return _responseFromEntry(refreshed, response: response, request: request);
      }
      await _invalidate(request.uri);
      return _responseFromEntry(cached, response: response, request: request);
    }

    final entry = await _entryFromResponseAsync(request, response, responseTime);
    if (entry != null && !invalidatedWhileInFlight) {
      await _enqueueStore(() => store.write(entry));
      return _responseFromEntry(entry, response: response, request: request);
    }
    return response;
  }

  Future<AlphaXCacheEntry?> _entryFromResponseAsync(
    AlphaXRequest request,
    AlphaXResponse response,
    DateTime now,
  ) async {
    if (!_isResponseStorable(request, response)) {
      return null;
    }
    final bytes = response.body.bufferedBytes ?? await response.body.readAsBytes();
    return _entryFromResponse(request: request, response: response, now: now, bodyBytes: bytes);
  }

  AlphaXCacheEntry? _entryFromResponse({
    required AlphaXRequest request,
    required AlphaXResponse response,
    required DateTime now,
    required List<int> bodyBytes,
  }) {
    if (!_isResponseStorable(request, response)) {
      return null;
    }
    final directives = _parseCacheControl(response.headers['cache-control']);
    final metadata = _cacheMetadata(
      response.headers,
      directives,
      now,
      defaultMaxAge: policy.defaultMaxAge,
      scope: policy.scope,
    );
    return AlphaXCacheEntry(
      key: _storedKey(request, _parseVary(response.headers)),
      statusCode: response.statusCode,
      headers: response.headers,
      bodyBytes: bodyBytes,
      storedAt: now,
      freshnessLifetime: metadata.freshnessLifetime,
      ageAtStore: metadata.ageAtStore,
    );
  }

  bool _requestMayUseCache(AlphaXRequest request) {
    if (request.headers.contains('proxy-authorization')) {
      return false;
    }
    return !_hasApplicationCredentials(request) || policy.identityKey != null;
  }

  bool _isResponseStorable(AlphaXRequest request, AlphaXResponse response) {
    if (!_isCacheableStatus(response.statusCode)) {
      return false;
    }
    final directives = _parseCacheControl(response.headers['cache-control']);
    final vary = _parseVary(response.headers);
    if (directives.contains('no-store') ||
        vary.contains('*') ||
        _hasSensitiveVary(vary) ||
        response.headers.contains('set-cookie')) {
      return false;
    }
    if (policy.scope == AlphaXCacheScope.shared && directives.contains('private')) {
      return false;
    }
    if (_hasApplicationCredentials(request)) {
      if (policy.identityKey == null) {
        return false;
      }
      if (policy.scope == AlphaXCacheScope.shared &&
          !directives.contains('public') &&
          !directives.contains('must-revalidate') &&
          directives['s-maxage'] == null) {
        return false;
      }
    }
    return true;
  }

  bool _isCacheableStatus(int statusCode) => switch (statusCode) {
    200 || 203 || 204 || 300 || 301 || 404 || 410 => true,
    _ => false,
  };

  bool _isMutation(HttpMethod method) => switch (method) {
    HttpMethod.post || HttpMethod.put || HttpMethod.patch || HttpMethod.delete => true,
    HttpMethod.get || HttpMethod.head || HttpMethod.options => false,
  };

  AlphaXCacheKey _lookupKey(AlphaXRequest request) => AlphaXCacheKey(
    method: request.method,
    uri: request.uri,
    requestHeaders: _safeRequestHeaders(request.headers),
    identityKey: _hasApplicationCredentials(request) ? policy.identityKey : null,
  );

  AlphaXCacheKey _storedKey(AlphaXRequest request, List<String> vary) => AlphaXCacheKey(
    method: request.method,
    uri: request.uri,
    requestHeaders: {
      for (final name in vary)
        if (_safeRequestHeaders(request.headers).containsKey(name))
          name: _safeRequestHeaders(request.headers)[name]!,
    },
    identityKey: _hasApplicationCredentials(request) ? policy.identityKey : null,
  );

  Future<void> _invalidate(Uri uri) => _enqueueStore(() async {
    await store.remove(AlphaXCacheKey(method: HttpMethod.get, uri: uri));
    await store.remove(AlphaXCacheKey(method: HttpMethod.head, uri: uri));
  });

  Future<void> _enqueueStore(Future<void> Function() operation) {
    final result = _storeTail.then<void>((_) => operation());
    _storeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

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

  AlphaXHeaders _mergeHeaders(AlphaXHeaders cached, AlphaXHeaders update) {
    var merged = cached;
    for (final entry in update.entries) {
      merged = merged.set(entry.key, entry.value);
    }
    return merged;
  }
}

final class _AlphaXCacheMetadata {
  const _AlphaXCacheMetadata({required this.freshnessLifetime, required this.ageAtStore});

  final Duration freshnessLifetime;
  final Duration ageAtStore;
}

final class _AlphaXCacheControl {
  const _AlphaXCacheControl(this.values);

  final Map<String, String?> values;

  bool contains(String name) => values.containsKey(name);

  String? operator [](String name) => values[name];
}

_AlphaXCacheMetadata _cacheMetadata(
  AlphaXHeaders headers,
  _AlphaXCacheControl directives,
  DateTime now, {
  required Duration defaultMaxAge,
  required AlphaXCacheScope scope,
}) {
  final date = parseAlphaXHttpDate(headers['date']);
  final ageAtStore = _durationFromSeconds(headers['age']) ?? Duration.zero;
  final apparentAge = date == null ? Duration.zero : now.difference(date);
  final correctedAge = _maxDuration(
    ageAtStore,
    apparentAge.isNegative ? Duration.zero : apparentAge,
  );
  final maxAge = scope == AlphaXCacheScope.shared
      ? _durationDirective(directives, 's-maxage') ?? _durationDirective(directives, 'max-age')
      : _durationDirective(directives, 'max-age');
  final expires = parseAlphaXHttpDate(headers['expires']);
  final expiresLifetime = expires == null
      ? null
      : expires.difference(date ?? now).isNegative
      ? Duration.zero
      : expires.difference(date ?? now);
  return _AlphaXCacheMetadata(
    freshnessLifetime: maxAge ?? expiresLifetime ?? _nonNegative(defaultMaxAge),
    ageAtStore: correctedAge,
  );
}

_AlphaXCacheControl _parseCacheControl(String? header) {
  if (header == null || header.trim().isEmpty) {
    return const _AlphaXCacheControl(<String, String?>{});
  }
  final values = <String, String?>{};
  final parts = <String>[];
  final current = StringBuffer();
  var quoted = false;
  for (var index = 0; index < header.length; index++) {
    final character = header[index];
    if (character == '"') {
      quoted = !quoted;
    }
    if (character == ',' && !quoted) {
      parts.add(current.toString());
      current.clear();
    } else {
      current.write(character);
    }
  }
  parts.add(current.toString());

  for (final part in parts) {
    final separator = part.indexOf('=');
    final name = (separator < 0 ? part : part.substring(0, separator)).trim().toLowerCase();
    if (name.isEmpty) {
      continue;
    }
    final rawValue = separator < 0 ? null : part.substring(separator + 1).trim();
    values[name] = rawValue == null ? null : _unquote(rawValue);
  }
  return _AlphaXCacheControl(Map<String, String?>.unmodifiable(values));
}

String _unquote(String value) {
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    return value.substring(1, value.length - 1).replaceAll(r'\"', '"');
  }
  return value;
}

List<String> _parseVary(AlphaXHeaders headers) {
  final fields = <String>{};
  for (final value in headers.values('vary')) {
    for (final field in value.split(',')) {
      final normalized = field.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        fields.add(normalized);
      }
    }
  }
  final result = fields.toList()..sort();
  return result;
}

bool _hasSensitiveVary(Iterable<String> vary) => vary.any(
  (field) => switch (field) {
    'authorization' || 'proxy-authorization' || 'cookie' || 'set-cookie' => true,
    _ => false,
  },
);

Duration? _durationDirective(_AlphaXCacheControl directives, String name) {
  final value = directives[name];
  if (value == null) {
    return directives.contains(name) ? Duration.zero : null;
  }
  final seconds = int.tryParse(value);
  if (seconds == null || seconds < 0) {
    return Duration.zero;
  }
  return Duration(seconds: seconds);
}

Duration? _durationFromSeconds(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final seconds = int.tryParse(value.trim());
  if (seconds == null || seconds < 0) {
    return Duration.zero;
  }
  return Duration(seconds: seconds);
}

Duration? _maxAge(_AlphaXCacheControl directives) => _durationDirective(directives, 'max-age');

Map<String, String> _normalizeRequestHeaders(Map<String, String> values) {
  final normalized = AlphaXHeaders(values).toMap();
  final entries = normalized.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return Map<String, String>.unmodifiable(Map<String, String>.fromEntries(entries));
}

Map<String, String> _safeRequestHeaders(AlphaXHeaders headers) => {
  for (final entry in headers.toMap().entries)
    if (entry.key != 'authorization' && entry.key != 'proxy-authorization' && entry.key != 'cookie')
      entry.key: entry.value,
};

bool _hasApplicationCredentials(AlphaXRequest request) =>
    request.headers.contains('authorization') || request.headers.contains('cookie');

bool _sameResource(AlphaXCacheKey first, AlphaXCacheKey second) =>
    first.method == second.method && first.uri == second.uri;

bool _sameIdentityResource(AlphaXCacheKey first, AlphaXCacheKey second) =>
    first.method == second.method &&
    first.uri == second.uri &&
    first.identityKey == second.identityKey;

bool _matchesVariant(AlphaXCacheEntry entry, AlphaXCacheKey request) {
  if (entry.vary.contains('*') || !_sameIdentityResource(entry.key, request)) {
    return false;
  }
  for (final field in entry.vary) {
    if ((entry.key.requestHeaders[field] ?? '') != (request.requestHeaders[field] ?? '')) {
      return false;
    }
  }
  return true;
}

bool _sameHeaders(Map<String, String> first, Map<String, String> second) {
  if (first.length != second.length) {
    return false;
  }
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

Duration _maxDuration(Duration first, Duration second) => first >= second ? first : second;

Duration _nonNegative(Duration value) => value.isNegative ? Duration.zero : value;

int _validateStatus(int statusCode) {
  if (statusCode < 100 || statusCode > 599) {
    throw ArgumentError.value(statusCode, 'statusCode', 'Status code must be between 100 and 599');
  }
  return statusCode;
}
