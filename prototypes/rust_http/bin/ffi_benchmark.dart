import 'dart:io';

import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';

import '../../../benchmarks/client/benchmark_support.dart';
import '../lib/rust_ffi.dart';

Future<void> main(List<String> args) async {
  try {
    final options = BenchmarkOptions.parse(args, client: 'rust_reqwest_ffi');
    final client = RustFfiClient.fromEnvironment();
    try {
      final samples = <BenchmarkSample>[];
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
      stdout.writeln(encodeBenchmarkResult(options, samples));
    } finally {
      await client.close();
    }
  } catch (error, stackTrace) {
    stderr.writeln('$error\n$stackTrace');
    exitCode = 1;
  }
}

Future<BenchmarkSample> _request(BenchmarkTransport client, Uri url) async {
  final response = await client.getBytes(url);
  return BenchmarkSample(
    elapsed: response.elapsed,
    statusCode: response.statusCode,
    bytes: response.bodyBytes.length,
  );
}
