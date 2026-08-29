import 'alpha_x_body.dart';
import 'alpha_x_capabilities.dart';
import 'alpha_x_errors.dart';
import 'alpha_x_event.dart';
import 'alpha_x_file.dart';
import 'alpha_x_headers.dart';
import 'alpha_x_progress.dart';
import 'alpha_x_protocol.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';
import 'alpha_x_security.dart';

/// Transport implementation consumed by [AlphaXClient].
abstract class AlphaXTransport {
  /// Creates a transport base.
  const AlphaXTransport();

  /// Capabilities known for this configured transport instance.
  AlphaXCapabilities get capabilities;

  /// TLS policy configured for this transport instance.
  AlphaXTlsPolicy get tlsPolicy => const AlphaXTlsPolicy.platformDefault();

  /// Proxy policy configured for this transport instance.
  AlphaXProxyPolicy get proxyPolicy => const AlphaXProxyPolicy.system();

  /// Sends [request] and returns response metadata plus a body abstraction.
  ///
  /// The returned response is a headers-time snapshot. When the transport
  /// cannot know the negotiated protocol until operation completion, callers
  /// must await [AlphaXResponse.completionMetrics] rather than interpreting
  /// [AlphaXProtocol.unknown] as HTTP/1.1 or as fallback.
  Future<AlphaXResponse> send(AlphaXRequest request);

  /// Sends [request] and emits response metadata, bounded chunks, and completion.
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request);

  /// Downloads to [target]. Native transports may override this for direct
  /// native-to-file transfer; the default uses the bounded streaming contract.
  Future<AlphaXTransferResult> download(
    AlphaXRequest request,
    AlphaXFileTarget target,
  ) async {
    request.cancellationToken?.throwIfCancelled();
    AlphaXResponseStarted? started;
    AlphaXResponseCompleted? completed;
    AlphaXFileSink? sink;
    var bytesTransferred = 0;
    final onDownloadProgress = request.onDownloadProgress;

    try {
      await for (final event in sendStreaming(request)) {
        switch (event) {
          case AlphaXResponseStarted():
            started = event;
            sink = await target.openWrite();
          case AlphaXResponseChunk(:final bytes):
            final activeSink = sink;
            if (activeSink == null) {
              throw const AlphaXProtocolException(
                'A response chunk arrived before response metadata',
              );
            }
            activeSink.add(bytes);
            bytesTransferred += bytes.length;
            if (onDownloadProgress != null) {
              onDownloadProgress(
                AlphaXProgress(
                  direction: AlphaXTransferDirection.download,
                  bytesTransferred: bytesTransferred,
                  totalBytes: _contentLength(started?.headers),
                ),
              );
            }
          case AlphaXResponseCompleted():
            completed = event;
        }
      }

      final responseStarted = started;
      final responseCompleted = completed;
      final activeSink = sink;
      if (responseStarted == null || responseCompleted == null || activeSink == null) {
        throw const AlphaXProtocolException(
          'A streaming transport must emit start, body, and completion events',
        );
      }
      await activeSink.flush();
      await activeSink.close();
      if (onDownloadProgress != null) {
        onDownloadProgress(
          AlphaXProgress(
            direction: AlphaXTransferDirection.download,
            bytesTransferred: bytesTransferred,
            totalBytes: _contentLength(responseStarted.headers),
            isComplete: true,
          ),
        );
      }
      return AlphaXTransferResult(
        statusCode: responseStarted.statusCode,
        headers: responseStarted.headers,
        protocol: responseCompleted.metrics.negotiatedProtocol == AlphaXProtocol.unknown
            ? responseStarted.protocol
            : responseCompleted.metrics.negotiatedProtocol,
        requestedProtocol: responseCompleted.requestedProtocol ?? responseStarted.requestedProtocol,
        requiredProtocol: responseCompleted.requiredProtocol,
        protocolFallback: responseCompleted.protocolFallback ?? responseStarted.protocolFallback,
        metrics: responseCompleted.metrics,
        redirects: responseStarted.redirects,
        bytesTransferred: bytesTransferred,
        totalBytes: _contentLength(responseStarted.headers),
      );
    } catch (_) {
      await sink?.abort();
      rethrow;
    }
  }

  /// Uploads [source]. Native transports may override this for direct file
  /// upload; the default exposes it as a replay-aware request body.
  Future<AlphaXTransferResult> upload(
    AlphaXRequest request,
    AlphaXFileSource source,
  ) async {
    var bytesTransferred = 0;
    final onUploadProgress = request.onUploadProgress;
    final countedSource = _CountingFileSource(
      source,
      onOpen: () => bytesTransferred = 0,
      onBytes: (bytes) => bytesTransferred += bytes,
    );
    final body = AlphaXFileBody(
      countedSource,
      onProgress: onUploadProgress,
    );
    final response = await send(request.copyWith(body: body));
    return AlphaXTransferResult(
      statusCode: response.statusCode,
      headers: response.headers,
      protocol: response.protocol,
      requestedProtocol: response.requestedProtocol,
      requiredProtocol: response.requiredProtocol,
      protocolFallback: response.protocolFallback,
      metrics: response.metrics,
      redirects: response.redirects,
      bytesTransferred:
          response.metrics.uploadedBytes ??
          (bytesTransferred == 0 ? source.length ?? 0 : bytesTransferred),
      totalBytes: source.length,
    );
  }

  /// Releases resources. Implementations must make repeated calls harmless.
  Future<void> close();

  static int? _contentLength(AlphaXHeaders? headers) {
    final value = headers?['content-length'];
    return value == null ? null : int.tryParse(value);
  }
}

final class _CountingFileSource implements AlphaXFileSource {
  _CountingFileSource(
    this._source, {
    required this.onOpen,
    required this.onBytes,
  });

  final AlphaXFileSource _source;
  final void Function() onOpen;
  final void Function(int bytes) onBytes;

  @override
  String? get name => _source.name;

  @override
  int? get length => _source.length;

  @override
  bool get isReplayable => _source.isReplayable;

  @override
  Stream<List<int>> openRead() async* {
    onOpen();
    await for (final chunk in _source.openRead()) {
      onBytes(chunk.length);
      yield chunk;
    }
  }
}
