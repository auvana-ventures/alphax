import 'dart:async';
import 'dart:convert';

import 'package:alphax/alphax.dart';

import '../domain/models.dart';
import 'demo_waypoint_transport.dart';
import 'waypoint_activity_stream.dart';
import 'waypoint_file.dart';
import 'waypoint_json.dart';

abstract interface class WaypointDataSource {
  String get name;

  AlphaXCapabilities get capabilities;

  AlphaXTlsPolicy get tlsPolicy;

  AlphaXProxyPolicy get proxyPolicy;

  bool get isDemo;

  Future<WaypointHomeData> loadHome({
    AlphaXCancellationToken? cancellationToken,
  });

  Future<List<WaypointPlace>> searchPlaces(
    String query, {
    AlphaXCancellationToken? cancellationToken,
  });

  Future<WaypointTrip> loadTrip(
    String id, {
    AlphaXCancellationToken? cancellationToken,
  });

  Stream<WaypointActivity> watchActivity({
    AlphaXCancellationToken? cancellationToken,
  });

  Future<WaypointTransferSummary> downloadItinerary(
    String tripId, {
    AlphaXCancellationToken? cancellationToken,
    AlphaXProgressCallback? onProgress,
  });

  Future<WaypointTransferSummary> uploadNote(
    String tripId, {
    AlphaXCancellationToken? cancellationToken,
    AlphaXProgressCallback? onProgress,
  });

  Future<WaypointProtocolProbe> probe({
    AlphaXProtocolPreference preference = AlphaXProtocolPreference.http3,
    AlphaXProtocolRequirement? requirement,
  });

  Future<void> close();
}

class AlphaXWaypointDataSource implements WaypointDataSource {
  AlphaXWaypointDataSource({
    required this.client,
    required Uri baseUri,
    this.name = 'AlphaX client',
  }) : baseUri = _withTrailingSlash(baseUri);

  final AlphaXClient client;
  final Uri baseUri;

  @override
  final String name;

  @override
  AlphaXCapabilities get capabilities => client.capabilities;

  @override
  AlphaXTlsPolicy get tlsPolicy => client.tlsPolicy;

  @override
  AlphaXProxyPolicy get proxyPolicy => client.proxyPolicy;

  @override
  bool get isDemo => false;

  @override
  Future<WaypointHomeData> loadHome({
    AlphaXCancellationToken? cancellationToken,
  }) async {
    final response = await _get(
      'api/home',
      cancellationToken: cancellationToken,
    );
    return WaypointJson.decodeHome(await response.readAsJson());
  }

  @override
  Future<List<WaypointPlace>> searchPlaces(
    String query, {
    AlphaXCancellationToken? cancellationToken,
  }) async {
    final response = await _get(
      'api/search',
      query: <String, String>{'q': query},
      cancellationToken: cancellationToken,
    );
    return WaypointJson.decodePlaces(await response.readAsJson());
  }

  @override
  Future<WaypointTrip> loadTrip(
    String id, {
    AlphaXCancellationToken? cancellationToken,
  }) async {
    final response = await _get(
      'api/trips/$id',
      cancellationToken: cancellationToken,
    );
    return WaypointJson.decodeTrip(await response.readAsJson());
  }

  @override
  Stream<WaypointActivity> watchActivity({
    AlphaXCancellationToken? cancellationToken,
  }) async* {
    final decoder = WaypointActivityStreamDecoder();
    await for (final event in client.sendStreaming(
      AlphaXRequest(
        method: HttpMethod.get,
        uri: _uri('api/activity'),
        cancellationToken: cancellationToken,
        timeout: const AlphaXTimeouts(read: Duration(seconds: 10)),
      ),
    )) {
      switch (event) {
        case AlphaXResponseStarted(:final statusCode):
          if (statusCode < 200 || statusCode >= 300) {
            throw WaypointDataException(
              'Activity stream failed',
              statusCode: statusCode,
            );
          }
        case AlphaXResponseChunk(:final bytes):
          decoder.add(bytes);
          for (final value in decoder.drain()) {
            yield WaypointJson.decodeActivity(value);
          }
        case AlphaXResponseCompleted():
          decoder.close();
          for (final value in decoder.drain()) {
            yield WaypointJson.decodeActivity(value);
          }
      }
    }
  }

