import 'alpha_x_cancellation.dart';
import 'alpha_x_progress.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_redirect.dart';
import 'alpha_x_request.dart';
import 'alpha_x_timeout.dart';

/// Immutable request-scoped options accepted by generated AlphaX APIs.
///
/// This is a compact bundle of the options already represented by
/// [AlphaXRequest]. It does not add a second timeout, cancellation, redirect,
/// or protocol policy system.
final class AlphaXRequestOptions {
  /// Creates request options using the same defaults as [AlphaXRequest].
  const AlphaXRequestOptions({
    this.timeouts = const AlphaXTimeouts(),
    this.cancellationToken,
    this.protocolPreference = AlphaXProtocolPreference.auto,
    this.protocolRequirement,
    this.redirectPolicy = const AlphaXRedirectPolicy(),
    this.priority = AlphaXPriority.normal,
    this.onUploadProgress,
    this.onDownloadProgress,
  });

  /// Timeout phases for this request.
  final AlphaXTimeouts timeouts;

  /// Optional caller-owned cancellation source.
  final AlphaXCancellationToken? cancellationToken;

  /// Preferred protocol for this request.
  final AlphaXProtocolPreference protocolPreference;

  /// Protocol that must be negotiated, when required.
  final AlphaXProtocolRequirement? protocolRequirement;

  /// Redirect behavior for this request.
  final AlphaXRedirectPolicy redirectPolicy;

  /// Optional scheduling hint.
  final AlphaXPriority priority;

  /// Optional upload progress callback.
  final AlphaXProgressCallback? onUploadProgress;

  /// Optional download progress callback.
  final AlphaXProgressCallback? onDownloadProgress;
}
