import 'dart:io';

import '../../../benchmarks/client/benchmark_support.dart';
import '../lib/rust_ffi.dart';

Future<void> main(List<String> args) async {
  try {
    final options = BenchmarkOptions.parse(args, client: 'rust_reqwest_ffi');
    final client = RustFfiClient.fromEnvironment();
    final samples = <BenchmarkSample>[];
    for (var start = 0; start < options.requests; start += options.concurrency) {
      final batchSize = (options.requests - start).clamp(0, options.concurrency);
      samples.addAll(
        List<BenchmarkSample>.generate(
          batchSize,
          (_) {
            final result = client.get(options.url);
            return BenchmarkSample(
              elapsed: Duration(microseconds: (result.totalMs * 1000).round()),
              statusCode: result.statusCode.toInt(),
              bytes: result.bytesReceived,
            );
          },
          growable: false,
        ),
      );
    }
    stdout.writeln(encodeBenchmarkResult(options, samples));
  } catch (error, stackTrace) {
    stderr.writeln('$error\n$stackTrace');
    exitCode = 1;
  }
}
