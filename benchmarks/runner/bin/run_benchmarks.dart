import 'dart:convert';
import 'dart:io';

import 'package:alphax_benchmark_runner/alphax_benchmark_runner.dart';
import 'package:alphax_benchmark_server/benchmark_server.dart';
import 'package:alphax_dart_io_prototype/dart_io.dart';
import 'package:alphax_libcurl_ffi_prototype/curl_ffi.dart';
import 'package:alphax_rust_http_ffi_prototype/rust_ffi.dart';

Future<void> main(List<String> args) async {
  final options = _RunnerOptions.parse(args);
  if (options.candidateName == null && !options.correctnessOnly) {
    await _runIsolatedCandidates(options);
    return;
  }

  BenchmarkServer? server;
  try {
    var baseUri = options.baseUri;
    if (baseUri == null) {
      server = BenchmarkServer();
      await server.start();
      baseUri = server.baseUri;
    }

    final metadata = await _metadata(baseUri, options);

    final candidates = _candidates(
      options.candidateName,
      streamChunkSize: options.streamChunkSize,
      streamWindowChunks: options.streamWindowChunks,
      includeReferences: options.includeReferences,
    );
    stdout.writeln(
      'Running correctness checks for ${candidates.map((candidate) => candidate.name).join(', ')}',
    );
    final run = await runBenchmark(
      baseUri: baseUri,
      candidates: candidates,
      metadata: metadata,
      warmupIterations: options.warmupIterations,
      measuredIterations: options.measuredIterations,
      runPerformance: !options.correctnessOnly,
      onlyScenarios: options.onlyScenarios,
    );
    final failed = run.correctness.where((report) => report['passed'] != true).toList();
    if (options.correctnessOnly) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(run.correctness));
      if (failed.isNotEmpty) {
        throw StateError('Correctness failed');
      }
      return;
    }
    if (failed.isNotEmpty) {
      stderr.writeln(const JsonEncoder.withIndent('  ').convert(failed));
      throw StateError(
        'Correctness failed; comparative performance samples were not collected for every candidate',
      );
    }
    if (run.performanceErrors.isNotEmpty) {
      stderr.writeln(const JsonEncoder.withIndent('  ').convert(run.performanceErrors));
      throw StateError('Performance run failed; no complete comparable dataset was written');
    }
    await _writeRunFiles(run, options.outputDirectory);
  } finally {
    await server?.close();
  }
}

Future<Map<String, Object?>> _metadata(Uri baseUri, _RunnerOptions options) async {
  final metadata = await collectBenchmarkMetadata(baseUri: baseUri);
  metadata['base_url'] = baseUri.toString();
  metadata['candidate_process_name'] = options.candidateName ?? 'combined';
  metadata['warmup_iterations'] = options.warmupIterations;
  metadata['measured_iterations'] = options.measuredIterations;
  metadata['stream_chunk_size_bytes'] = options.streamChunkSize;
  metadata['stream_window_chunks'] = options.streamWindowChunks;
  metadata['include_external_references'] = options.includeReferences;
  metadata['transport_security'] = baseUri.scheme == 'https' ? 'tls' : 'plain-http';
  metadata['network_profile'] = options.networkProfile;
  metadata['selected_scenarios'] = options.onlyScenarios.toList(growable: false);
  metadata['methodology'] = <String, Object?>{
    'statistics': <String>[
      'min',
      'mean',
      'p25',
      'p50',
      'p75',
      'p90',
      'p95',
      'p99 where n >= 20',
      'max',
      'standard deviation',
    ],
    'p99_minimum_sample_count': 20,
    'raw_samples': true,
    'json_decode_in_transport_samples': false,
    'connection_reuse': 'candidate behavior is recorded; no reuse claim is inferred',
    'large_transfer_scope': <int>[10 * 1024 * 1024, 100 * 1024 * 1024],
    'timing_boundaries': <String, String>{
      'upload_start': 'before file length/stat preparation for every candidate',
      'upload_end': 'after response body completion and candidate/native cleanup notification',
      'download_start': 'before request creation',
      'download_end': 'after response bytes are written and file sink closes',
      'concurrency_start': 'before the first candidate future is created',
      'concurrency_end': 'after all candidate futures complete',
    },
    'upload_validation': 'server byte count plus deterministic FNV-1a 64 content hash',
    'process_metrics':
        'macOS ps CPU time/utilization plus Dart RSS/peak RSS; unavailable is reported explicitly',
    'classification_rule':
        'approximately equivalent <=5% p50 difference; clear >=20% with non-overlapping p25-p75 and <=10% CV; likely >=10% and <=20% CV; otherwise inconclusive',
  };
  return metadata;
}

