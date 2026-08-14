import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';
import 'package:alphax_dart_io_prototype/dart_io.dart';
import 'package:alphax_libcurl_ffi_prototype/curl_ffi.dart';
import 'package:alphax_rust_http_ffi_prototype/rust_ffi.dart';
import 'package:flutter/material.dart';

const _warmupIterations = 3;
const _measuredIterations = 10;
const _smallBytes = 1024;
const _downloadBytes = 32 * 1024 * 1024;
const _uploadBytes = 8 * 1024 * 1024;
const _streamBytes = 2 * 1024 * 1024;
const _streamChunkSize = 64 * 1024;
const _streamWindowChunks = 4;
const _requestOptions = BenchmarkRequestOptions(
  timeout: Duration(seconds: 60),
  followRedirects: true,
);

const _baseUrl = String.fromEnvironment('ALPHAX_MOBILE_GATE_BASE_URL');
const _deviceModel = String.fromEnvironment(
  'ALPHAX_DEVICE_MODEL',
  defaultValue: 'unreported',
);
const _deviceArchitecture = String.fromEnvironment(
  'ALPHAX_DEVICE_ARCH',
  defaultValue: 'arm64',
);
const _flutterVersion = String.fromEnvironment(
  'ALPHAX_FLUTTER_VERSION',
  defaultValue: 'unreported',
);
const _gitCommit = String.fromEnvironment(
  'ALPHAX_GIT_COMMIT',
  defaultValue: 'unreported',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _GateApp());

  final result = await _runGate();
  await _emitResult(result);
}

Future<void> _emitResult(Map<String, Object?> result) async {
  final encoded = jsonEncode(result);
  final file = File(
    '${Directory.systemTemp.path}/alphax-mobile-gate-result.json',
  );
  await file.writeAsString(encoded);
  debugPrint('ALPHAX_MOBILE_GATE_RESULT_FILE=${file.path}');
  debugPrint('ALPHAX_MOBILE_GATE_RESULT_BEGIN');
  const chunkSize = 700;
  for (var offset = 0; offset < encoded.length; offset += chunkSize) {
    final end = offset + chunkSize;
    debugPrint(
      encoded.substring(offset, end < encoded.length ? end : encoded.length),
    );
  }
  debugPrint('ALPHAX_MOBILE_GATE_RESULT_END');
  stdout.writeln('ALPHAX_MOBILE_GATE_RESULT_BEGIN');
  stdout.writeln(encoded);
  stdout.writeln('ALPHAX_MOBILE_GATE_RESULT_END');
}

final class _GateApp extends StatelessWidget {
  const _GateApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('AlphaX mobile sanity gate is running.')),
    ),
  );
}

