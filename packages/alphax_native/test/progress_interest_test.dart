import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

import 'package:alphax_native/src/alpha_x_progress_arguments.dart';

void main() {
  group('operation-scoped progress interest', () {
    test('does not request either direction without observers', () {
      final arguments = alphaXProgressInterestArguments(
        AlphaXRequest(method: HttpMethod.get, uri: Uri.http('example.test', '/')),
      );

      expect(arguments, <String, Object?>{
        'downloadProgressRequested': false,
        'uploadProgressRequested': false,
      });
    });

    test('keeps download and upload interest independent', () {
      final downloadOnly = alphaXProgressInterestArguments(
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.http('example.test', '/download'),
          onDownloadProgress: (_) {},
        ),
      );
      final uploadOnly = alphaXProgressInterestArguments(
        AlphaXRequest(
          method: HttpMethod.post,
          uri: Uri.http('example.test', '/upload'),
          onUploadProgress: (_) {},
        ),
      );

      expect(downloadOnly['downloadProgressRequested'], isTrue);
      expect(downloadOnly['uploadProgressRequested'], isFalse);
      expect(uploadOnly['downloadProgressRequested'], isFalse);
      expect(uploadOnly['uploadProgressRequested'], isTrue);
    });

    test('file-body observer requests upload progress', () {
      final arguments = alphaXProgressInterestArguments(
        AlphaXRequest(
          method: HttpMethod.post,
          uri: Uri.http('example.test', '/upload'),
          body: AlphaXFileBody(
            _TestFileSource(),
            onProgress: (_) {},
          ),
        ),
      );

      expect(arguments['downloadProgressRequested'], isFalse);
      expect(arguments['uploadProgressRequested'], isTrue);
    });

    test('concurrent requests retain their own interest', () {
      final requests = <AlphaXRequest>[
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.http('example.test', '/a'),
          onDownloadProgress: (_) {},
        ),
        AlphaXRequest(
          method: HttpMethod.get,
          uri: Uri.http('example.test', '/b'),
        ),
        AlphaXRequest(
          method: HttpMethod.post,
          uri: Uri.http('example.test', '/c'),
          onUploadProgress: (_) {},
        ),
      ];
      final values = requests.map(alphaXProgressInterestArguments).toList();

      expect(values[0]['downloadProgressRequested'], isTrue);
      expect(values[0]['uploadProgressRequested'], isFalse);
      expect(values[1]['downloadProgressRequested'], isFalse);
      expect(values[1]['uploadProgressRequested'], isFalse);
      expect(values[2]['downloadProgressRequested'], isFalse);
      expect(values[2]['uploadProgressRequested'], isTrue);
    });
  });
}

final class _TestFileSource implements AlphaXFileSource {
  @override
  bool get isReplayable => true;

  @override
  int get length => 0;

  @override
  String get name => 'test';

  @override
  Stream<List<int>> openRead() => const Stream<List<int>>.empty();
}
