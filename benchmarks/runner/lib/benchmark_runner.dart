import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';

/// One candidate factory used by the benchmark runner.
final class BenchmarkCandidate {
  /// Creates a candidate descriptor.
  const BenchmarkCandidate({required this.name, required this.create});

  /// Stable candidate identifier.
  final String name;

  /// Creates a fresh transport instance.
  final BenchmarkTransport Function() create;
}

/// Machine-readable benchmark output schema.
final class BenchmarkRun {
  /// Creates a run document.
  const BenchmarkRun({
    required this.metadata,
    required this.correctness,
    required this.samples,
    required this.performanceErrors,
  });

  /// Environment and methodology metadata.
  final Map<String, Object?> metadata;

  /// Correctness results by candidate.
  final List<Map<String, Object?>> correctness;

  /// Measured and diagnostic samples.
  final List<Map<String, Object?>> samples;

  /// Candidate/scenario failures that prevented a complete performance run.
  final List<Map<String, Object?>> performanceErrors;

  /// Encodes the stable JSON representation.
  Map<String, Object?> toJson() => <String, Object?>{
    'metadata': metadata,
    'correctness': correctness,
    'samples': samples,
    'performance_errors': performanceErrors,
  };
}

/// Runs correctness and local benchmark scenarios for all supplied candidates.
Future<BenchmarkRun> runBenchmark({
  required Uri baseUri,
  required List<BenchmarkCandidate> candidates,
  required Map<String, Object?> metadata,
  int warmupIterations = 3,
  int measuredIterations = 10,
  bool runPerformance = true,
}) async {
  final correctness = <Map<String, Object?>>[];
  final samples = <Map<String, Object?>>[];
  final performanceErrors = <Map<String, Object?>>[];
  for (final candidate in candidates) {
    stderr.writeln('Correctness: ${candidate.name}');
    final transport = candidate.create();
    try {
      final report = await runCorrectness(transport, baseUri);
      correctness.add(<String, Object?>{
        'candidate': candidate.name,
        'passed': report.passed,
        'checks': report.checks,
        'failures': report.failures,
      });
      if (!report.passed) {
        continue;
      }
      if (runPerformance) {
        try {
          samples.addAll(
            await runLocalScenarios(
              transport,
              candidate.name,
              baseUri,
              createTransport: candidate.create,
              warmupIterations: warmupIterations,
              measuredIterations: measuredIterations,
            ),
          );
        } catch (error, stackTrace) {
          performanceErrors.add(<String, Object?>{
            'candidate': candidate.name,
            'error': error.toString(),
            'stack_trace': stackTrace.toString(),
          });
        }
      }
    } catch (error, stackTrace) {
      correctness.add(<String, Object?>{
        'candidate': candidate.name,
        'passed': false,
        'checks': 0,
        'failures': <String>['runner error: $error', stackTrace.toString()],
      });
    } finally {
      await transport.close();
    }
  }
  return BenchmarkRun(
    metadata: metadata,
    correctness: correctness,
    samples: samples,
    performanceErrors: performanceErrors,
  );
}

/// Correctness outcome for one candidate.
final class CorrectnessReport {
  /// Creates a report.
  const CorrectnessReport({required this.passed, required this.checks, required this.failures});

  /// Whether every check passed.
  final bool passed;

  /// Number of checks executed.
  final int checks;

  /// Failure messages, if any.
  final List<String> failures;
}

