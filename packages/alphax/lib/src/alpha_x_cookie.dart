import 'alpha_x_headers.dart';
import 'alpha_x_event.dart';
import 'alpha_x_file.dart';
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

/// In-memory, host/path-scoped cookie storage.
final class AlphaXCookieJar {
  final List<AlphaXCookie> _cookies = <AlphaXCookie>[];

  /// Current non-expired cookies.
  List<AlphaXCookie> get cookies => List<AlphaXCookie>.unmodifiable(_liveCookies());

  /// Returns the Cookie header for [uri], or `null` when empty.
  String? cookieHeaderFor(Uri uri, {DateTime? now}) {
    final values =
        _liveCookies(
            now: now,
          ).where((cookie) => cookie.matches(uri, now: now)).toList(growable: false)
          ..sort((a, b) => b.path.length.compareTo(a.path.length));
    if (values.isEmpty) {
      return null;
    }
    return values.map((cookie) => cookie.headerValue).join('; ');
  }

  /// Stores all Set-Cookie headers from [responseHeaders].
  void storeFromResponse(Uri uri, AlphaXHeaders responseHeaders, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    for (final header in responseHeaders.values('set-cookie')) {
      final parsed = _parseSetCookie(uri, header, currentTime);
      if (parsed == null) {
        continue;
      }
      _cookies.removeWhere(
        (cookie) =>
            cookie.name == parsed.name &&
            cookie.domain == parsed.domain &&
            cookie.path == parsed.path,
      );
      if (!parsed.isExpired(currentTime)) {
        _cookies.add(parsed);
      }
    }
    _purge(currentTime);
  }

  /// Removes all stored cookies.
  void clear() => _cookies.clear();

  /// Removes cookies matching [name] and [uri].
  void remove(String name, Uri uri) {
    _cookies.removeWhere((cookie) => cookie.name == name && cookie.matches(uri));
  }

  List<AlphaXCookie> _liveCookies({DateTime? now}) {
    _purge(now ?? DateTime.now());
    return List<AlphaXCookie>.from(_cookies);
  }

  void _purge(DateTime now) => _cookies.removeWhere((cookie) => cookie.isExpired(now));

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
    var path = _defaultPath(uri.path);
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
          expires ??= _parseDate(attributeValue);
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

  String _defaultPath(String requestPath) {
    if (requestPath.isEmpty || !requestPath.startsWith('/')) {
      return '/';
    }
    final separator = requestPath.lastIndexOf('/');
    return separator <= 0 ? '/' : requestPath.substring(0, separator);
  }

  DateTime? _parseDate(String value) {
    final direct = DateTime.tryParse(value);
    if (direct != null) {
      return direct.toUtc();
    }
    final match = RegExp(
      r'(?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s*)?(\d{1,2})\s+'
      r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+'
      r'(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    const months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return DateTime.utc(
      int.parse(match.group(3)!),
      months[match.group(2)!.toLowerCase()]!,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}

/// Middleware that applies and records cookies for buffered, streamed, and
/// file-transfer operations.
final class AlphaXCookieMiddleware extends AlphaXMiddleware {
  /// Creates cookie middleware backed by [jar].
  const AlphaXCookieMiddleware(this.jar);

  /// Cookie storage used by this middleware.
  final AlphaXCookieJar jar;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    final effectiveRequest = _withCookies(request);
    final response = await next(effectiveRequest);
    jar.storeFromResponse(request.uri, response.headers);
    return response;
  }

  @override
  Stream<AlphaXEvent> interceptStream(AlphaXRequest request, AlphaXStreamNext next) async* {
    final effectiveRequest = _withCookies(request);
    await for (final event in next(effectiveRequest)) {
      if (event case AlphaXResponseStarted(:final headers)) {
        jar.storeFromResponse(request.uri, headers);
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
    final result = await next(_withCookies(request), target);
    jar.storeFromResponse(request.uri, result.headers);
    return result;
  }

  @override
  Future<AlphaXTransferResult> interceptUpload(
    AlphaXRequest request,
    AlphaXFileSource source,
    AlphaXUploadNext next,
  ) async {
    final result = await next(_withCookies(request), source);
    jar.storeFromResponse(request.uri, result.headers);
    return result;
  }

  AlphaXRequest _withCookies(AlphaXRequest request) {
    final cookieHeader = jar.cookieHeaderFor(request.uri);
    return cookieHeader == null || request.headers.contains('cookie')
        ? request
        : request.copyWith(headers: request.headers.set('cookie', cookieHeader));
  }
}