Future<Map<String, Object?>> _runGate() async {
  if (_baseUrl.isEmpty) {
    return <String, Object?>{
      'status': 'blocked',
      'error': 'ALPHAX_MOBILE_GATE_BASE_URL was not provided',
    };
  }

  final baseUri = Uri.parse(_baseUrl);
  final idleRss = _currentRss();
  final expectedDownloadHash = _patternHash(_downloadBytes);
  final expectedStreamHash = _streamPatternHash(32, _streamChunkSize);
  final temp = await Directory.systemTemp.createTemp('alphax-mobile-gate-');
  final uploadFile = File('${temp.path}/upload.bin');
  final uploadHash = await _writePatternFile(uploadFile, _uploadBytes);
  final samples = <Map<String, Object?>>[];
  final candidateReports = <Map<String, Object?>>[];

  final factories = <String, BenchmarkTransport Function()>{
    'dart_io': () => DartIoTransport(maxConnectionsPerHost: 64),
    'libcurl_ffi': () => Platform.isIOS
        ? CurlFfiClient.fromProcess(
            streamChunkSize: _streamChunkSize,
            streamWindowChunks: _streamWindowChunks,
          )
        : CurlFfiClient.fromPath(
            'libalphax_curl.so',
            streamChunkSize: _streamChunkSize,
            streamWindowChunks: _streamWindowChunks,
          ),
    'rust_reqwest_ffi': () => Platform.isIOS
        ? RustFfiClient.fromProcess(
            streamChunkSize: _streamChunkSize,
            streamWindowChunks: _streamWindowChunks,
          )
        : RustFfiClient.fromPath(
            'libalphax_rust_http.so',
            streamChunkSize: _streamChunkSize,
            streamWindowChunks: _streamWindowChunks,
          ),
  };

  try {
    for (final entry in factories.entries) {
      final candidate = entry.key;
      BenchmarkTransport? transport;
      final candidateReport = <String, Object?>{
        'candidate': candidate,
        'initialized': false,
      };
      try {
        transport = entry.value();
        candidateReport['initialized'] = true;
        for (final scenario in <String>[
          'warm_small_get',
          'concurrency_64_small_get',
          'download_32mb',
          'upload_8mb',
          'mixed_workload',
        ]) {
          await _runScenario(
            candidate: candidate,
            scenario: scenario,
            transport: transport,
            baseUri: baseUri,
            uploadFile: uploadFile,
            uploadHash: uploadHash,
            expectedDownloadHash: expectedDownloadHash,
            expectedStreamHash: expectedStreamHash,
            idleRss: idleRss,
            samples: samples,
          );
        }
      } catch (error, stackTrace) {
        candidateReport['initialization_error'] = error.toString();
        candidateReport['initialization_stack'] = stackTrace.toString();
      } finally {
        await transport?.close();
      }
      candidateReports.add(candidateReport);
    }
  } finally {
    await temp.delete(recursive: true);
  }

  final correctnessFailures = samples
      .where((sample) => sample['correctness'] != true)
      .map((sample) => '${sample['candidate']}/${sample['scenario']}')
      .toList(growable: false);
  return <String, Object?>{
    'status': correctnessFailures.isEmpty ? 'complete' : 'correctness_failure',
    'metadata': <String, Object?>{
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'device_model': _deviceModel,
      'architecture': _deviceArchitecture,
      'dart_version': Platform.version,
      'flutter_version': _flutterVersion,
      'libcurl_version': '8.7.1; fixed mobile gate build; HTTP/1.1; no TLS',
      'rust_version': 'rustc 1.97.1; reqwest 0.12.28; hyper 1.11.0',
      'build_mode': 'profile device run; optimized native artifacts',
      'git_commit': _gitCommit,
      'warmup_iterations': _warmupIterations,
      'measured_iterations': _measuredIterations,
      'stream_chunk_size_bytes': _streamChunkSize,
      'stream_window_chunks': _streamWindowChunks,
      'transport_protocol_scope':
          'plain HTTP; server protocol header recorded; no HTTP/2 or HTTP/3 work',
      'timing_boundary':
          'wall clock starts immediately before the transport operation and ends after response/file completion; deterministic hash validation is outside the timed large download interval',
      'mixed_workload': <String, Object?>{
        'parallel_requests': <String, Object?>{
          'small_gets': 16,
          'endpoint': '/bytes/1024',
        },
        'stream_gets': 1,
        'stream_endpoint': '/stream/32/65536',
        'upload_requests': 1,
        'upload_endpoint': '/upload',
        'consumer': 'fast; stream is fully consumed',
      },
      'resource_measurement': <String, Object?>{
        'idle_rss_bytes': idleRss,
        'peak_rss':
            'ProcessInfo.currentRss sampled during measured operations when supported',
        'cpu':
            'unavailable: no reliable process CPU API used in the mobile app',
      },
      'practical_equivalence':
          'differences below 5 percent are treated as practically equivalent unless correctness or resource behavior differs materially',
    },
    'candidates': candidateReports,
    'correctness_failures': correctnessFailures,
    'samples': samples,
  };
}

