import 'dart:async';

import 'alpha_x_event.dart';
import 'alpha_x_file.dart';
import 'alpha_x_middleware.dart';
import 'alpha_x_policy_helpers.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';

/// Supplies the current access token, when one is available.
typedef AlphaXAccessTokenProvider = FutureOr<String?> Function();

/// Refreshes an access token after an authentication challenge.
typedef AlphaXAccessTokenRefresher = FutureOr<String?> Function();

/// Adds authentication headers and coordinates one refresh for concurrent 401s.
///
/// Token injection applies to buffered, streamed, upload, and download
/// operations. Challenge refresh is limited to replayable buffered requests so
/// a partially consumed stream or file transfer is never replayed implicitly.
final class AlphaXAuthenticationMiddleware extends AlphaXMiddleware {
  /// Creates authentication middleware.
  AlphaXAuthenticationMiddleware({
    required this.accessToken,
    this.refreshAccessToken,
    this.scheme = 'Bearer',
    this.headerName = 'authorization',
    Iterable<int> challengeStatuses = const <int>{401},
    this.replaceExistingHeader = false,
  }) : challengeStatuses = Set<int>.unmodifiable(challengeStatuses);

  /// Current access-token provider.
  final AlphaXAccessTokenProvider accessToken;

  /// Optional refresh callback used once after a challenge.
  final AlphaXAccessTokenRefresher? refreshAccessToken;

  /// Authorization scheme placed before the token.
  final String scheme;

  /// Header that receives the credential.
  final String headerName;

  /// Statuses that trigger one refresh attempt.
  final Set<int> challengeStatuses;

  /// Whether a caller-supplied header may be replaced.
  final bool replaceExistingHeader;

  Future<String?>? _refreshing;

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) async {
    final firstRequest = await _withToken(request);
    final response = await next(firstRequest);
    if (refreshAccessToken == null ||
        !challengeStatuses.contains(response.statusCode) ||
        !request.body.isReplayable) {
      return response;
    }

    final token = await _refreshOnce();
    if (token == null || token.isEmpty) {
      return response;
    }
    await drainAlphaXResponse(response);
    final refreshedRequest = request.copyWith(
      headers: request.headers.set(headerName, _formatToken(token)),
    );
    return next(refreshedRequest);
  }

  @override
  Stream<AlphaXEvent> interceptStream(AlphaXRequest request, AlphaXStreamNext next) async* {
    final effectiveRequest = await _withToken(request);
    yield* next(effectiveRequest);
  }

  @override
  Future<AlphaXTransferResult> interceptDownload(
    AlphaXRequest request,
    AlphaXFileTarget target,
    AlphaXDownloadNext next,
  ) async {
    final effectiveRequest = await _withToken(request);
    return next(effectiveRequest, target);
  }

  @override
  Future<AlphaXTransferResult> interceptUpload(
    AlphaXRequest request,
    AlphaXFileSource source,
    AlphaXUploadNext next,
  ) async {
    final effectiveRequest = await _withToken(request);
    return next(effectiveRequest, source);
  }

  Future<AlphaXRequest> _withToken(AlphaXRequest request) async {
    if (request.headers.contains(headerName) && !replaceExistingHeader) {
      return request;
    }
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      return request;
    }
    return request.copyWith(headers: request.headers.set(headerName, _formatToken(token)));
  }

  String _formatToken(String token) => scheme.trim().isEmpty ? token : '$scheme $token';

  Future<String?> _refreshOnce() async {
    final existing = _refreshing;
    if (existing != null) {
      return existing;
    }
    final future = Future<String?>.sync(refreshAccessToken!);
    _refreshing = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshing, future)) {
        _refreshing = null;
      }
    }
  }
}
