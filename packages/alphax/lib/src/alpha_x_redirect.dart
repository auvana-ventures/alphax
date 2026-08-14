/// Redirect behavior requested for a request.
enum AlphaXRedirectMode {
  /// Follow redirects up to [AlphaXRedirectPolicy.maxRedirects].
  follow,

  /// Return the redirect response to the caller.
  manual,

  /// Fail when a redirect is received.
  reject,
}

/// Redirect policy shared by transports.
final class AlphaXRedirectPolicy {
  /// Creates a redirect policy.
  const AlphaXRedirectPolicy({
    this.mode = AlphaXRedirectMode.follow,
    this.maxRedirects = 5,
  }) : assert(maxRedirects >= 0);

  /// Requested redirect behavior.
  final AlphaXRedirectMode mode;

  /// Maximum number of followed redirects.
  final int maxRedirects;
}

/// One redirect observed while resolving a request.
final class AlphaXRedirectInfo {
  /// Creates redirect metadata.
  const AlphaXRedirectInfo({
    required this.statusCode,
    required this.from,
    required this.to,
    this.method,
  });

  /// Redirect response status.
  final int statusCode;

  /// URI before the redirect.
  final Uri from;

  /// URI supplied by the redirect location.
  final Uri to;

  /// Method used for the redirect hop, when reported.
  final String? method;
}
