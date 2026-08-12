import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';

import 'benchmark_metadata.dart';

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
  Set<String> onlyScenarios = const <String>{},
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
              onlyScenarios: onlyScenarios,
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
  Set<String> onlyScenarios = const <String>{},
}) async {
  final samples = <Map<String, Object?>>[];
  stderr.writeln('Benchmark: $candidate small requests');
  for (final size in <int>[1024, 10 * 1024, 100 * 1024]) {
    for (final mode in <String>['cold', 'warm']) {
      final scenario = 'small_${size}_$mode';
      if (!_scenarioEnabled(onlyScenarios, scenario)) {
        continue;
      }
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
              scenario: scenario,
              statusCode: response.statusCode,
              bytes: response.bodyBytes.length,
              elapsed: stopwatch.elapsed,
              timeToFirstByte: response.timeToFirstByte,
              extra: <String, Object?>{
                ...response.diagnostics,
                ..._connectionDiagnostics(<BenchmarkResponse>[response]),
              },
            ),
          );
        }
      }
    }
  }

  for (final concurrency in <int>[10, 50, 100, 250]) {
    final scenario = 'concurrency_$concurrency';
    if (!_scenarioEnabled(onlyScenarios, scenario)) {
      continue;
    }
    stderr.writeln('Benchmark: $candidate concurrency $concurrency');
    for (var index = 0; index < warmupIterations + measuredIterations; index++) {
      final measured = index >= warmupIterations;
      final processBefore = measured ? await captureProcessMetrics() : null;
      final stopwatch = Stopwatch()..start();
      final futures = List<Future<BenchmarkResponse>>.generate(
        concurrency,
        (_) => transport.getBytes(_uri(baseUri, '/bytes/1024')),
        growable: false,
      );
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
      final processAfter = measured ? await captureProcessMetrics() : null;
      if (measured) {
        samples.add(
          _sample(
            candidate: candidate,
            scenario: scenario,
            statusCode: responses.every((response) => response.statusCode == 200) ? 200 : 0,
            bytes: responses.fold<int>(0, (sum, response) => sum + response.bodyBytes.length),
            elapsed: stopwatch.elapsed,
            extra: <String, Object?>{
              ..._connectionDiagnostics(responses),
              ..._nativeDiagnostics(responses),
              'process_metrics': _processDiagnostics(
                processBefore!,
                processAfter!,
                stopwatch.elapsed,
              ),
            },
          ),
        );
      }
    }
  }

  for (final size in <int>[10 * 1024 * 1024, 100 * 1024 * 1024]) {
    final scenario = 'download_${size}_bytes';
    if (!_scenarioEnabled(onlyScenarios, scenario)) {
      continue;
    }
    stderr.writeln('Benchmark: $candidate download $size');
    final path = '${Directory.systemTemp.path}/alphax-download-$size.bin';
    for (var index = 0; index < warmupIterations + measuredIterations; index++) {
      final measured = index >= warmupIterations;
      final processBefore = measured ? await captureProcessMetrics() : null;
      final response = await transport.downloadFile(_uri(baseUri, '/bytes/$size'), path);
      final processAfter = measured ? await captureProcessMetrics() : null;
      if (measured) {
        samples.add(
          _sample(
            candidate: candidate,
            scenario: scenario,
            statusCode: response.statusCode,
            bytes: response.bytesTransferred,
            elapsed: response.elapsed,
            timeToFirstByte: response.timeToFirstByte,
            extra: <String, Object?>{
              ...response.diagnostics,
              ..._connectionDiagnosticsForTransfer(response.headers, response.diagnostics),
              'process_metrics': _processDiagnostics(
                processBefore!,
                processAfter!,
                response.elapsed,
              ),
            },
          ),
        );
      }
    }
    await File(path).delete();
  }

  for (final size in <int>[10 * 1024 * 1024, 100 * 1024 * 1024]) {
    final scenario = 'upload_${size}_bytes';
    if (!_scenarioEnabled(onlyScenarios, scenario)) {
      continue;
    }
    stderr.writeln('Benchmark: $candidate upload $size');
    final path = '${Directory.systemTemp.path}/alphax-upload-$size.bin';
    await _writePatternFile(path, size);
    final expectedHash = await _hashFile(path);
    for (var index = 0; index < warmupIterations + measuredIterations; index++) {
      final measured = index >= warmupIterations;
      final processBefore = measured ? await captureProcessMetrics() : null;
      final response = await transport.uploadFile(
        _uri(baseUri, '/upload?expected=$size&expected_hash=$expectedHash'),
        path,
      );
      _validateUploadResponse(response, size, expectedHash);
      final processAfter = measured ? await captureProcessMetrics() : null;
      if (measured) {
        samples.add(
          _sample(
            candidate: candidate,
            scenario: scenario,
            statusCode: response.statusCode,
            bytes: response.bytesTransferred,
            elapsed: response.elapsed,
            timeToFirstByte: response.timeToFirstByte,
            extra: <String, Object?>{
              ...response.diagnostics,
              'upload_validation': <String, Object?>{
                'expected_bytes': size,
                'server_bytes': _headerInt(response.headers, 'x-alphax-uploaded-bytes'),
                'expected_hash': expectedHash,
                'server_hash': response.headers['x-alphax-upload-fnv1a64']?.first,
                'hash_algorithm': response.headers['x-alphax-upload-hash-algorithm']?.first,
                'server_body_read_us': _headerInt(
                  response.headers,
                  'x-alphax-server-body-read-us',
                ),
              },
              ..._connectionDiagnosticsForTransfer(response.headers, response.diagnostics),
              'process_metrics': _processDiagnostics(
                processBefore!,
                processAfter!,
                response.elapsed,
              ),
            },
          ),
        );
      }
    }
    await File(path).delete();
  }

  if (_scenarioEnabled(onlyScenarios, 'stream_2097152_bytes')) {
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
  }

  if (_scenarioEnabled(onlyScenarios, 'stream_2097152_bytes_slow_consumer')) {
    for (var index = 0; index < warmupIterations + measuredIterations; index++) {
      if (index == 0) {
        stderr.writeln('Benchmark: $candidate slow consumer');
      }
      final measured = index >= warmupIterations;
      final processBefore = measured ? await captureProcessMetrics() : null;
      final stopwatch = Stopwatch()..start();
      var bytes = 0;
      var statusCode = 0;
      Map<String, Object?> streamDiagnostics = const <String, Object?>{};
      await for (final event in transport.getStreaming(_uri(baseUri, '/stream/32/65536'))) {
        if (event case BenchmarkStreamStarted(statusCode: final startedStatus)) {
          statusCode = startedStatus;
        } else if (event case BenchmarkStreamChunk(bytes: final chunk)) {
          bytes += chunk.length;
          await Future<void>.delayed(const Duration(milliseconds: 2));
        } else if (event case BenchmarkStreamCompleted(
          statusCode: final completedStatus,
          diagnostics: final diagnostics,
        )) {
          statusCode = completedStatus;
          streamDiagnostics = diagnostics;
        }
      }
      stopwatch.stop();
      final processAfter = measured ? await captureProcessMetrics() : null;
      if (measured) {
        samples.add(
          _sample(
            candidate: candidate,
            scenario: 'stream_2097152_bytes_slow_consumer',
            statusCode: statusCode,
            bytes: bytes,
            elapsed: stopwatch.elapsed,
            extra: <String, Object?>{
              ...streamDiagnostics,
              'process_metrics': _processDiagnostics(
                processBefore!,
                processAfter!,
                stopwatch.elapsed,
              ),
            },
          ),
        );
      }
    }
  }

  if (_scenarioEnabled(onlyScenarios, 'json_100000_bytes_network')) {
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
  }

  if (onlyScenarios.isEmpty ||
      onlyScenarios.any((scenario) => scenario.startsWith('cancellation_'))) {
    await _runCancellationScenarios(samples, transport, candidate, baseUri, measuredIterations);
  }
  return samples;
}

