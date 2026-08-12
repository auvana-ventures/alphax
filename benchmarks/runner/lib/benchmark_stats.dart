import 'dart:math' as math;

/// Statistical summary for a finite sample set.
final class BenchmarkStats {
  /// Computes statistics from microsecond samples.
  BenchmarkStats(Iterable<int> values) : values = List<int>.of(values)..sort() {
    if (this.values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'must not be empty');
    }
  }

  /// Sorted samples retained for auditability.
  final List<int> values;

  /// Sample count.
  int get count => values.length;

  /// Arithmetic mean.
  double get mean => values.fold<int>(0, (sum, value) => sum + value) / count;

  /// Minimum sample.
  int get min => values.first;

  /// Maximum sample.
  int get max => values.last;

  /// Population standard deviation.
  double get standardDeviation {
    final average = mean;
    final variance =
        values.fold<double>(0, (sum, value) {
          final difference = value - average;
          return sum + difference * difference;
        }) /
        count;
    return math.sqrt(variance);
  }

  /// Returns a nearest-rank percentile.
  int percentile(double percentile) {
    if (percentile < 0 || percentile > 1) {
      throw ArgumentError.value(percentile, 'percentile', 'must be between 0 and 1');
    }
    final index = math.max(0, math.min(count - 1, (percentile * count).ceil() - 1));
    return values[index];
  }

  /// JSON-friendly representation.
  Map<String, Object?> toJson() => <String, Object?>{
    'count': count,
    'min_us': min,
    'mean_us': mean,
    'p50_us': percentile(0.50),
    'p95_us': percentile(0.95),
    // A p99 from fewer than 20 samples is just the maximum and is not useful
    // as a percentile estimate; retain the field but report it unavailable.
    'p99_us': count >= 20 ? percentile(0.99) : null,
    'max_us': max,
    'stddev_us': standardDeviation,
  };
}

/// Groups raw runner samples into scenario/candidate summaries.
List<Map<String, Object?>> summarizeSamples(List<Map<String, Object?>> samples) {
  final groups = <String, List<Map<String, Object?>>>{};
  for (final sample in samples) {
    final candidate = sample['candidate'];
    final scenario = sample['scenario'];
    final elapsed = sample['elapsed_us'];
    if (candidate is! String || scenario is! String || elapsed is! num) {
      continue;
    }
    groups.putIfAbsent('$candidate::$scenario', () => <Map<String, Object?>>[]).add(sample);
  }
  return [
    for (final entry in groups.entries)
      () {
        final elapsed = <int>[
          for (final sample in entry.value) (sample['elapsed_us']! as num).toInt(),
        ];
        final ttfb = <int>[
          for (final sample in entry.value)
            if (sample['ttfb_us'] is num) (sample['ttfb_us']! as num).toInt(),
        ];
        final throughput = <double>[
          for (final sample in entry.value)
            if (sample['throughput_bytes_per_second'] is num)
              (sample['throughput_bytes_per_second']! as num).toDouble(),
        ];
        final bytes = <int>[
          for (final sample in entry.value)
            (sample['bytes'] is num ? sample['bytes']! as num : 0).toInt(),
        ];
        final stats = BenchmarkStats(elapsed).toJson();
        if (ttfb.isNotEmpty) {
          stats['ttfb_p50_us'] = BenchmarkStats(ttfb).percentile(0.5);
        }
        if (throughput.isNotEmpty) {
          stats['mean_throughput_bytes_per_second'] =
              throughput.fold<double>(0, (sum, value) => sum + value) / throughput.length;
        }
        stats['mean_bytes'] = bytes.fold<int>(0, (sum, value) => sum + value) / bytes.length;
        return <String, Object?>{
          'candidate': entry.key.substring(0, entry.key.indexOf('::')),
          'scenario': entry.key.substring(entry.key.indexOf('::') + 2),
          'stats': stats,
        };
      }(),
  ];
}
