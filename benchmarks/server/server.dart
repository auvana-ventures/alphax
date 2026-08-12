import 'dart:async';
import 'dart:io';

import 'package:alphax_benchmark_server/benchmark_server.dart';

Future<void> main(List<String> args) async {
  final options = BenchmarkServerOptions.parse(args);
  final server = BenchmarkServer(host: options.host, port: options.port);
  await server.start();
  stdout.writeln('AlphaX benchmark server listening on ${server.baseUri}');

  ProcessSignal.sigint.watch().listen((_) {
    unawaited(server.close());
  });

  await server.done;
}
