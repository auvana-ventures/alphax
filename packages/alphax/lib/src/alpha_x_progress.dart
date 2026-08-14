/// Direction of a reported body transfer.
enum AlphaXTransferDirection {
  /// Request-body transfer.
  upload,

  /// Response-body transfer.
  download,
}

/// Transport-neutral upload or download progress.
final class AlphaXProgress {
  /// Creates a progress value.
  const AlphaXProgress({
    required this.direction,
    required this.bytesTransferred,
    this.totalBytes,
    this.isComplete = false,
  }) : assert(bytesTransferred >= 0),
       assert(totalBytes == null || totalBytes >= 0);

  /// Transfer direction.
  final AlphaXTransferDirection direction;

  /// Number of bytes transferred so far.
  final int bytesTransferred;

  /// Total bytes, when known.
  final int? totalBytes;

  /// Whether the operation has reached its terminal transfer boundary.
  final bool isComplete;
}

/// Callback invoked when a transport reports body progress.
typedef AlphaXProgressCallback = void Function(AlphaXProgress progress);
