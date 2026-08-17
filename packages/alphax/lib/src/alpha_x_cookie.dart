import 'dart:async';

import 'alpha_x_event.dart';
import 'alpha_x_file.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_http_date.dart';
import 'alpha_x_middleware.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';

/// A transport-neutral HTTP cookie.
final class AlphaXCookie {
  /// Creates a cookie value.
  AlphaXCookie({
    required this.name,
    required this.value,
    required String domain,
    this.path = '/',
    this.expires,
    this.secure = false,
    this.httpOnly = false,
    this.hostOnly = false,
  }) : domain = _normalizeDomain(domain) {
    if (name.isEmpty || name.contains(RegExp(r'[=;\s]'))) {
      throw ArgumentError.value(name, 'name', 'Cookie names must be tokens');
    }
    if (value.contains(RegExp(r'[;\r\n]'))) {
      throw ArgumentError.value(value, 'value', 'Cookie values cannot contain separators');
    }
  }

  /// Cookie name.
  final String name;

  /// Cookie value.
  final String value;

  /// Normalized host/domain scope.
  final String domain;

  /// Path scope.
  final String path;

  /// Absolute expiry, when present.
  final DateTime? expires;

  /// Whether the cookie is sent only over HTTPS.
  final bool secure;

  /// Whether the cookie was marked HttpOnly.
  final bool httpOnly;

  /// Whether the cookie came from a host-only Set-Cookie value.
  final bool hostOnly;

  /// Whether the cookie is expired at [now].
  bool isExpired([DateTime? now]) => expires != null && !expires!.isAfter(now ?? DateTime.now());

  /// Header representation.
  String get headerValue => '$name=$value';

  /// Whether this cookie applies to [uri].
  bool matches(Uri uri, {DateTime? now}) {
    if (isExpired(now) || (secure && uri.scheme != 'https')) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final domainMatches = hostOnly ? host == domain : host == domain || host.endsWith('.$domain');
    if (!domainMatches) {
      return false;
    }
    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    if (requestPath == path) {
      return true;
    }
    return requestPath.startsWith(path.endsWith('/') ? path : '$path/') ||
        (path == '/' && requestPath.startsWith('/'));
  }

  static String _normalizeDomain(String value) {
    final normalized = value.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    if (normalized.isEmpty || normalized.contains(RegExp(r'[\s/]'))) {
      throw ArgumentError.value(value, 'domain', 'Cookie domains must be host names');
    }
    return normalized;
  }
}

/// Asynchronous transport-neutral cookie storage.
///
/// The middleware owns cookie parsing and matching. Stores persist parsed
/// [AlphaXCookie] values through [readCookies] and [writeCookies], so custom
/// storage adapters do not need to reimplement domain, path, expiry, Secure,
/// HttpOnly, host-only, replacement, or deletion rules. Implementations must
/// serialize concurrent writes, preserve the supplied cookie fields, and
/// surface persistence failures. AlphaX does not prescribe a file format,
/// database, encryption mechanism, or secure-storage integration.
abstract interface class AlphaXCookieStore {
  /// Reads the current parsed cookie values.
  Future<List<AlphaXCookie>> readCookies();

  /// Replaces the stored parsed cookie values.
  Future<void> writeCookies(Iterable<AlphaXCookie> cookies);

  /// Atomically transforms the stored parsed cookie values.
  ///
  /// Implementations must serialize this read/transform/write operation with
  /// other updates, including updates made through another client instance
  /// sharing the store. The callback must not retain or mutate [cookies].
  Future<void> updateCookies(
    Iterable<AlphaXCookie> Function(List<AlphaXCookie> cookies) transform,
  );

  /// Clears every cookie in the store.
  Future<void> clear();
}

/// In-memory, host/path-scoped cookie storage.
///
/// This is the default AlphaX implementation. It is intentionally not
/// persistent and can be replaced with a caller-owned secure or durable
/// [AlphaXCookieStore]. Updates are serialized so concurrent responses cannot
/// lose a replacement or deletion.
final class AlphaXCookieJar implements AlphaXCookieStore {
  /// Creates an empty in-memory cookie jar.
  AlphaXCookieJar();

