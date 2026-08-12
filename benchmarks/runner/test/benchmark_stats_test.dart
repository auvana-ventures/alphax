import 'package:alphax_benchmark_runner/alphax_benchmark_runner.dart';
import 'package:test/test.dart';

void main() {
  test('computes deterministic summary statistics', () {
    final stats = BenchmarkStats(<int>[5, 1, 3, 9, 7]);

    expect(stats.count, 5);
    expect(stats.min, 1);
    expect(stats.max, 9);
    expect(stats.percentile(0.50), 5);
    expect(stats.percentile(0.95), 9);
    expect(stats.toJson()['p99_us'], isNull);
    expect(stats.toJson()['mean_us'], 5.0);
  });

  test('reports p99 only when the sample count supports it', () {
    final stats = BenchmarkStats(List<int>.generate(20, (index) => index));

    expect(stats.toJson()['p99_us'], 19);
  });

  test('groups raw samples without an overall score', () {
    final summaries = summarizeSamples(<Map<String, Object?>>[
      <String, Object?>{'candidate': 'dart_io', 'scenario': 'small_1024_warm', 'elapsed_us': 10},
      <String, Object?>{'candidate': 'dart_io', 'scenario': 'small_1024_warm', 'elapsed_us': 20},
    ]);

    expect(summaries, hasLength(1));
    expect(summaries.single['candidate'], 'dart_io');
    expect(summaries.single['scenario'], 'small_1024_warm');
  });
}
