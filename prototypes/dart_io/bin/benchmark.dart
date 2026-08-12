import 'dart:io';

import '../../../benchmarks/client/benchmark_support.dart';

Future<void> main(List<String> args) async {
  try {
    final options = BenchmarkOptions.parse(args, client: 'dart_io');
    final client = HttpClient()..maxConnectionsPerHost = options.concurrency;
    final samples = <BenchmarkSample>[];
    try {
      for (var start = 0; start < options.requests; start += options.concurrency) {
        final batchSize = (options.requests - start).clamp(0, options.concurrency);
        final batch = await Future.wait<BenchmarkSample>(
          List<Future<BenchmarkSample>>.generate(
            batchSize,
            (_) => _request(client, options.url),
            growable: false,
          ),
        );
        samples.addAll(batch);
      }
    } finally {
      client.close(force: true);
    }
    stdout.writeln(encodeBenchmarkResult(options, samples));
  } catch (error, stackTrace) {
    stderr.writeln('$error\n$stackTrace');
    exitCode = 1;
  }
}

Future<BenchmarkSample> _request(HttpClient client, Uri url) async {
  final stopwatch = Stopwatch()..start();
  var statusCode = 0;
  var bytes = 0;
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    statusCode = response.statusCode;
    await for (final chunk in response) {
      bytes += chunk.length;
    }
  } finally {
    stopwatch.stop();
  }
  return BenchmarkSample(
    elapsed: stopwatch.elapsed,
    statusCode: statusCode,
    bytes: bytes,
  );
}
