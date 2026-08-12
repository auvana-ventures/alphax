import 'dart:convert';
import 'dart:io';

/// Common command-line options for Phase 0 benchmark clients.
final class BenchmarkOptions {
  /// Creates benchmark options.
  const BenchmarkOptions({
    required this.client,
    required this.url,
    required this.requests,
    required this.concurrency,
  });

  /// Candidate client name written to results.
  final String client;

  /// Endpoint under test.
  final Uri url;

  /// Number of requests to send.
  final int requests;

  /// Maximum requests issued in a batch.
  final int concurrency;

  /// Parses the shared benchmark flags.
  static BenchmarkOptions parse(List<String> args, {required String client}) {
    var url = Uri.parse('http://127.0.0.1:8080/bytes/1024');
    var requests = 1;
    var concurrency = 1;
    for (var index = 0; index < args.length; index++) {
      switch (args[index]) {
        case '--url':
          url = Uri.parse(args[++index]);
        case '--requests':
          requests = int.parse(args[++index]);
        case '--concurrency':
          concurrency = int.parse(args[++index]);
        case '--help':
          stdout.writeln('''Usage: benchmark.dart [options]
  --url URL             Endpoint to request
  --requests N          Total request count (default: 1)
  --concurrency N       Batch concurrency (default: 1)
''');
          exit(0);
        default:
          throw FormatException('Unknown argument: ${args[index]}');
      }
    }
    if (requests < 1 || concurrency < 1) {
      throw FormatException('requests and concurrency must be positive');
    }
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw FormatException('url must use HTTP or HTTPS');
    }
    return BenchmarkOptions(
      client: client,
      url: url,
      requests: requests,
      concurrency: concurrency,
    );
  }
}

/// One measured request sample.
final class BenchmarkSample {
  /// Creates a sample.
  const BenchmarkSample({required this.elapsed, required this.statusCode, required this.bytes});

  /// Total elapsed request duration.
  final Duration elapsed;

  /// HTTP status code, or `0` when no response was received.
  final int statusCode;

  /// Response bytes consumed.
  final int bytes;
}

/// Encodes common benchmark output as stable JSON.
String encodeBenchmarkResult(BenchmarkOptions options, List<BenchmarkSample> samples) {
  final micros = samples.map((sample) => sample.elapsed.inMicroseconds).toList()..sort();
  final totalBytes = samples.fold<int>(0, (total, sample) => total + sample.bytes);
  final totalMicros = micros.fold<int>(0, (total, value) => total + value);
  final statuses = <String, int>{};
  for (final sample in samples) {
    final key = sample.statusCode.toString();
    statuses[key] = (statuses[key] ?? 0) + 1;
  }
  final result = <String, Object?>{
    'client': options.client,
    'url': options.url.toString(),
    'requests': samples.length,
    'concurrency': options.concurrency,
    'bytes_received': totalBytes,
    'status_counts': statuses,
    'elapsed_us': <String, int>{
      'min': micros.first,
      'p50': micros[micros.length ~/ 2],
      'max': micros.last,
      'average': totalMicros ~/ micros.length,
    },
    'environment': <String, String>{
      'os': Platform.operatingSystem,
      'dart': Platform.version.split(' ').first,
    },
  };
  return const JsonEncoder.withIndent('  ').convert(result);
}