Future<void> _runIsolatedCandidates(_RunnerOptions options) async {
  final temporary = await Directory.systemTemp.createTemp('alphax-benchmark-candidates-');
  try {
    final documents = <Map<String, Object?>>[];
    for (final candidate in _candidateNamesFor(options.includeReferences)) {
      final childOutput = Directory('${temporary.path}/$candidate');
      await childOutput.create(recursive: true);
      stdout.writeln('Starting isolated benchmark process: $candidate');
      final childArguments = <String>[
        'run',
        Platform.script.toFilePath(),
        '--candidate',
        candidate,
        '--warmup',
        '${options.warmupIterations}',
        '--iterations',
        '${options.measuredIterations}',
        '--stream-chunk-size',
        '${options.streamChunkSize}',
        '--stream-window-chunks',
        '${options.streamWindowChunks}',
        '--network-profile',
        options.networkProfile,
        '--output',
        childOutput.path,
      ];
      if (options.onlyScenarios.isNotEmpty) {
        childArguments
          ..add('--only')
          ..add(options.onlyScenarios.join(','));
      }
      if (options.includeReferences) {
        childArguments.add('--include-references');
      }
      if (options.baseUri != null) {
        childArguments
          ..add('--base-url')
          ..add(options.baseUri.toString());
      }
      final process = await Process.start(
        Platform.executable,
        childArguments,
        workingDirectory: Directory.current.path,
      );
      final stdoutDone = process.stdout.transform(utf8.decoder).forEach(stdout.write);
      final stderrDone = process.stderr.transform(utf8.decoder).forEach(stderr.write);
      final exitCode = await process.exitCode;
      await Future.wait<void>(<Future<void>>[stdoutDone, stderrDone]);
      if (exitCode != 0) {
        throw StateError('Isolated benchmark process failed for $candidate (exit $exitCode)');
      }
      final rawDirectory = Directory('${childOutput.path}/raw');
      final rawFiles = await rawDirectory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .toList();
      if (rawFiles.length != 1) {
        throw StateError('Expected one raw result for $candidate, found ${rawFiles.length}');
      }
      documents.add(_asMap(jsonDecode(await File(rawFiles.single.path).readAsString())));
    }

    final firstMetadata = Map<String, Object?>.from(documents.first['metadata']! as Map);
    final idleBaselines = <String, Object?>{
      for (final document in documents)
        (document['metadata']! as Map)['candidate_process_name'] as String:
            (document['metadata']! as Map)['process_metrics_idle_baseline'],
    };
    firstMetadata
      ..remove('base_url')
      ..remove('candidate_process_name')
      ..remove('process_metrics_idle_baseline')
      ..['process_metrics_idle_baselines'] = idleBaselines
      ..['candidate_process_isolation'] = true
      ..['candidate_order'] = _candidateNamesFor(options.includeReferences);
    final run = BenchmarkRun(
      metadata: firstMetadata,
      correctness: documents.expand((document) => _mapList(document['correctness'])).toList(),
      samples: documents.expand((document) => _mapList(document['samples'])).toList(),
      performanceErrors: documents
          .expand((document) => _mapList(document['performance_errors']))
          .toList(),
    );
    _throwIfIncomplete(run);
    await _writeRunFiles(run, options.outputDirectory);
  } finally {
    await temporary.delete(recursive: true);
  }
}

