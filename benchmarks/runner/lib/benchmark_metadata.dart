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
  };
  final commit = await _command('git', <String>['rev-parse', 'HEAD']);
  metadata['git_commit'] = commit;
  return metadata;
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
