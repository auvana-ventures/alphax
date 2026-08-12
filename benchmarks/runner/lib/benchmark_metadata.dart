import 'dart:convert';
import 'dart:io';

/// Collects reproducibility metadata without recording local paths or hostnames.
Future<Map<String, Object?>> collectBenchmarkMetadata() async {
  final metadata = <String, Object?>{
    'os': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'architecture': await _command('uname', <String>['-m']),
    'cpu': await _cpuDescription(),
    'dart': Platform.version,
    'flutter': await _flutterVersion(),
    'libcurl': await _command('curl', <String>['--version']),
    'rust': await _command('rustc', <String>['--version']),
    'build_mode': 'Dart VM benchmark; native candidates release library where configured',
    'network_profile': 'localhost; no latency, bandwidth, or packet-loss simulation',
    'protocol_profile':
        'HTTP/1.1-compatible local server; candidate negotiation recorded separately',
    'process_metrics_idle_baseline': (await captureProcessMetrics()).toJson(),
  };
  final commit = await _command('git', <String>['rev-parse', 'HEAD']);
  metadata['git_commit'] = commit;
  metadata['git_worktree_dirty'] = await _gitWorktreeDirty();
  return metadata;
}

Future<bool> _gitWorktreeDirty() async {
  try {
    final result = await Process.run('git', <String>['status', '--porcelain']);
    return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Process-level resource measurements used when component allocation metrics
/// are not available reliably across Dart and native runtimes.
final class BenchmarkProcessMetrics {
  /// Creates one process measurement.
  const BenchmarkProcessMetrics({
    required this.cpuTimeSeconds,
    required this.cpuUtilizationPercent,
    required this.rssBytes,
    required this.maxRssBytes,
  });

  /// Cumulative user+system CPU time reported by `ps`, when available.
  final double? cpuTimeSeconds;

  /// Point-in-time process CPU utilization reported by `ps`, when available.
  final double? cpuUtilizationPercent;

  /// Current resident/physical memory.
  final int? rssBytes;

  /// Peak resident/physical memory reported by the Dart process.
  final int? maxRssBytes;

  /// JSON-friendly representation.
  Map<String, Object?> toJson() => <String, Object?>{
    'cpu_time_seconds': cpuTimeSeconds,
    'cpu_utilization_percent': cpuUtilizationPercent,
    'rss_bytes': rssBytes,
    'max_rss_bytes': maxRssBytes,
  };
}

/// Captures process-level CPU and memory metrics without recording host paths.
Future<BenchmarkProcessMetrics> captureProcessMetrics() async {
  double? cpuTimeSeconds;
  double? cpuUtilizationPercent;
  try {
    final result = await Process.run('ps', <String>['-p', '$pid', '-o', 'cputime=,rss=,%cpu=']);
    if (result.exitCode == 0) {
      final fields = result.stdout.toString().trim().split(RegExp(r'\s+'));
      if (fields.isNotEmpty) {
        cpuTimeSeconds = _parseCpuTime(fields[0]);
      }
      if (fields.length >= 3) {
        cpuUtilizationPercent = double.tryParse(fields[2]);
      }
    }
  } catch (_) {
    // Report unavailable rather than substituting an estimate.
  }
  int? rssBytes;
  try {
    rssBytes = ProcessInfo.currentRss;
  } catch (_) {
    rssBytes = null;
  }
  int? maxRssBytes;
  try {
    maxRssBytes = ProcessInfo.maxRss;
  } catch (_) {
    maxRssBytes = null;
  }
  return BenchmarkProcessMetrics(
    cpuTimeSeconds: cpuTimeSeconds,
    cpuUtilizationPercent: cpuUtilizationPercent,
    rssBytes: rssBytes,
    maxRssBytes: maxRssBytes,
  );
}

double? _parseCpuTime(String value) {
  final fields = value.split(':');
  if (fields.length == 2) {
    final minutes = double.tryParse(fields[0]);
    final seconds = double.tryParse(fields[1]);
    if (minutes != null && seconds != null) {
      return minutes * 60 + seconds;
    }
  }
  if (fields.length == 3) {
    final hours = double.tryParse(fields[0]);
    final minutes = double.tryParse(fields[1]);
    final seconds = double.tryParse(fields[2]);
    if (hours != null && minutes != null && seconds != null) {
      return hours * 3600 + minutes * 60 + seconds;
    }
  }
  return null;
}

Future<Object?> _flutterVersion() async {
  try {
    final result = await Process.run('flutter', <String>['--version', '--machine']);
    if (result.exitCode != 0) {
      return 'unavailable';
    }
    final decoded = jsonDecode(result.stdout.toString());
    if (decoded is! Map) {
      return 'unavailable';
    }
    final sanitized = <String, Object?>{};
    decoded.forEach((key, value) {
      if (key != 'flutterRoot') {
        sanitized[key.toString()] = value;
      }
    });
    return sanitized;
  } catch (_) {
    return 'unavailable';
  }
}

Future<String> _cpuDescription() async {
  if (Platform.isMacOS) {
    return _command('sysctl', <String>['-n', 'machdep.cpu.brand_string']);
  }
  if (Platform.isLinux) {
    return _command('sh', <String>['-c', 'grep -m1 "model name" /proc/cpuinfo']);
  }
  return 'unavailable';
}

Future<String> _command(String executable, List<String> arguments) async {
  try {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      return 'unavailable';
    }
    final value = result.stdout.toString().trim();
    return value.isEmpty ? 'unavailable' : value;
  } catch (_) {
    return 'unavailable';
  }
}