void _throwIfIncomplete(BenchmarkRun run) {
  final failed = run.correctness.where((report) => report['passed'] != true).toList();
  if (failed.isNotEmpty) {
    stderr.writeln(const JsonEncoder.withIndent('  ').convert(failed));
    throw StateError(
      'Correctness failed; comparative performance samples were not collected for every candidate',
    );
  }
  if (run.performanceErrors.isNotEmpty) {
    stderr.writeln(const JsonEncoder.withIndent('  ').convert(run.performanceErrors));
    throw StateError('Performance run failed; no complete comparable dataset was written');
  }
}

Future<void> _writeRunFiles(BenchmarkRun run, String outputDirectoryPath) async {
  final outputDirectory = Directory(outputDirectoryPath);
  await outputDirectory.create(recursive: true);
  final commit = (run.metadata['git_commit'] as String).replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final dirtySuffix = run.metadata['git_worktree_dirty'] == true ? '-dirty' : '';
  final chunkSize = run.metadata['stream_chunk_size_bytes'];
  final windowChunks = run.metadata['stream_window_chunks'];
  final flowSuffix = chunkSize is num && windowChunks is num
      ? '-chunk${chunkSize.toInt()}-window${windowChunks.toInt()}'
      : '';
  final profile = run.metadata['network_profile'];
  final profileSuffix = profile is String && profile.isNotEmpty ? '-network-$profile' : '';
  final selected = run.metadata['selected_scenarios'];
  final selectedSuffix = selected is List && selected.isNotEmpty
      ? () {
          final labels = selected.map((value) => value.toString()).toList(growable: false);
          final fullLabel = labels.join('_').replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
          final compactLabel = fullLabel.length <= 80
              ? fullLabel
              : '${labels.length}-${labels.first}-${labels.last}'.replaceAll(
                  RegExp(r'[^A-Za-z0-9_.-]'),
                  '_',
                );
          return '-only-$compactLabel';
        }()
      : '';
  final security = run.metadata['transport_security'] == 'tls' ? 'tls' : 'local';
  final protocolProfile = run.metadata['protocol_profile']?.toString().toLowerCase() ?? '';
  final protocolSuffix = protocolProfile.contains('http/2') ? '-h2' : '';
  final candidateName = run.metadata['candidate_process_name']?.toString();
  final candidateSuffix =
      candidateName == null || candidateName.isEmpty || candidateName == 'combined'
      ? ''
      : '-$candidateName';
  final stem =
      'macos-$security-$commit$dirtySuffix$flowSuffix$profileSuffix$protocolSuffix$candidateSuffix$selectedSuffix';
  final rawPath = '${outputDirectory.path}/raw/$stem.json';
  final summaryJsonPath = '${outputDirectory.path}/summaries/$stem.json';
  final summaryMarkdownPath = '${outputDirectory.path}/summaries/$stem.md';
  await Directory('${outputDirectory.path}/raw').create(recursive: true);
  await Directory('${outputDirectory.path}/summaries').create(recursive: true);
  await File(rawPath).writeAsString(const JsonEncoder.withIndent('  ').convert(run.toJson()));
  final summaries = summarizeSamples(run.samples);
  final summary = <String, Object?>{
    'metadata': run.metadata,
    'correctness': run.correctness,
    'performance_errors': run.performanceErrors,
    'scenario_summaries': summaries,
    'interpretation': _interpretSummaries(summaries),
  };
  await File(summaryJsonPath).writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
  await File(summaryMarkdownPath).writeAsString(_markdownSummary(summary));
  stdout.writeln('Raw results: $rawPath');
  stdout.writeln('Summary JSON: $summaryJsonPath');
  stdout.writeln('Summary Markdown: $summaryMarkdownPath');
}

Map<String, Object?> _asMap(Object? value) => Map<String, Object?>.from(value! as Map);

List<Map<String, Object?>> _mapList(Object? value) => [
  for (final item in (value as List<Object?>? ?? const <Object?>[])) _asMap(item),
];

final List<String> _candidateNames = <String>['dart_io', 'libcurl_ffi', 'rust_reqwest_ffi'];

List<String> _candidateNamesFor(bool includeReferences) => <String>[
  ..._candidateNames,
  if (includeReferences) 'dio_reference',
];