/// Executes equivalent contract checks before performance measurements.
Future<CorrectnessReport> runCorrectness(BenchmarkTransport transport, Uri baseUri) async {
  var checks = 0;
  final failures = <String>[];
  Future<void> check(String name, FutureOr<bool> Function() body) async {
    checks++;
    stderr.writeln('  $name');
    try {
      if (!await Future<bool>(() async => body()).timeout(const Duration(seconds: 5))) {
        failures.add(name);
      }
    } catch (error) {
      failures.add('$name: $error');
    }
  }

  await check(
    'status code',
    () async => (await transport.getBytes(_uri(baseUri, '/status/201'))).statusCode == 201,
  );
  await check('response headers', () async {
    final response = await transport.getBytes(_uri(baseUri, '/headers'));
    return response.header('x-alphax-server') == 'benchmark';
  });
  await check('deterministic byte body', () async {
    final response = await transport.getBytes(_uri(baseUri, '/bytes/257'));
    return response.statusCode == 200 && _sameBytes(response.bodyBytes, _pattern(257, 0));
  });
  await check('POST body echo', () async {
    final body = List<int>.generate(257, (index) => index % 251);
    final response = await transport.postBytes(_uri(baseUri, '/echo'), body);
    return response.statusCode == 200 && _sameBytes(response.bodyBytes, body);
  });
  await check('stream completeness', () async {
    final events = await transport.getStreaming(_uri(baseUri, '/stream/4/257')).toList();
    final chunks = events.whereType<BenchmarkStreamChunk>().expand((event) => event.bytes).toList();
    final completed = events.whereType<BenchmarkStreamCompleted>().single;
    return completed.statusCode == 200 &&
        completed.bytesTransferred == 1028 &&
        chunks.length == 1028;
  });

  final temporary = await Directory.systemTemp.createTemp('alphax-correctness-');
  try {
    final uploadPath = '${temporary.path}/upload.bin';
    final downloadPath = '${temporary.path}/download.bin';
    final payload = _pattern(257, 0);
    await File(uploadPath).writeAsBytes(payload);
    await check('upload completeness', () async {
      final response = await transport.uploadFile(
        _uri(baseUri, '/upload?expected=257'),
        uploadPath,
      );
      return response.statusCode == 200 && response.bytesTransferred == 257;
    });
    await check('download completeness', () async {
      final response = await transport.downloadFile(_uri(baseUri, '/bytes/257'), downloadPath);
      return response.statusCode == 200 &&
          response.bytesTransferred == 257 &&
          _sameBytes(await File(downloadPath).readAsBytes(), payload);
    });
  } finally {
    await temporary.delete(recursive: true);
  }

  await check('timeout behavior', () async {
    try {
      await transport.getBytes(
        _uri(baseUri, '/delay/100'),
        options: const BenchmarkRequestOptions(timeout: Duration(milliseconds: 10)),
      );
      return false;
    } on BenchmarkTimeoutException {
      return true;
    }
  });
  await check('waiting cancellation', () async {
    final token = BenchmarkCancellationToken();
    final request = transport.getBytes(
      _uri(baseUri, '/delay/1000'),
      options: BenchmarkRequestOptions(cancellation: token),
    );
    token.cancel();
    try {
      await request;
      return false;
    } on BenchmarkCancelledException {
      return true;
    }
  });
  await check('redirect support', () async {
    final response = await transport.getBytes(_uri(baseUri, '/redirect/3'));
    return response.statusCode == 200 && utf8.decode(response.bodyBytes) == 'redirect complete';
  });
  return CorrectnessReport(passed: failures.isEmpty, checks: checks, failures: failures);
}

