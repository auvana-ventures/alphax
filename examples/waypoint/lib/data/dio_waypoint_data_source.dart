import 'dart:async';
import 'dart:convert';
import 'package:alphax/alphax.dart';
import 'package:alphax_dio/alphax_dio.dart';
import 'package:dio/dio.dart';

import '../domain/models.dart';
import 'demo_waypoint_transport.dart';
import 'waypoint_activity_stream.dart';
import 'waypoint_data_source.dart';
import 'waypoint_file.dart';
import 'waypoint_json.dart';

final class DioWaypointDataSource implements WaypointDataSource {
  DioWaypointDataSource({
    required this.client,
    required Uri baseUri,
    this.name = 'Dio + AlphaX adapter',
    this.isDemo = false,
  }) : baseUri = _withTrailingSlash(baseUri),
       _dio = Dio(
         BaseOptions(baseUrl: _withTrailingSlash(baseUri).toString()),
       ) {
    _dio.httpClientAdapter = AlphaXDioAdapter(client, closeClient: false);
  }

  factory DioWaypointDataSource.demo() => DioWaypointDataSource(
    client: AlphaXClient(transport: WaypointDemoTransport()),
    baseUri: Uri.parse('https://waypoint.demo/'),
    name: 'Dio + AlphaX demo adapter',
    isDemo: true,
  );

  final AlphaXClient client;
  final Dio _dio;
  final Uri baseUri;

  @override
  final String name;

  @override
  final bool isDemo;

  @override
  AlphaXCapabilities get capabilities => client.capabilities;

  @override
  AlphaXTlsPolicy get tlsPolicy => client.tlsPolicy;

  @override
  AlphaXProxyPolicy get proxyPolicy => client.proxyPolicy;

  @override
  Future<WaypointHomeData> loadHome({
    AlphaXCancellationToken? cancellationToken,
  }) async {
    final response = await _get(
      'api/home',
      cancellationToken: cancellationToken,
    );
    return WaypointJson.decodeHome(response.data);
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
    return WaypointJson.decodePlaces(response.data);
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
    return WaypointJson.decodeTrip(response.data);
  }

  @override
  Stream<WaypointActivity> watchActivity({
    AlphaXCancellationToken? cancellationToken,
  }) async* {
    try {
      final response = await _dio.get<ResponseBody>(
        'api/activity',
        cancelToken: _cancelToken(cancellationToken),
        options: Options(responseType: ResponseType.stream),
      );
      final statusCode = response.statusCode ?? 500;
      if (statusCode < 200 || statusCode >= 300) {
        throw WaypointDataException(
          'Activity stream failed',
          statusCode: statusCode,
        );
      }
      final body = response.data;
      if (body == null) {
        throw const WaypointDataException('Activity stream returned no body');
      }
      final decoder = WaypointActivityStreamDecoder();
      await for (final chunk in body.stream) {
        cancellationToken?.throwIfCancelled();
        decoder.add(chunk);
        for (final value in decoder.drain()) {
          yield* _decodeActivities(value);
        }
      }
      decoder.close();
      for (final value in decoder.drain()) {
        yield* _decodeActivities(value);
      }
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        throw const AlphaXCancellationException(
          'The Dio request was cancelled',
        );
      }
      throw WaypointDataException(error.message ?? 'Dio request failed');
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
    final result = await client.upload(
      _uri('api/documents'),
      from: WaypointMemoryFileSource(
        utf8.encode('A note added from the Waypoint documents screen.'),
        name: '$tripId-note.txt',
      ),
      cancellationToken: cancellationToken,
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
  Future<void> close() async {
    _dio.close(force: true);
    await client.close();
  }

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, String> query = const <String, String>{},
    AlphaXCancellationToken? cancellationToken,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        cancelToken: _cancelToken(cancellationToken),
      );
      if ((response.statusCode ?? 500) < 200 ||
          (response.statusCode ?? 500) >= 300) {
        throw WaypointDataException(
          'Waypoint request failed',
          statusCode: response.statusCode,
        );
      }
      return response;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        throw const AlphaXCancellationException(
          'The Dio request was cancelled',
        );
      }
      throw WaypointDataException(error.message ?? 'Dio request failed');
    }
  }

  CancelToken? _cancelToken(AlphaXCancellationToken? token) {
    if (token == null) {
      return null;
    }
    final cancelToken = CancelToken();
    unawaited(
      token.whenCancelled.then<void>((_) {
        cancelToken.cancel('AlphaX cancellation');
      }),
    );
    return cancelToken;
  }

  Uri _uri(String path) => baseUri.resolve(path);

  Stream<WaypointActivity> _decodeActivities(Object? decoded) async* {
    if (decoded is List) {
      for (final value in decoded) {
        yield WaypointJson.decodeActivity(value);
      }
    } else if (decoded is Map && decoded['activities'] is List) {
      for (final value in decoded['activities'] as List) {
        yield WaypointJson.decodeActivity(value);
      }
    } else {
      yield WaypointJson.decodeActivity(decoded);
    }
  }

  static Uri _withTrailingSlash(Uri value) =>
      value.path.endsWith('/') ? value : value.replace(path: '${value.path}/');
}