List<BenchmarkCandidate> _candidates(
  String? filter, {
  required int streamChunkSize,
  required int streamWindowChunks,
  required bool includeReferences,
}) {
  final curlPath = Platform.environment['ALPHAX_CURL_LIBRARY'];
  final rustPath = Platform.environment['ALPHAX_RUST_LIBRARY'];
  if (curlPath == null || curlPath.isEmpty || rustPath == null || rustPath.isEmpty) {
    throw StateError(
      'Set ALPHAX_CURL_LIBRARY and ALPHAX_RUST_LIBRARY before running a comparable dataset',
    );
  }
  final candidates = <BenchmarkCandidate>[
    BenchmarkCandidate(name: 'dart_io', create: DartIoTransport.new),
    BenchmarkCandidate(
      name: 'rust_reqwest_ffi',
      create: () => RustFfiClient.fromPath(
        rustPath,
        streamChunkSize: streamChunkSize,
        streamWindowChunks: streamWindowChunks,
      ),
    ),
    BenchmarkCandidate(
      name: 'libcurl_ffi',
      create: () => CurlFfiClient.fromPath(
        curlPath,
        streamChunkSize: streamChunkSize,
        streamWindowChunks: streamWindowChunks,
      ),
    ),
    if (includeReferences)
      BenchmarkCandidate(name: 'dio_reference', create: DioReferenceTransport.new),
  ];
  if (filter == null) {
    return candidates;
  }
  final filtered = candidates.where((candidate) => candidate.name == filter).toList();
  if (filtered.isEmpty) {
    throw FormatException('Unknown candidate: $filter');
  }
  return filtered;
}

final class _RunnerOptions {
  const _RunnerOptions({
    required this.baseUri,
    required this.outputDirectory,
    required this.warmupIterations,
    required this.measuredIterations,
    required this.correctnessOnly,
    required this.candidateName,
    required this.onlyScenarios,
    required this.streamChunkSize,
    required this.streamWindowChunks,
    required this.includeReferences,
    required this.networkProfile,
  });

  final Uri? baseUri;
  final String outputDirectory;
  final int warmupIterations;
  final int measuredIterations;
  final bool correctnessOnly;
  final String? candidateName;
  final Set<String> onlyScenarios;
  final int streamChunkSize;
  final int streamWindowChunks;
  final bool includeReferences;
  final String networkProfile;