/// Runs the initial local profile after correctness has passed.
Future<List<Map<String, Object?>>> runLocalScenarios(
  BenchmarkTransport transport,
  String candidate,
  Uri baseUri, {
  required BenchmarkTransport Function() createTransport,
  required int warmupIterations,
  required int measuredIterations,
}) async {
  final samples = <Map<String, Object?>>[];
  stderr.writeln('Benchmark: $candidate small requests');
  for (final size in <int>[1024, 10 * 1024, 100 * 1024]) {
    for (final mode in <String>['cold', 'warm']) {
      for (var index = 0; index < warmupIterations + measuredIterations; index++) {
        final measured = index >= warmupIterations;
        final activeTransport = mode == 'cold' ? createTransport() : transport;
        final stopwatch = Stopwatch()..start();
        late final BenchmarkResponse response;
        try {
          response = await activeTransport.getBytes(_uri(baseUri, '/bytes/$size'));
        } finally {
          stopwatch.stop();
          if (mode == 'cold') {
            await activeTransport.close();
          }
        }
        if (measured) {
          samples.add(
            _sample(
              candidate: candidate,
              scenario: 'small_${size}_$mode',
              statusCode: response.statusCode,
              bytes: response.bodyBytes.length,
              elapsed: stopwatch.elapsed,
              timeToFirstByte: response.timeToFirstByte,
            ),
          );
        }
      }
    }
  }

  for (final concurrency in <int>[10, 50, 100, 250]) {
    stderr.writeln('Benchmark: $candidate concurrency $concurrency');
    for (var index = 0; index < warmupIterations + measuredIterations; index++) {
      final futures = List<Future<BenchmarkResponse>>.generate(
        concurrency,
        (_) => transport.getBytes(_uri(baseUri, '/bytes/1024')),
        growable: false,
      );
      final stopwatch = Stopwatch()..start();
      final responses = await Future.wait(
        futures.map(
          (future) async => future.catchError((Object error, StackTrace stackTrace) {
            throw StateError(
              '$candidate concurrency $concurrency request failed: $error\n$stackTrace',
            );
          }),
        ),
      );
      stopwatch.stop();
      if (index >= warmupIterations) {
        samples.add(
          _sample(
            candidate: candidate,
            scenario: 'concurrency_$concurrency',
            statusCode: responses.every((response) => response.statusCode == 200) ? 200 : 0,
            bytes: responses.fold<int>(0, (sum, response) => sum + response.bodyBytes.length),
            elapsed: stopwatch.elapsed,
          ),
        );
      }
    }
  }

  for (final size in <int>[10 * 1024 * 1024, 100 * 1024 * 1024]) {
    stderr.writeln('Benchmark: $candidate download $size');
    final path = '${Directory.systemTemp.path}/alphax-download-$size.bin';
    for (var index = 0; index < warmupIterations + measuredIterations; index++) {
      final response = await transport.downloadFile(_uri(baseUri, '/bytes/$size'), path);
      if (index >= warmupIterations) {
        samples.add(
          _sample(
            candidate: candidate,
            scenario: 'download_${size}_bytes',
            statusCode: response.statusCode,
            bytes: response.bytesTransferred,
            elapsed: response.elapsed,
            timeToFirstByte: response.timeToFirstByte,
          ),
        );
      }
    }
    await File(path).delete();
  }

  for (final size in <int>[10 * 1024 * 1024, 100 * 1024 * 1024]) {
    stderr.writeln('Benchmark: $candidate upload $size');
    final path = '${Directory.systemTemp.path}/alphax-upload-$size.bin';
    await _writePatternFile(path, size);
    for (var index = 0; index < warmupIterations + measuredIterations; index++) {
      final response = await transport.uploadFile(
        _uri(baseUri, '/upload?expected=$size'),
        path,
      );
      if (index >= warmupIterations) {
        samples.add(
          _sample(
            candidate: candidate,
            scenario: 'upload_${size}_bytes',
            statusCode: response.statusCode,
            bytes: response.bytesTransferred,
            elapsed: response.elapsed,
            timeToFirstByte: response.timeToFirstByte,
          ),
        );
      }
    }
    await File(path).delete();
  }

  for (var index = 0; index < warmupIterations + measuredIterations; index++) {
    if (index == 0) {
      stderr.writeln('Benchmark: $candidate streaming');
    }
    final stopwatch = Stopwatch()..start();
    var bytes = 0;
    Duration? timeToFirstByte;
    var statusCode = 0;
    await for (final event in transport.getStreaming(_uri(baseUri, '/stream/32/65536'))) {
      if (event case BenchmarkStreamStarted(statusCode: final startedStatus)) {
        timeToFirstByte ??= stopwatch.elapsed;
        statusCode = startedStatus;
      } else if (event case BenchmarkStreamChunk(bytes: final chunk)) {
        bytes += chunk.length;
      } else if (event case BenchmarkStreamCompleted(statusCode: final completedStatus)) {
        statusCode = completedStatus;
      }
    }
    stopwatch.stop();
    if (index >= warmupIterations) {
      samples.add(
        _sample(
          candidate: candidate,
          scenario: 'stream_2097152_bytes',
          statusCode: statusCode,
          bytes: bytes,
          elapsed: stopwatch.elapsed,
          timeToFirstByte: timeToFirstByte,
        ),
      );
    }
  }

  for (var index = 0; index < warmupIterations + measuredIterations; index++) {
    if (index == 0) {
      stderr.writeln('Benchmark: $candidate slow consumer');
    }
    final stopwatch = Stopwatch()..start();
    var bytes = 0;
    var statusCode = 0;
    await for (final event in transport.getStreaming(_uri(baseUri, '/stream/32/65536'))) {
      if (event case BenchmarkStreamStarted(statusCode: final startedStatus)) {
        statusCode = startedStatus;
      } else if (event case BenchmarkStreamChunk(bytes: final chunk)) {
        bytes += chunk.length;
        await Future<void>.delayed(const Duration(milliseconds: 2));
      } else if (event case BenchmarkStreamCompleted(statusCode: final completedStatus)) {
        statusCode = completedStatus;
      }
    }
    stopwatch.stop();
    if (index >= warmupIterations) {
      samples.add(
        _sample(
          candidate: candidate,
          scenario: 'stream_2097152_bytes_slow_consumer',
          statusCode: statusCode,
          bytes: bytes,
          elapsed: stopwatch.elapsed,
        ),
      );
    }
  }

  for (var index = 0; index < warmupIterations + measuredIterations; index++) {
    if (index == 0) {
      stderr.writeln('Benchmark: $candidate JSON separation');
    }
    final networkStopwatch = Stopwatch()..start();
    final response = await transport.getBytes(_uri(baseUri, '/json/100000'));
    networkStopwatch.stop();
    final decodeStopwatch = Stopwatch()..start();
    final text = utf8.decode(response.bodyBytes);
    decodeStopwatch.stop();
    final parseStopwatch = Stopwatch()..start();
    final decoded = jsonDecode(text);
    parseStopwatch.stop();
    if (index >= warmupIterations) {
      samples.add(
        _sample(
          candidate: candidate,
          scenario: 'json_100000_bytes_network',
          statusCode: response.statusCode,
          bytes: response.bodyBytes.length,
          elapsed: networkStopwatch.elapsed,
          timeToFirstByte: response.timeToFirstByte,
          extra: <String, Object?>{
            'utf8_decode_us': decodeStopwatch.elapsed.inMicroseconds,
            'json_parse_us': parseStopwatch.elapsed.inMicroseconds,
            'decoded_payload_type': decoded.runtimeType.toString(),
          },
        ),
      );
    }
  }

  await _runCancellationScenarios(samples, transport, candidate, baseUri, measuredIterations);
  return samples;
}

