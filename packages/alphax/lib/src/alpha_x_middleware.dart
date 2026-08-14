import 'alpha_x_event.dart';
import 'alpha_x_file.dart';
import 'alpha_x_request.dart';
import 'alpha_x_response.dart';

/// Next handler for a buffered response operation.
typedef AlphaXNext = Future<AlphaXResponse> Function(AlphaXRequest request);

/// Next handler for a streamed response operation.
typedef AlphaXStreamNext = Stream<AlphaXEvent> Function(AlphaXRequest request);

/// Next handler for a file download operation.
typedef AlphaXDownloadNext =
    Future<AlphaXTransferResult> Function(
      AlphaXRequest request,
      AlphaXFileTarget target,
    );

/// Next handler for a file upload operation.
typedef AlphaXUploadNext =
    Future<AlphaXTransferResult> Function(
      AlphaXRequest request,
      AlphaXFileSource source,
    );

/// Foundation for asynchronous request/response middleware.
///
/// Middleware is entered in list order and unwinds in reverse order. A
/// middleware may mutate behavior by passing an immutable [AlphaXRequest]
/// copy, short-circuit by returning a response, or transform an exception in
/// a `try`/`catch` around [next]. It must not invoke a non-replayable body more
/// than once.
abstract class AlphaXMiddleware {
  /// Creates a middleware element.
  const AlphaXMiddleware();

  /// Intercepts a buffered operation.
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) => next(request);

  /// Intercepts a streaming operation.
  Stream<AlphaXEvent> interceptStream(AlphaXRequest request, AlphaXStreamNext next) =>
      next(request);

  /// Intercepts a file download operation.
  Future<AlphaXTransferResult> interceptDownload(
    AlphaXRequest request,
    AlphaXFileTarget target,
    AlphaXDownloadNext next,
  ) => next(request, target);

  /// Intercepts a file upload operation.
  Future<AlphaXTransferResult> interceptUpload(
    AlphaXRequest request,
    AlphaXFileSource source,
    AlphaXUploadNext next,
  ) => next(request, source);
}