  static _RunnerOptions parse(List<String> args) {
    Uri? baseUri;
    var outputDirectory = 'benchmarks/results';
    var warmupIterations = 3;
    var measuredIterations = 10;
    var correctnessOnly = false;
    String? candidateName;
    var streamChunkSize = 64 * 1024;
    var streamWindowChunks = 4;
    var includeReferences = false;
    var networkProfile = 'local';
    final onlyScenarios = <String>{};
    for (var index = 0; index < args.length; index++) {
      switch (args[index]) {
        case '--base-url':
          baseUri = Uri.parse(args[++index]);
        case '--output':
          outputDirectory = args[++index];
        case '--warmup':
          warmupIterations = int.parse(args[++index]);
        case '--iterations':
          measuredIterations = int.parse(args[++index]);
        case '--stream-chunk-size':
          streamChunkSize = int.parse(args[++index]);
        case '--stream-window-chunks':
          streamWindowChunks = int.parse(args[++index]);
        case '--include-references':
          includeReferences = true;
        case '--network-profile':
          networkProfile = args[++index];
        case '--correctness-only':
          correctnessOnly = true;
        case '--candidate':
          candidateName = args[++index];
        case '--only':
          onlyScenarios
            ..clear()
            ..addAll(args[++index].split(',').where((value) => value.isNotEmpty));
        case '--help':
          stdout.writeln('''Usage: dart run bin/run_benchmarks.dart [options]
  --base-url URL      Use an existing benchmark server; otherwise start one
  --output DIR        Results directory (default: benchmarks/results)
  --warmup N          Warmup iterations (default: 3)
  --iterations N      Measured iterations (default: 10)
  --stream-chunk-size N  Native FFI chunk target (default: 65536)
  --stream-window-chunks N  Native FFI credit window (default: 4)
  --include-references  Include Dio ecosystem reference (Nitro is not Dart-compatible)
  --network-profile NAME  local, good-network, typical-mobile, or poor-mobile
  --correctness-only  Run correctness checks without performance scenarios
  --candidate NAME     Diagnostic filter: dart_io, libcurl_ffi, or rust_reqwest_ffi
  --only LIST           Comma-separated performance scenario names; correctness always runs
''');
          exit(0);
        default:
          throw FormatException('Unknown argument: ${args[index]}');
      }
    }
    if (warmupIterations < 0 || measuredIterations < 2) {
      throw FormatException('warmup must be >= 0 and iterations must be >= 2');
    }
    if (streamChunkSize <= 0 || streamWindowChunks <= 0) {
      throw FormatException('stream chunk size and window must be positive');
    }
    const networkProfiles = <String>{'local', 'good-network', 'typical-mobile', 'poor-mobile'};
    if (!networkProfiles.contains(networkProfile)) {
      throw FormatException('unknown network profile: $networkProfile');
    }
    return _RunnerOptions(
      baseUri: baseUri,
      outputDirectory: outputDirectory,
      warmupIterations: warmupIterations,
      measuredIterations: measuredIterations,
      correctnessOnly: correctnessOnly,
      candidateName: candidateName,
      onlyScenarios: onlyScenarios,
      streamChunkSize: streamChunkSize,
      streamWindowChunks: streamWindowChunks,
      includeReferences: includeReferences,
      networkProfile: networkProfile,
    );
  }
}

List<Map<String, Object?>> _interpretSummaries(List<Map<String, Object?>> summaries) {
  final byScenario = <String, List<Map<String, Object?>>>{};
  for (final summary in summaries) {
    final scenario = summary['scenario'];
    if (scenario is String) {
      byScenario.putIfAbsent(scenario, () => <Map<String, Object?>>[]).add(summary);
    }
  }
  return [
    for (final entry in byScenario.entries)
      () {
        final rows = entry.value;
        final comparableRows = rows
            .where(
              (row) => row['candidate'] is String && row['stats'] is Map<String, Object?>,
            )
            .toList(growable: false);
        comparableRows.sort(
          (left, right) => ((left['stats']! as Map<String, Object?>)['p50_us']! as num).compareTo(
            (right['stats']! as Map<String, Object?>)['p50_us']! as num,
          ),
        );
        final ordered = comparableRows
            .map((row) => row['candidate'] as String)
            .toList(growable: false);
        final classification = _classifyScenario(comparableRows);
        final note = comparableRows.length < 2
            ? 'only one candidate has measured samples'
            : '${classification['label']}: ${classification['explanation']}';
        return <String, Object?>{
          'scenario': entry.key,
          'assessment': note,
          'classification': classification['label'],
          'classification_rule': classification['rule'],
          'p50_order': ordered,
        };
      }(),
  ];
}