bool _scenarioEnabled(Set<String> onlyScenarios, String scenario) =>
    onlyScenarios.isEmpty || onlyScenarios.contains(scenario);

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

Map<String, Object?> _connectionDiagnostics(List<BenchmarkResponse> responses) =>
    _connectionDiagnosticsFromHeaders(
      responses.map(
        (response) => _headersWithNativeConnectionId(response.headers, response.diagnostics),
      ),
    );

Map<String, Object?> _connectionDiagnosticsForTransfer(
  Map<String, List<String>> headers,
  Map<String, Object?> diagnostics,
) => _connectionDiagnosticsFromHeaders(<Map<String, List<String>>>[
  _headersWithNativeConnectionId(headers, diagnostics),
]);

Map<String, List<String>> _headersWithNativeConnectionId(
  Map<String, List<String>> headers,
  Map<String, Object?> diagnostics,
) {
  final merged = <String, List<String>>{
    for (final entry in headers.entries) entry.key: List<String>.of(entry.value),
  };
  if (!merged.containsKey('x-alphax-server-connection-id')) {
    final rustConnectionId = diagnostics['rust_connection_id'];
    if (rustConnectionId is num && rustConnectionId != 0) {
      merged['x-alphax-server-connection-id'] = <String>['${rustConnectionId.toInt()}'];
    }
  }
  return merged;
}