  final List<AlphaXCookie> _cookies = <AlphaXCookie>[];
  Future<void> _writeTail = Future<void>.value();

  /// Current non-expired cookies.
  List<AlphaXCookie> get cookies => List<AlphaXCookie>.unmodifiable(_liveCookies());

  /// Returns the Cookie header for [uri], or `null` when empty.
  Future<String?> cookieHeaderFor(Uri uri, {DateTime? now}) async {
    await _writeTail;
    return _cookieHeaderForCookies(_cookies, uri, now: now);
  }

  /// Stores all Set-Cookie headers from [responseHeaders].
  Future<void> storeFromResponse(
    Uri uri,
    AlphaXHeaders responseHeaders, {
    DateTime? now,
  }) => updateCookies(
    (cookies) => _cookiesAfterResponse(cookies, uri, responseHeaders, now: now),
  );

  /// Reads the parsed cookie values for a custom storage adapter.
  @override
  Future<List<AlphaXCookie>> readCookies() async {
    await _writeTail;
    return List<AlphaXCookie>.unmodifiable(_liveCookies());
  }

  /// Replaces the parsed cookie values.
  @override
  Future<void> writeCookies(Iterable<AlphaXCookie> cookies) => _enqueue(() {
    _cookies
      ..clear()
      ..addAll(cookies);
    _purge(DateTime.now());
  });

  /// Atomically transforms the in-memory cookie list.
  @override
  Future<void> updateCookies(
    Iterable<AlphaXCookie> Function(List<AlphaXCookie> cookies) transform,
  ) => _enqueue(() {
    final updated = transform(List<AlphaXCookie>.from(_liveCookies()));
    _cookies
      ..clear()
      ..addAll(updated);
    _purge(DateTime.now());
  });

  /// Removes all stored cookies.
  @override
  Future<void> clear() => _enqueue(_cookies.clear);

  /// Removes cookies matching [name] and [uri].
  Future<void> remove(String name, Uri uri) =>
      _enqueue(() => _cookies.removeWhere((cookie) => cookie.name == name && cookie.matches(uri)));

  Future<void> _enqueue(void Function() operation) {
    final result = _writeTail.then<void>((_) => operation());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  List<AlphaXCookie> _liveCookies({DateTime? now}) {
    _purge(now ?? DateTime.now());
    return List<AlphaXCookie>.from(_cookies);
  }

  void _purge(DateTime now) => _cookies.removeWhere((cookie) => cookie.isExpired(now));
}

/// Middleware that applies and records cookies for buffered, streamed, and
/// file-transfer operations.
final class AlphaXCookieMiddleware extends AlphaXMiddleware {
  /// Creates cookie middleware backed by [store].
  AlphaXCookieMiddleware(this.store);

  /// Cookie storage used by this middleware.
  final AlphaXCookieStore store;

  Future<void> _storeTail = Future<void>.value();

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    final effectiveRequest = await _withCookies(request);
    final response = await next(effectiveRequest);
    await _recordResponseCookies(request.uri, response.headers);
    return response;
  }

  @override
  Stream<AlphaXEvent> interceptStream(AlphaXRequest request, AlphaXStreamNext next) async* {
    final effectiveRequest = await _withCookies(request);
    await for (final event in next(effectiveRequest)) {
      if (event case AlphaXResponseStarted(:final headers)) {
        await _recordResponseCookies(request.uri, headers);
      }
      yield event;
    }
  }

  @override
  Future<AlphaXTransferResult> interceptDownload(
    AlphaXRequest request,
    AlphaXFileTarget target,
    AlphaXDownloadNext next,
  ) async {
    final result = await next(await _withCookies(request), target);
    await _recordResponseCookies(request.uri, result.headers);
    return result;
  }

  @override
  Future<AlphaXTransferResult> interceptUpload(
    AlphaXRequest request,
    AlphaXFileSource source,
    AlphaXUploadNext next,
  ) async {
    final result = await next(await _withCookies(request), source);
    await _recordResponseCookies(request.uri, result.headers);
    return result;
  }