Future<void> _runScenario({
  required String candidate,
  required String scenario,
  required BenchmarkTransport transport,
  required Uri baseUri,
  required File uploadFile,
  required String uploadHash,
  required String expectedDownloadHash,
  required String expectedStreamHash,
  required int? idleRss,
  required List<Map<String, Object?>> samples,
}) async {
  for (
    var iteration = 0;
    iteration < _warmupIterations + _measuredIterations;
    iteration++
  ) {
    final measured = iteration >= _warmupIterations;
    final sampler = measured ? _RssSampler() : null;
    final stopwatch = Stopwatch()..start();
    _OperationOutcome? outcome;
    Object? error;
    String? stack;
    try {
      outcome = await _operation(
        scenario: scenario,
        transport: transport,
        baseUri: baseUri,
        uploadFile: uploadFile,
        uploadHash: uploadHash,
        expectedDownloadHash: expectedDownloadHash,
        expectedStreamHash: expectedStreamHash,
      );
    } catch (caught, trace) {
      error = caught;
      stack = trace.toString();
    }
    stopwatch.stop();
    final peakRss = sampler?.stop();
    if (outcome != null && !outcome.correctness) {
      error ??= 'correctness validation failed';
    }
    if (measured) {
      samples.add(<String, Object?>{
        'candidate': candidate,
        'scenario': scenario,
        'iteration': iteration - _warmupIterations + 1,
        'correctness': outcome?.correctness == true && error == null,
        'wall_time_us':
            outcome?.timedElapsedUs ?? stopwatch.elapsed.inMicroseconds,
        'bytes': outcome?.bytes,
        'validation': outcome?.validation,
        'connection_observation': _connections(outcome?.headers ?? const []),
        'protocols': _protocols(outcome?.headers ?? const []),
        'diagnostics': outcome?.diagnostics,
        'rss_bytes_peak': peakRss,
        'rss_bytes_incremental_peak': _incremental(peakRss, idleRss),
        'cpu': null,
        'error': error?.toString(),
        'stack': stack,
      });
    }
  }
}

Future<_OperationOutcome> _operation({
  required String scenario,
  required BenchmarkTransport transport,
  required Uri baseUri,
  required File uploadFile,
  required String uploadHash,
  required String expectedDownloadHash,
  required String expectedStreamHash,
}) {
  switch (scenario) {
    case 'warm_small_get':
      return _smallGet(transport, _uri(baseUri, '/bytes/$_smallBytes'));
    case 'concurrency_64_small_get':
      return _concurrentGets(transport, _uri(baseUri, '/bytes/$_smallBytes'));
    case 'download_32mb':
      return _download(
        transport,
        _uri(baseUri, '/bytes/$_downloadBytes'),
        File('${Directory.systemTemp.path}/alphax-mobile-download.bin'),
        _downloadBytes,
        expectedDownloadHash,
      );
    case 'upload_8mb':
      return _upload(
        transport,
        _uploadUri(baseUri, uploadHash),
        uploadFile,
        _uploadBytes,
        uploadHash,
      );
    case 'mixed_workload':
      return _mixed(
        transport: transport,
        baseUri: baseUri,
        uploadFile: uploadFile,
        uploadHash: uploadHash,
        expectedStreamHash: expectedStreamHash,
      );
  }
  throw StateError('Unknown mobile gate scenario: $scenario');
}

Future<_OperationOutcome> _smallGet(
  BenchmarkTransport transport,
  Uri uri,
) async {
  final response = await transport.getBytes(uri, options: _requestOptions);
  final expected = _pattern(_smallBytes);
  return _OperationOutcome(
    correctness:
        response.statusCode == 200 && _sameBytes(response.bodyBytes, expected),
    bytes: response.bodyBytes.length,
    headers: <Map<String, List<String>>>[response.headers],
    validation: <String, Object?>{
      'status': response.statusCode,
      'expected_bytes': _smallBytes,
      'actual_bytes': response.bodyBytes.length,
      'body_hash': _fnv1aHex(response.bodyBytes),
      'expected_hash': _fnv1aHex(expected),
    },
    diagnostics: response.diagnostics,
  );
}

