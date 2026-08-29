import 'package:alphax/alphax.dart';

/// Internal operation-scoped progress interest passed to native adapters.
///
/// This file is intentionally not exported from `alphax_native.dart`. The
/// values are transport arguments, not a public progress configuration API.
Map<String, Object?> alphaXProgressInterestArguments(AlphaXRequest request) {
  final body = request.body;
  final bodyProgressRequested = body is AlphaXFileBody && body.onProgress != null;
  return <String, Object?>{
    'downloadProgressRequested': request.onDownloadProgress != null,
    'uploadProgressRequested': request.onUploadProgress != null || bodyProgressRequested,
  };
}