Future<void> _runCancellationScenarios(
  List<Map<String, Object?>> samples,
  BenchmarkTransport transport,
  String candidate,
  Uri baseUri,
  int measuredIterations,
) async {
  for (var index = 0; index < measuredIterations; index++) {
    final token = BenchmarkCancellationToken();
    final request = transport.getBytes(
      _uri(baseUri, '/delay/1000'),
      options: BenchmarkRequestOptions(cancellation: token),
    );
    final stopwatch = Stopwatch()..start();
    token.cancel();
    var outcome = 'completed';
    try {
      await request;
    } on BenchmarkCancelledException {
      outcome = 'cancelled';
    } catch (error) {
      outcome = 'error:${error.runtimeType}';
    }
    stopwatch.stop();
    final resourcesReleased = await _probeAfterCancellation(transport, baseUri);
    samples.add(
      _sample(
        candidate: candidate,
        scenario: 'cancellation_waiting',
        statusCode: outcome == 'cancelled' ? 0 : 200,
        bytes: 0,
        elapsed: stopwatch.elapsed,
        extra: <String, Object?>{'outcome': outcome, 'resources_released': resourcesReleased},
      ),
    );
  }

  for (var index = 0; index < measuredIterations; index++) {
    final token = BenchmarkCancellationToken();
    final stopwatch = Stopwatch()..start();
    final request = transport.getStreaming(
      _uri(baseUri, '/stream/128/65536?delay_ms=5'),
      options: BenchmarkRequestOptions(cancellation: token),
    );
    var outcome = 'completed';
    try {
      await for (final event in request) {
        if (event is BenchmarkStreamChunk) {
          token.cancel();
        }
      }
    } on BenchmarkCancelledException {
      outcome = 'cancelled';
    } catch (error) {
      outcome = 'error:${error.runtimeType}';
    }
    stopwatch.stop();
    final resourcesReleased = await _probeAfterCancellation(transport, baseUri);
    samples.add(
      _sample(
        candidate: candidate,
        scenario: 'cancellation_streaming',
        statusCode: outcome == 'cancelled' ? 0 : 200,
        bytes: 0,
        elapsed: stopwatch.elapsed,
        extra: <String, Object?>{'outcome': outcome, 'resources_released': resourcesReleased},
      ),
    );
  }

  final temporary = await Directory.systemTemp.createTemp('alphax-cancel-');
  try {
    final downloadPath = '${temporary.path}/download.bin';
    final uploadPath = '${temporary.path}/upload.bin';
    const uploadSize = 10 * 1024 * 1024;
    await _writePatternFile(uploadPath, uploadSize);
    for (final transfer in <String>['download', 'upload']) {
      for (var index = 0; index < measuredIterations; index++) {
        final token = BenchmarkCancellationToken();
        final request = transfer == 'download'
            ? transport.downloadFile(
                _uri(baseUri, '/stream/256/65536?delay_ms=5'),
                downloadPath,
                options: BenchmarkRequestOptions(cancellation: token),
              )
            : transport.uploadFile(
                _uri(baseUri, '/upload?expected=$uploadSize&delay_ms=1'),
                uploadPath,
                options: BenchmarkRequestOptions(cancellation: token),
              );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final stopwatch = Stopwatch()..start();
        token.cancel();
        var outcome = 'completed';
        try {
          await request;
        } on BenchmarkCancelledException {
          outcome = 'cancelled';
        } catch (error) {
          outcome = 'error:${error.runtimeType}';
        }
        stopwatch.stop();
        final resourcesReleased = await _probeAfterCancellation(transport, baseUri);
        samples.add(
          _sample(
            candidate: candidate,
            scenario: 'cancellation_$transfer',
            statusCode: outcome == 'cancelled' ? 0 : 200,
            bytes: 0,
            elapsed: stopwatch.elapsed,
            extra: <String, Object?>{'outcome': outcome, 'resources_released': resourcesReleased},
          ),
        );
      }
    }
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<bool> _probeAfterCancellation(BenchmarkTransport transport, Uri baseUri) async {
  try {
    final response = await transport.getBytes(_uri(baseUri, '/bytes/1'));
    return response.statusCode == 200 && response.bodyBytes.length == 1;
  } catch (_) {
    return false;
  }
}

Map<String, Object?> _sample({
  required String candidate,
  required String scenario,
  required int statusCode,
  required int bytes,
  required Duration elapsed,
  Duration? timeToFirstByte,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'candidate': candidate,
  'scenario': scenario,
  'status_code': statusCode,
  'bytes': bytes,
  'elapsed_us': elapsed.inMicroseconds,
  'ttfb_us': timeToFirstByte?.inMicroseconds,
  'throughput_bytes_per_second': elapsed.inMicroseconds == 0
      ? null
      : bytes * Duration.microsecondsPerSecond / elapsed.inMicroseconds,
  'memory_rss_after_bytes': ProcessInfo.currentRss,
  'memory_max_rss_bytes': ProcessInfo.maxRss,
  ...extra,
};

Future<void> _writePatternFile(String path, int size) async {
  final file = File(path).openWrite();
  const chunkSize = 1024 * 1024;
  for (var offset = 0; offset < size; offset += chunkSize) {
    file.add(_pattern(math.min(chunkSize, size - offset), offset));
  }
  await file.close();
}

Uri _uri(Uri base, String path) {
  final relative = Uri.parse(path);
  return base.replace(path: relative.path, query: relative.query);
}

List<int> _pattern(int length, int offset) =>
    List<int>.generate(length, (index) => (index + offset) % 251, growable: false);

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