Future<_OperationOutcome> _concurrentGets(
  BenchmarkTransport transport,
  Uri uri,
) async {
  final responses = await Future.wait<BenchmarkResponse>(
    List<Future<BenchmarkResponse>>.generate(
      64,
      (_) => transport.getBytes(uri, options: _requestOptions),
    ),
  );
  final expected = _pattern(_smallBytes);
  final correct =
      responses.length == 64 &&
      responses.every(
        (response) =>
            response.statusCode == 200 &&
            _sameBytes(response.bodyBytes, expected),
      );
  return _OperationOutcome(
    correctness: correct,
    bytes: responses.fold<int>(
      0,
      (total, response) => total + response.bodyBytes.length,
    ),
    headers: responses
        .map((response) => response.headers)
        .toList(growable: false),
    validation: <String, Object?>{
      'request_count': responses.length,
      'successful_requests': responses
          .where((response) => response.statusCode == 200)
          .length,
      'expected_body_hash': _fnv1aHex(expected),
      'body_hashes': responses
          .map((response) => _fnv1aHex(response.bodyBytes))
          .toSet()
          .toList(),
    },
  );
}

Future<_OperationOutcome> _download(
  BenchmarkTransport transport,
  Uri uri,
  File file,
  int expectedBytes,
  String expectedHash,
) async {
  final stopwatch = Stopwatch()..start();
  final response = await transport.downloadFile(
    uri,
    file.path,
    options: _requestOptions,
  );
  stopwatch.stop();
  final actualBytes = await file.length();
  final actualHash = await _hashFile(file);
  final outcome = _OperationOutcome(
    correctness:
        response.statusCode == 200 &&
        response.bytesTransferred == expectedBytes &&
        actualBytes == expectedBytes &&
        actualHash == expectedHash,
    bytes: actualBytes,
    timedElapsedUs: stopwatch.elapsed.inMicroseconds,
    headers: <Map<String, List<String>>>[response.headers],
    validation: <String, Object?>{
      'status': response.statusCode,
      'expected_bytes': expectedBytes,
      'reported_bytes': response.bytesTransferred,
      'actual_file_bytes': actualBytes,
      'expected_hash': expectedHash,
      'actual_hash': actualHash,
      'hash_algorithm': 'fnv1a64',
      'file_transfer_path': 'transport downloadFile to app-private file',
    },
    diagnostics: response.diagnostics,
  );
  await file.delete();
  return outcome;
}

Future<_OperationOutcome> _upload(
  BenchmarkTransport transport,
  Uri uri,
  File file,
  int expectedBytes,
  String expectedHash,
) async {
  final response = await transport.uploadFile(
    uri,
    file.path,
    options: _requestOptions,
  );
  final serverBytes = int.tryParse(
    response.headers['x-alphax-uploaded-bytes']?.first ?? '',
  );
  final serverHash = response.headers['x-alphax-upload-fnv1a64']?.first;
  return _OperationOutcome(
    correctness:
        response.statusCode == 200 &&
        response.bytesTransferred == expectedBytes &&
        serverBytes == expectedBytes &&
        serverHash == expectedHash,
    bytes: response.bytesTransferred,
    headers: <Map<String, List<String>>>[response.headers],
    validation: <String, Object?>{
      'status': response.statusCode,
      'expected_bytes': expectedBytes,
      'reported_bytes': response.bytesTransferred,
      'server_bytes': serverBytes,
      'expected_hash': expectedHash,
      'server_hash': serverHash,
      'hash_algorithm':
          response.headers['x-alphax-upload-hash-algorithm']?.first,
    },
    diagnostics: response.diagnostics,
  );
}