  Future<AlphaXRequest> _withCookies(AlphaXRequest request) async {
    await _storeTail;
    final cookies = await store.readCookies();
    final cookieHeader = _cookieHeaderForCookies(cookies, request.uri);
    return cookieHeader == null || request.headers.contains('cookie')
        ? request
        : request.copyWith(headers: request.headers.set('cookie', cookieHeader));
  }

  Future<void> _recordResponseCookies(Uri uri, AlphaXHeaders headers) {
    final operation = _storeTail.then<void>((_) async {
      await store.updateCookies((cookies) => _cookiesAfterResponse(cookies, uri, headers));
    });
    _storeTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }
}

String? _cookieHeaderForCookies(
  Iterable<AlphaXCookie> cookies,
  Uri uri, {
  DateTime? now,
}) {
  final values = cookies.where((cookie) => cookie.matches(uri, now: now)).toList(growable: false)
    ..sort((a, b) => b.path.length.compareTo(a.path.length));
  if (values.isEmpty) {
    return null;
  }
  return values.map((cookie) => cookie.headerValue).join('; ');
}

List<AlphaXCookie> _cookiesAfterResponse(
  Iterable<AlphaXCookie> existing,
  Uri uri,
  AlphaXHeaders responseHeaders, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final updated = List<AlphaXCookie>.from(existing);
  for (final header in responseHeaders.values('set-cookie')) {
    final parsed = _parseSetCookie(uri, header, currentTime);
    if (parsed == null) {
      continue;
    }
    updated.removeWhere(
      (cookie) =>
          cookie.name == parsed.name &&
          cookie.domain == parsed.domain &&
          cookie.path == parsed.path,
    );
    if (!parsed.isExpired(currentTime)) {
      updated.add(parsed);
    }
  }
  updated.removeWhere((cookie) => cookie.isExpired(currentTime));
  return updated;
}

AlphaXCookie? _parseSetCookie(Uri uri, String raw, DateTime now) {
  final parts = raw.split(';');
  if (parts.isEmpty) {
    return null;
  }
  final pair = parts.first.trim();
  final separator = pair.indexOf('=');
  if (separator <= 0) {
    return null;
  }
  final name = pair.substring(0, separator).trim();
  final value = pair.substring(separator + 1).trim();
  var domain = uri.host.toLowerCase();
  var hostOnly = true;
  var path = _defaultCookiePath(uri.path);
  DateTime? expires;
  var secure = false;
  var httpOnly = false;
  var deleteCookie = false;

  for (final rawAttribute in parts.skip(1)) {
    final attribute = rawAttribute.trim();
    if (attribute.isEmpty) {
      continue;
    }
    final equals = attribute.indexOf('=');
    final key = (equals < 0 ? attribute : attribute.substring(0, equals)).trim().toLowerCase();
    final attributeValue = equals < 0 ? '' : attribute.substring(equals + 1).trim();
    switch (key) {
      case 'domain':
        final candidate = attributeValue.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
        if (candidate.isEmpty ||
            !(uri.host.toLowerCase() == candidate ||
                uri.host.toLowerCase().endsWith('.$candidate'))) {
          return null;
        }
        domain = candidate;
        hostOnly = false;
        break;
      case 'path':
        if (attributeValue.startsWith('/')) {
          path = attributeValue;
        }
        break;
      case 'max-age':
        final seconds = int.tryParse(attributeValue);
        if (seconds != null) {
          if (seconds <= 0) {
            deleteCookie = true;
          } else {
            expires = now.add(Duration(seconds: seconds));
          }
        }
        break;
      case 'expires':
        expires ??= parseAlphaXHttpDate(attributeValue);
        break;
      case 'secure':
        secure = true;
        break;
      case 'httponly':
        httpOnly = true;
        break;
    }
  }
  if (deleteCookie) {
    expires = now.subtract(const Duration(seconds: 1));
  }
  return AlphaXCookie(
    name: name,
    value: value,
    domain: domain,
    path: path,
    expires: expires,
    secure: secure,
    httpOnly: httpOnly,
    hostOnly: hostOnly,
  );
}

String _defaultCookiePath(String requestPath) {
  if (requestPath.isEmpty || !requestPath.startsWith('/')) {
    return '/';
  }
  final separator = requestPath.lastIndexOf('/');
  return separator <= 0 ? '/' : requestPath.substring(0, separator);
}
