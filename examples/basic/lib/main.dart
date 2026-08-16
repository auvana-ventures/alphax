import 'dart:async';
import 'dart:io';

import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/material.dart';

const _baseUrl = String.fromEnvironment(
  'ALPHAX_EXAMPLE_BASE_URL',
  defaultValue: 'https://example.com',
);

void main() => runApp(const AlphaXExampleApp());

final class AlphaXExampleApp extends StatefulWidget {
  const AlphaXExampleApp({super.key});

  @override
  State<AlphaXExampleApp> createState() => _AlphaXExampleState();
}

final class _AlphaXExampleState extends State<AlphaXExampleApp> {
  late final AlphaXClient _client;
  String _status = 'Ready';

  Uri _uri(String path) => Uri.parse(_baseUrl).resolve(path);

  @override
  void initState() {
    super.initState();
    _client = AlphaXClient(transport: DartIoTransport());
  }

  @override
  void dispose() {
    unawaited(_client.close());
    super.dispose();
  }

  Future<void> _run(String label, Future<String> Function() action) async {
    setState(() => _status = '$label…');
    try {
      final result = await action();
      if (mounted) setState(() => _status = '$label: $result');
    } on AlphaXException catch (error) {
      if (mounted) setState(() => _status = '$label: ${error.kind.name}');
    } catch (error) {
      if (mounted) setState(() => _status = '$label: $error');
    }
  }

  Future<String> _get() async {
    final response = await _client.get(
      _uri('/'),
      protocolPreference: AlphaXProtocolPreference.http3,
    );
    final body = await response.readAsString();
    final finalMetrics = await response.completionMetrics;
    final fallback = await response.completionProtocolFallback;
    return 'HTTP ${response.statusCode}, ${body.length} chars, '
        'protocol ${finalMetrics.negotiatedProtocol.name}, '
        'fallback ${fallback?.negotiated.name ?? 'none'}';
  }

  Future<String> _requireH3() async {
    try {
      final response = await _client.get(
        _uri('/'),
        protocolPreference: AlphaXProtocolPreference.http3,
        protocolRequirement: AlphaXProtocolRequirement.http3,
      );
      final metrics = await response.completionMetrics;
      return 'H3 requirement met: ${metrics.negotiatedProtocol.name}';
    } on AlphaXException catch (error) {
      return 'H3 requirement failed closed: ${error.kind.name}';
    }
  }

  Future<String> _cancel() async {
    final token = AlphaXCancellationToken();
    final pending = _client.get(_uri('/delay/1000'), cancellationToken: token);
    token.cancel('example cancellation');
    try {
      await pending;
    } on AlphaXCancellationException {
      return 'cancelled';
    }
    return 'request completed before cancellation';
  }

  Future<String> _stream() async {
    final response = await _client.get(_uri('/stream/3/16'));
    var bytes = 0;
    await for (final chunk in response.stream) {
      bytes += chunk.length;
    }
    return '$bytes streamed bytes';
  }

  Future<String> _files() async {
    final directory = await Directory.systemTemp.createTemp('alphax-example-');
    final path = '${directory.path}/payload.bin';
    try {
      final download = await _client.download(
        _uri('/bytes/32'),
        to: AlphaXLocalFileTarget(path),
      );
      final upload = await _client.upload(
        _uri('/upload'),
        from: AlphaXLocalFileSource(path),
      );
      return '${download.bytesTransferred} downloaded, '
          '${upload.bytesTransferred} uploaded';
    } finally {
      await directory.delete(recursive: true);
    }
  }

  String _capabilities() {
    final capabilities = _client.capabilities;
    return 'H1=${capabilities.http11.name}, '
        'H2=${capabilities.http2.name}, H3=${capabilities.http3.name}';
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('AlphaX example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(_status),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _run('GET', _get),
            child: const Text('GET'),
          ),
          FilledButton(
            onPressed: () => _run('Require H3', _requireH3),
            child: const Text('Require HTTP/3'),
          ),
          FilledButton(
            onPressed: () => _run('Cancel', _cancel),
            child: const Text('Cancel request'),
          ),
          FilledButton(
            onPressed: () => _run('Stream', _stream),
            child: const Text('Stream response'),
          ),
          FilledButton(
            onPressed: () => _run('Files', _files),
            child: const Text('Download/upload file'),
          ),
          FilledButton(
            onPressed: () => setState(() => _status = _capabilities()),
            child: const Text('Show capabilities'),
          ),
        ],
      ),
    ),
  );
}