Map<String, Object?> _connectionDiagnosticsFromHeaders(
  Iterable<Map<String, List<String>>> headerMaps,
) {
  final maps = headerMaps.toList(growable: false);
  final ids = <String>{};
  var connectionsEstablished = 0;
  var maxRequestsOnConnection = 0;
  var observedRequests = 0;
  var observed = false;
  for (final headers in maps) {
    final id = headers['x-alphax-server-connection-id']?.first;
    final established = _headerInt(headers, 'x-alphax-server-connections-established');
    final requestCount = _headerInt(headers, 'x-alphax-server-connection-request-count');
    if (id != null) {
      observed = true;
      observedRequests++;
      ids.add(id);
    }
    if (established != null && established > connectionsEstablished) {
      connectionsEstablished = established;
    }
    if (requestCount != null && requestCount > maxRequestsOnConnection) {
      maxRequestsOnConnection = requestCount;
    }
  }
  if (!observed) {
    return <String, Object?>{
      'connection_reuse': 'unavailable',
      'connection_ids_observed': null,
      'connections_established_cumulative': null,
      'requests_per_connection': null,
    };
  }
  return <String, Object?>{
    'connection_reuse': 'server remote-address/port observation',
    'connection_ids_observed': ids.toList(growable: false),
    'distinct_connections_observed': ids.length,
    'connections_established_cumulative': connectionsEstablished == 0
        ? null
        : connectionsEstablished,
    'requests_per_connection': ids.isEmpty ? null : observedRequests / ids.length,
    'max_requests_on_one_connection': maxRequestsOnConnection == 0 ? null : maxRequestsOnConnection,
  };
}

Map<String, Object?> _nativeDiagnostics(List<BenchmarkResponse> responses) {
  var pollCount = 0;
  var pollWaitUs = 0;
  var maxPollWaitUs = 0;
  var uploadCallbacks = 0;
  var responseCallbacks = 0;
  var observed = false;
  for (final response in responses) {
    final loop = response.diagnostics['libcurl_event_loop'];
    final callbacks = response.diagnostics['libcurl_callbacks'];
    if (loop is Map) {
      observed = true;
      pollCount += (loop['poll_count'] as num? ?? 0).toInt();
      pollWaitUs += (loop['poll_wait_us'] as num? ?? 0).toInt();
      final maximum = (loop['max_poll_wait_us'] as num? ?? 0).toInt();
      if (maximum > maxPollWaitUs) {
        maxPollWaitUs = maximum;
      }
    }
    if (callbacks is Map) {
      observed = true;
      uploadCallbacks += (callbacks['upload_read_callbacks'] as num? ?? 0).toInt();
      responseCallbacks += (callbacks['response_callbacks'] as num? ?? 0).toInt();
    }
  }
  if (!observed) {
    return const <String, Object?>{};
  }
  return <String, Object?>{
    'native_callback_volume': <String, Object?>{
      'libcurl_poll_count': pollCount,
      'libcurl_poll_wait_us': pollWaitUs,
      'libcurl_max_poll_wait_us': maxPollWaitUs,
      'libcurl_upload_read_callbacks': uploadCallbacks,
      'libcurl_response_callbacks': responseCallbacks,
    },
  };
}

Map<String, Object?> _processDiagnostics(
  BenchmarkProcessMetrics before,
  BenchmarkProcessMetrics after,
  Duration elapsed,
) {
  final cpuDelta = before.cpuTimeSeconds == null || after.cpuTimeSeconds == null
      ? null
      : after.cpuTimeSeconds! - before.cpuTimeSeconds!;
  final wallSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  return <String, Object?>{
    'before': before.toJson(),
    'after': after.toJson(),
    'cpu_time_delta_seconds': cpuDelta,
    'cpu_utilization_percent': cpuDelta == null || wallSeconds <= 0
        ? null
        : cpuDelta / wallSeconds * 100,
    'rss_delta_bytes': before.rssBytes == null || after.rssBytes == null
        ? null
        : after.rssBytes! - before.rssBytes!,
    'peak_rss_delta_bytes': before.maxRssBytes == null || after.maxRssBytes == null
        ? null
        : after.maxRssBytes! - before.maxRssBytes!,
  };
}

int? _headerInt(Map<String, List<String>> headers, String name) {
  final value = headers[name]?.first;
  return value == null ? null : int.tryParse(value);
}

Future<String> _hashFile(String path) async {
  var hash = _fnv1aOffset;
  await for (final chunk in File(path).openRead()) {
    for (final byte in chunk) {
      hash = ((hash ^ byte) * _fnv1aPrime) & _fnv1aMask;
    }
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

void _validateUploadResponse(
  BenchmarkTransferResult response,
  int expectedBytes,
  String expectedHash,
) {
  final serverBytes = _headerInt(response.headers, 'x-alphax-uploaded-bytes');
  final serverHash = response.headers['x-alphax-upload-fnv1a64']?.first;
  if (response.statusCode != 200 ||
      response.bytesTransferred != expectedBytes ||
      serverBytes != expectedBytes ||
      serverHash != expectedHash) {
    throw StateError(
      'upload validation failed: status=${response.statusCode}, '
      'reported=${response.bytesTransferred}, serverBytes=$serverBytes, '
      'serverHash=$serverHash, expectedHash=$expectedHash',
    );
  }
}

const int _fnv1aOffset = 0xcbf29ce484222325;
const int _fnv1aPrime = 0x100000001b3;
const int _fnv1aMask = 0xffffffffffffffff;

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
