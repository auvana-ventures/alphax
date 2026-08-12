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

    final candidates = _candidates(options.candidateName);
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
  final metadata = await collectBenchmarkMetadata();
  metadata['base_url'] = baseUri.toString();
  metadata['warmup_iterations'] = options.warmupIterations;
  metadata['measured_iterations'] = options.measuredIterations;
  metadata['methodology'] = <String, Object?>{
    'statistics': <String>['mean', 'p50', 'p95', 'p99', 'standard deviation'],
    'p99_minimum_sample_count': 20,
    'raw_samples': true,
    'json_decode_in_transport_samples': false,
    'connection_reuse': 'candidate behavior is recorded; no reuse claim is inferred',
    'large_transfer_scope': <int>[10 * 1024 * 1024, 100 * 1024 * 1024],
  };
  return metadata;
}

Future<void> _runIsolatedCandidates(_RunnerOptions options) async {
  final temporary = await Directory.systemTemp.createTemp('alphax-benchmark-candidates-');
  try {
    final documents = <Map<String, Object?>>[];
    for (final candidate in _candidateNames) {
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
        '--output',
        childOutput.path,
      ];
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
    firstMetadata
      ..remove('base_url')
      ..['candidate_process_isolation'] = true
      ..['candidate_order'] = _candidateNames;
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
  final stem = 'macos-local-$commit';
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

List<BenchmarkCandidate> _candidates(String? filter) {
  final curlPath = Platform.environment['ALPHAX_CURL_LIBRARY'];
  final rustPath = Platform.environment['ALPHAX_RUST_LIBRARY'];
  if (curlPath == null || curlPath.isEmpty || rustPath == null || rustPath.isEmpty) {
    throw StateError(
      'Set ALPHAX_CURL_LIBRARY and ALPHAX_RUST_LIBRARY before running a comparable dataset',
    );
  }
  final candidates = <BenchmarkCandidate>[
    BenchmarkCandidate(name: 'dart_io', create: DartIoTransport.new),
    BenchmarkCandidate(name: 'rust_reqwest_ffi', create: () => RustFfiClient.fromPath(rustPath)),
    BenchmarkCandidate(name: 'libcurl_ffi', create: () => CurlFfiClient.fromPath(curlPath)),
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
  });

  final Uri? baseUri;
  final String outputDirectory;
  final int warmupIterations;
  final int measuredIterations;
  final bool correctnessOnly;
  final String? candidateName;

  static _RunnerOptions parse(List<String> args) {
    Uri? baseUri;
    var outputDirectory = 'benchmarks/results';
    var warmupIterations = 3;
    var measuredIterations = 10;
    var correctnessOnly = false;
    String? candidateName;
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
        case '--correctness-only':
          correctnessOnly = true;
        case '--candidate':
          candidateName = args[++index];
        case '--help':
          stdout.writeln('''Usage: dart run bin/run_benchmarks.dart [options]
  --base-url URL      Use an existing benchmark server; otherwise start one
  --output DIR        Results directory (default: benchmarks/results)
  --warmup N          Warmup iterations (default: 3)
  --iterations N      Measured iterations (default: 10)
  --correctness-only  Run correctness checks without performance scenarios
  --candidate NAME     Diagnostic filter: dart_io, libcurl_ffi, or rust_reqwest_ffi
''');
          exit(0);
        default:
          throw FormatException('Unknown argument: ${args[index]}');
      }
    }
    if (warmupIterations < 0 || measuredIterations < 2) {
      throw FormatException('warmup must be >= 0 and iterations must be >= 2');
    }
    return _RunnerOptions(
      baseUri: baseUri,
      outputDirectory: outputDirectory,
      warmupIterations: warmupIterations,
      measuredIterations: measuredIterations,
      correctnessOnly: correctnessOnly,
      candidateName: candidateName,
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
        final medians = <String, num>{
          for (final row in rows)
            if (row['candidate'] is String &&
                row['stats'] is Map<String, Object?> &&
                (row['stats']! as Map<String, Object?>)['p50_us'] is num)
              row['candidate'] as String: (row['stats']! as Map<String, Object?>)['p50_us']! as num,
        };
        final ordered = medians.entries.toList()
          ..sort((left, right) => left.value.compareTo(right.value));
        final note = ordered.length < 2
            ? 'only one candidate has measured samples'
            : ordered[1].value / ordered.first.value <= 1.05
            ? 'approximately equivalent by p50 (within 5% of the fastest observed candidate)'
            : '${ordered.first.key} has the lowest observed p50; this is scenario-local, not an overall score';
        return <String, Object?>{
          'scenario': entry.key,
          'assessment': note,
          'p50_order': ordered.map((item) => item.key).toList(),
        };
      }(),
  ];
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
    ..writeln('| Candidate | Scenario | N | p50 (ms) | p95 (ms) | TTFB p50 (ms) | Mean MB/s |')
    ..writeln('| --- | --- | ---: | ---: | ---: | ---: | ---: |');
  final scenarios = summary['scenario_summaries'] as List<Object?>;
  for (final item in scenarios.cast<Map<String, Object?>>()) {
    final stats = item['stats'] as Map<String, Object?>;
    buffer.writeln(
      '| ${item['candidate']} | ${item['scenario']} | ${stats['count']} | ${_milliseconds(stats['p50_us'])} | ${_milliseconds(stats['p95_us'])} | ${_milliseconds(stats['ttfb_p50_us'])} | ${_megabytesPerSecond(stats['mean_throughput_bytes_per_second'])} |',
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