Future<_OperationOutcome> _mixed({
  required BenchmarkTransport transport,
  required Uri baseUri,
  required File uploadFile,
  required String uploadHash,
  required String expectedStreamHash,
}) async {
  final smallGets = Future.wait<BenchmarkResponse>(
    List<Future<BenchmarkResponse>>.generate(
      16,
      (_) => transport.getBytes(
        _uri(baseUri, '/bytes/$_smallBytes'),
        options: _requestOptions,
      ),
    ),
  );
  final stream = _stream(
    transport,
    _uri(baseUri, '/stream/32/$_streamChunkSize'),
    expectedStreamHash,
  );
  final upload = _upload(
    transport,
    _uploadUri(baseUri, uploadHash),
    uploadFile,
    _uploadBytes,
    uploadHash,
  );
  final results = await Future.wait<dynamic>(<Future<dynamic>>[
    smallGets,
    stream,
    upload,
  ]);
  final getResponses = results[0] as List<BenchmarkResponse>;
  final streamOutcome = results[1] as _OperationOutcome;
  final uploadOutcome = results[2] as _OperationOutcome;
  final expectedSmall = _pattern(_smallBytes);
  final headers = <Map<String, List<String>>>[
    ...getResponses.map((response) => response.headers),
    ...streamOutcome.headers,
    ...uploadOutcome.headers,
  ];
  final correctGets =
      getResponses.length == 16 &&
      getResponses.every(
        (response) =>
            response.statusCode == 200 &&
            _sameBytes(response.bodyBytes, expectedSmall),
      );
  return _OperationOutcome(
    correctness:
        correctGets && streamOutcome.correctness && uploadOutcome.correctness,
    bytes:
        getResponses.fold<int>(
          0,
          (total, response) => total + response.bodyBytes.length,
        ) +
        (streamOutcome.bytes ?? 0) +
        (uploadOutcome.bytes ?? 0),
    headers: headers,
    validation: <String, Object?>{
      'small_get_count': getResponses.length,
      'small_get_successes': getResponses
          .where((response) => response.statusCode == 200)
          .length,
      'stream': streamOutcome.validation,
      'upload': uploadOutcome.validation,
    },
    diagnostics: <String, Object?>{
      'stream': streamOutcome.diagnostics,
      'upload': uploadOutcome.diagnostics,
    },
  );
}

Future<_OperationOutcome> _stream(
  BenchmarkTransport transport,
  Uri uri,
  String expectedHash,
) async {
  var status = 0;
  var bytes = 0;
  var hash = _fnv1aOffset;
  final headers = <Map<String, List<String>>>[];
  Map<String, Object?> diagnostics = const <String, Object?>{};
  await for (final event in transport.getStreaming(
    uri,
    options: _requestOptions,
  )) {
    if (event is BenchmarkStreamStarted) {
      status = event.statusCode;
      headers.add(event.headers);
    } else if (event is BenchmarkStreamChunk) {
      bytes += event.bytes.length;
      hash = _updateHash(hash, event.bytes);
    } else if (event is BenchmarkStreamCompleted) {
      status = event.statusCode;
      headers.add(event.headers);
      diagnostics = event.diagnostics;
    }
  }
  return _OperationOutcome(
    correctness:
        status == 200 &&
        bytes == _streamBytes &&
        _hashHex(hash) == expectedHash,
    bytes: bytes,
    headers: headers,
    validation: <String, Object?>{
      'status': status,
      'expected_bytes': _streamBytes,
      'actual_bytes': bytes,
      'expected_hash': expectedHash,
      'actual_hash': _hashHex(hash),
      'hash_algorithm': 'fnv1a64',
      'bounded_stream_config': <String, int>{
        'chunk_size_bytes': _streamChunkSize,
        'window_chunks': _streamWindowChunks,
        'queue_bytes': _streamChunkSize * _streamWindowChunks,
      },
    },
    diagnostics: diagnostics,
  );
}

final class _OperationOutcome {
  const _OperationOutcome({
    required this.correctness,
    this.bytes,
    this.timedElapsedUs,
    this.headers = const <Map<String, List<String>>>[],
    this.validation,
    this.diagnostics,
  });