  @override
  Future<WaypointTransferSummary> downloadItinerary(
    String tripId, {
    AlphaXCancellationToken? cancellationToken,
    AlphaXProgressCallback? onProgress,
  }) async {
    final target = WaypointMemoryFileTarget(name: '$tripId-itinerary.pdf');
    final result = await client.download(
      _uri('api/trips/$tripId/itinerary'),
      to: target,
      cancellationToken: cancellationToken,
      onDownloadProgress: onProgress,
    );
    if (!result.isSuccessful) {
      throw WaypointDataException(
        'Itinerary download failed',
        statusCode: result.statusCode,
      );
    }
    return WaypointTransferSummary(
      operation: 'Downloaded itinerary',
      bytes: result.bytesTransferred,
      protocol: result.protocol,
    );
  }

  @override
  Future<WaypointTransferSummary> uploadNote(
    String tripId, {
    AlphaXCancellationToken? cancellationToken,
    AlphaXProgressCallback? onProgress,
  }) async {
    final source = WaypointMemoryFileSource(
      utf8.encode('A note added from the Waypoint documents screen.'),
      name: '$tripId-note.txt',
    );
    final result = await client.upload(
      _uri('api/documents'),
      from: source,
      cancellationToken: cancellationToken,
      headers: AlphaXHeaders({'content-type': 'text/plain'}),
      onUploadProgress: onProgress,
    );
    if (!result.isSuccessful) {
      throw WaypointDataException(
        'Travel note upload failed',
        statusCode: result.statusCode,
      );
    }
    return WaypointTransferSummary(
      operation: 'Uploaded travel note',
      bytes: result.bytesTransferred,
      protocol: result.protocol,
    );
  }

  @override
  Future<WaypointProtocolProbe> probe({
    AlphaXProtocolPreference preference = AlphaXProtocolPreference.http3,
    AlphaXProtocolRequirement? requirement,
  }) async {
    final response = await client.get(
      _uri('api/probe'),
      protocolPreference: preference,
      protocolRequirement: requirement,
    );
    final metrics = await response.completionMetrics;
    return WaypointProtocolProbe(
      protocol: metrics.negotiatedProtocol,
      preference: preference,
      fallback:
          response.protocolFallback ??
          await response.completionProtocolFallback,
      metrics: metrics,
    );
  }

  @override
  Future<void> close() => client.close();

  Future<AlphaXResponse> _get(
    String path, {
    Map<String, String> query = const <String, String>{},
    AlphaXCancellationToken? cancellationToken,
  }) async {
    final response = await client.get(
      _uri(path, query: query),
      cancellationToken: cancellationToken,
      timeout: const AlphaXTimeouts(
        connect: Duration(seconds: 5),
        request: Duration(seconds: 8),
        read: Duration(seconds: 8),
      ),
    );
    if (!response.isSuccessful) {
      throw WaypointDataException(
        'Waypoint request failed',
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  Uri _uri(
    String path, {
    Map<String, String> query = const <String, String>{},
  }) => baseUri
      .resolve(path)
      .replace(queryParameters: query.isEmpty ? null : query);

  static Uri _withTrailingSlash(Uri value) =>
      value.path.endsWith('/') ? value : value.replace(path: '${value.path}/');
}

final class DemoWaypointDataSource extends AlphaXWaypointDataSource {
  DemoWaypointDataSource()
    : super(
        client: AlphaXClient(transport: WaypointDemoTransport()),
        baseUri: Uri.parse('https://waypoint.demo/'),
        name: 'AlphaX demo client',
      );

  @override
  bool get isDemo => true;
}
