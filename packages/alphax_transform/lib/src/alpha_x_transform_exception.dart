/// Reports that this package cannot provide a background isolate on the
/// current target.
final class AlphaXTransformUnsupportedException implements Exception {
  /// Creates an unsupported-transform error.
  const AlphaXTransformUnsupportedException([
    this.message = 'Background isolate JSON transforms are unavailable on the current target.',
  ]);

  /// Human-readable explanation of the unsupported operation.
  final String message;

  @override
  String toString() => 'AlphaXTransformUnsupportedException: $message';
}