  final bool correctness;
  final int? bytes;
  final int? timedElapsedUs;
  final List<Map<String, List<String>>> headers;
  final Map<String, Object?>? validation;
  final Map<String, Object?>? diagnostics;
}

final class _RssSampler {
  _RssSampler() {
    _record();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) => _record());
  }

  late final Timer _timer;
  int? _peak;

  void _record() {
    final rss = _currentRss();
    if (rss != null && (_peak == null || rss > _peak!)) {
      _peak = rss;
    }
  }

  int? stop() {
    _timer.cancel();
    _record();
    return _peak;
  }
}

int? _currentRss() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return null;
  }
}

int? _incremental(int? peak, int? idle) {
  if (peak == null || idle == null) {
    return null;
  }
  return peak - idle;
}

Map<String, Object?> _connections(List<Map<String, List<String>>> headers) {
  final ids = <String>{};
  final requestCounts = <String, String>{};
  for (final header in headers) {
    final id = header['x-alphax-server-connection-id']?.first;
    if (id == null) {
      continue;
    }
    ids.add(id);
    final count = header['x-alphax-server-connection-request-count']?.first;
    if (count != null) {
      requestCounts[id] = count;
    }
  }
  return <String, Object?>{
    'observable': ids.isNotEmpty,
    'distinct_connection_ids': ids.length,
    'request_counts_by_connection': requestCounts,
  };
}

List<String> _protocols(List<Map<String, List<String>>> headers) => headers
    .map((header) => header['x-alphax-server-protocol']?.first)
    .whereType<String>()
    .toSet()
    .toList(growable: false);

Uri _uri(Uri base, String path) => base.replace(path: path, query: '');

Uri _uploadUri(Uri base, String expectedHash) => base.replace(
  path: '/upload',
  queryParameters: <String, String>{
    'expected': '$_uploadBytes',
    'expected_hash': expectedHash,
  },
);

List<int> _pattern(int length, [int offset = 0]) => List<int>.generate(
  length,
  (index) => (index + offset) % 251,
  growable: false,
);

bool _sameBytes(List<int> first, List<int> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

Future<String> _writePatternFile(File file, int length) async {
  var hash = _fnv1aOffset;
  final sink = file.openWrite();
  try {
    for (var offset = 0; offset < length; offset += _streamChunkSize) {
      final remaining = length - offset;
      final chunkLength = remaining < _streamChunkSize
          ? remaining
          : _streamChunkSize;
      final chunk = _pattern(chunkLength, offset);
      sink.add(chunk);
      hash = _updateHash(hash, chunk);
    }
  } finally {
    await sink.close();
  }
  return _hashHex(hash);
}

Future<String> _hashFile(File file) async {
  var hash = _fnv1aOffset;
  await for (final chunk in file.openRead()) {
    hash = _updateHash(hash, chunk);
  }
  return _hashHex(hash);
}

String _patternHash(int length) {
  var hash = _fnv1aOffset;
  for (var index = 0; index < length; index++) {
    hash = ((hash ^ (index % 251)) * _fnv1aPrime) & _fnv1aMask;
  }
  return _hashHex(hash);
}

String _streamPatternHash(int chunks, int chunkSize) {
  var hash = _fnv1aOffset;
  for (var chunk = 0; chunk < chunks; chunk++) {
    hash = _updateHash(hash, _pattern(chunkSize, chunk));
  }
  return _hashHex(hash);
}

int _updateHash(int hash, Iterable<int> bytes) {
  var value = hash;
  for (final byte in bytes) {
    value = ((value ^ byte) * _fnv1aPrime) & _fnv1aMask;
  }
  return value;
}

String _fnv1aHex(Iterable<int> bytes) =>
    _hashHex(_updateHash(_fnv1aOffset, bytes));

String _hashHex(int hash) =>
    hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');

const int _fnv1aOffset = 0xcbf29ce484222325;
const int _fnv1aPrime = 0x100000001b3;
const int _fnv1aMask = 0xffffffffffffffff;