Map<String, String> _classifyScenario(List<Map<String, Object?>> rows) {
  if (rows.length < 2) {
    return const <String, String>{
      'label': 'inconclusive',
      'explanation': 'fewer than two candidates have measured samples',
      'rule': 'at least two comparable candidate distributions are required',
    };
  }
  final fastest = rows.first['stats']! as Map<String, Object?>;
  final runnerUp = rows[1]['stats']! as Map<String, Object?>;
  final fastestP50 = (fastest['p50_us']! as num).toDouble();
  final runnerUpP50 = (runnerUp['p50_us']! as num).toDouble();
  final relativeDifference = runnerUpP50 / fastestP50 - 1;
  final fastestCv = (fastest['stddev_us']! as num).toDouble() / fastestP50;
  final runnerUpCv = (runnerUp['stddev_us']! as num).toDouble() / runnerUpP50;
  final intervalsOverlap =
      (fastest['p75_us']! as num).toDouble() >= (runnerUp['p25_us']! as num).toDouble() &&
      (runnerUp['p75_us']! as num).toDouble() >= (fastest['p25_us']! as num).toDouble();
  const rule =
      'approximately equivalent when p50 differs <=5%; clear difference requires '
      '>=20% separation, non-overlapping p25-p75 intervals, and <=10% coefficient '
      'of variation for both; likely difference requires >=10% separation and <=20% '
      'coefficient of variation; otherwise inconclusive';
  if (relativeDifference <= 0.05) {
    return const <String, String>{
      'label': 'approximately equivalent',
      'explanation': 'p50 values differ by at most 5%',
      'rule': rule,
    };
  }
  if (relativeDifference >= 0.20 && !intervalsOverlap && fastestCv <= 0.10 && runnerUpCv <= 0.10) {
    return <String, String>{
      'label': 'clear difference',
      'explanation': '${rows.first['candidate']} is faster with stable, non-overlapping samples',
      'rule': rule,
    };
  }
  if (relativeDifference >= 0.10 && fastestCv <= 0.20 && runnerUpCv <= 0.20) {
    return <String, String>{
      'label': 'likely difference',
      'explanation':
          '${rows.first['candidate']} is faster, but variance or overlap limits confidence',
      'rule': rule,
    };
  }
  return const <String, String>{
    'label': 'inconclusive',
    'explanation': 'the observed separation is not stable enough for a stronger claim',
    'rule': rule,
  };
}

String _markdownSummary(Map<String, Object?> summary) {
  final buffer = StringBuffer()
    ..writeln('# AlphaX Phase 0 macOS local benchmark summary')
    ..writeln()
    ..writeln(
      'This is a scenario-by-scenario report. It does not select a production transport or produce an overall speed score.',
    )
    ..writeln()
    ..writeln('## Correctness')
    ..writeln()
    ..writeln('| Candidate | Passed | Checks | Failures |')
    ..writeln('| --- | ---: | ---: | --- |');
  final correctness = summary['correctness'] as List<Object?>;
  for (final item in correctness.cast<Map<String, Object?>>()) {
    buffer.writeln(
      '| ${item['candidate']} | ${item['passed']} | ${item['checks']} | ${(item['failures'] as List<Object?>).join('; ')} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Scenario summaries')
    ..writeln()
    ..writeln(
      '| Candidate | Scenario | N | Min (ms) | p50 (ms) | p90 (ms) | p95 (ms) | Max (ms) | SD (ms) | TTFB p50 (ms) | Mean MB/s |',
    )
    ..writeln('| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |');
  final scenarios = summary['scenario_summaries'] as List<Object?>;
  for (final item in scenarios.cast<Map<String, Object?>>()) {
    final stats = item['stats'] as Map<String, Object?>;
    buffer.writeln(
      '| ${item['candidate']} | ${item['scenario']} | ${stats['count']} | ${_milliseconds(stats['min_us'])} | ${_milliseconds(stats['p50_us'])} | ${_milliseconds(stats['p90_us'])} | ${_milliseconds(stats['p95_us'])} | ${_milliseconds(stats['max_us'])} | ${_milliseconds(stats['stddev_us'])} | ${_milliseconds(stats['ttfb_p50_us'])} | ${_megabytesPerSecond(stats['mean_throughput_bytes_per_second'])} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Scenario-local interpretation')
    ..writeln()
    ..writeln(
      'The following observations are descriptive only; they do not choose AlphaX’s production transport.',
    )
    ..writeln();
  final interpretation = summary['interpretation'] as List<Object?>;
  for (final item in interpretation.cast<Map<String, Object?>>()) {
    buffer.writeln('- `${item['scenario']}`: ${item['assessment']}.');
  }
  return buffer.toString();
}

String _milliseconds(Object? microseconds) {
  if (microseconds is! num) {
    return 'unavailable';
  }
  return (microseconds / 1000).toStringAsFixed(3);
}

String _megabytesPerSecond(Object? bytesPerSecond) {
  if (bytesPerSecond is! num) {
    return 'unavailable';
  }
  return (bytesPerSecond / (1024 * 1024)).toStringAsFixed(3);
}
