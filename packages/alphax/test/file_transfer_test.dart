import 'dart:async';

import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

final class _MemorySource implements AlphaXFileSource {
  _MemorySource(this.bytes);

  final List<int> bytes;

  @override
  String? get name => 'memory.bin';

  @override
  int get length => bytes.length;

  @override
  bool get isReplayable => true;

  @override
  Stream<List<int>> openRead() => Stream<List<int>>.value(bytes);
}

final class _UnknownLengthSource implements AlphaXFileSource {
  _UnknownLengthSource(this.bytes);

  final List<int> bytes;

  @override
  String? get name => 'unknown-length.bin';

  @override
  int? get length => null;

  @override
  bool get isReplayable => true;

  @override
  Stream<List<int>> openRead() => Stream<List<int>>.value(bytes);
}

final class _MemorySink implements AlphaXFileSink {
  final bytes = <int>[];

  @override
  void add(List<int> bytes) => this.bytes.addAll(bytes);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> abort() async {
    bytes.clear();
  }
}

final class _MemoryTarget implements AlphaXFileTarget {
  final sink = _MemorySink();

  @override
  String? get name => 'download.bin';

  @override
  Future<AlphaXFileSink> openWrite() async => sink;
}

final class _TransferTransport extends AlphaXTransport {
  _TransferTransport(this.downloadBytes, {this.reportUploadedBytes = true});

  final List<int> downloadBytes;
  final bool reportUploadedBytes;

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    http11: AlphaXSupport.supported,
    streamingUpload: AlphaXSupport.supported,
    streamingDownload: AlphaXSupport.supported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    var uploaded = 0;
    await for (final chunk in request.body.openStream()) {
      uploaded += chunk.length;
    }
    return AlphaXResponse(
      statusCode: 200,
      metrics: AlphaXRequestMetrics(
        uploadedBytes: reportUploadedBytes ? uploaded : null,
      ),
    );
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    yield AlphaXResponseStarted(
      statusCode: 200,
      headers: AlphaXHeaders({'content-length': '3'}),
    );
    yield AlphaXResponseChunk(downloadBytes);
    yield AlphaXResponseCompleted(bytesReceived: downloadBytes.length);
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('default transport file paths preserve bytes and progress semantics', () async {
    final transport = _TransferTransport(<int>[4, 5, 6]);
    final client = AlphaXClient(transport: transport);
    final target = _MemoryTarget();
    final downloadProgress = <AlphaXProgress>[];

    final download = await client.download(
      Uri.parse('https://example.com/file'),
      to: target,
      onDownloadProgress: downloadProgress.add,
    );
    final uploadProgress = <AlphaXProgress>[];
    final upload = await client.upload(
      Uri.parse('https://example.com/file'),
      from: _MemorySource(<int>[1, 2, 3, 4]),
      onUploadProgress: uploadProgress.add,
    );

    expect(target.sink.bytes, <int>[4, 5, 6]);
    expect(download.bytesTransferred, 3);
    expect(downloadProgress.last.isComplete, isTrue);
    expect(upload.bytesTransferred, 4);
    expect(uploadProgress.last.direction, AlphaXTransferDirection.upload);
  });

  test('unused progress still preserves unknown-length upload accounting', () async {
    final transport = _TransferTransport(
      <int>[],
      reportUploadedBytes: false,
    );
    final client = AlphaXClient(transport: transport);

    final upload = await client.upload(
      Uri.parse('https://example.com/file'),
      from: _UnknownLengthSource(<int>[1, 2, 3, 4]),
    );

    expect(upload.bytesTransferred, 4);
  });
}
