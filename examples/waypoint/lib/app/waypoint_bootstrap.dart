import 'package:alphax/alphax.dart';
import 'package:alphax_native/alphax_native.dart';
import 'package:flutter/foundation.dart';

import '../data/dio_waypoint_data_source.dart';
import '../data/waypoint_data_source.dart';

const waypointMode = String.fromEnvironment(
  'WAYPOINT_MODE',
  defaultValue: 'demo',
);
const waypointClient = String.fromEnvironment(
  'WAYPOINT_CLIENT',
  defaultValue: 'alphax',
);
const waypointBaseUrl = String.fromEnvironment('WAYPOINT_BASE_URL');

Future<WaypointDataSource> createWaypointDataSource() async {
  if (waypointMode != 'network') {
    return waypointClient == 'dio'
        ? DioWaypointDataSource.demo()
        : DemoWaypointDataSource();
  }

  if (waypointBaseUrl.isEmpty) {
    throw StateError(
      'Network mode needs a base URL. Add --dart-define=WAYPOINT_BASE_URL=https://your-fixture-host.',
    );
  }

  final transport = await _createTransport();
  final client = AlphaXClient(
    transport: transport,
    middleware: const <AlphaXMiddleware>[WaypointRequestTagMiddleware()],
  );
  final baseUri = Uri.parse(waypointBaseUrl);
  if (waypointClient == 'dio') {
    return DioWaypointDataSource(client: client, baseUri: baseUri);
  }
  return AlphaXWaypointDataSource(client: client, baseUri: baseUri);
}

Future<AlphaXTransport> _createTransport() => switch (defaultTargetPlatform) {
  TargetPlatform.android => AndroidCronetTransport.create(),
  TargetPlatform.iOS ||
  TargetPlatform.macOS => AppleUrlSessionTransport.create(),
  _ => Future<AlphaXTransport>.value(DartIoTransport()),
};

final class WaypointRequestTagMiddleware extends AlphaXMiddleware {
  const WaypointRequestTagMiddleware();

  @override
  Future<AlphaXResponse> intercept(AlphaXRequest request, AlphaXNext next) =>
      next(
        request.copyWith(
          headers: request.headers.set('x-waypoint-client', 'reference-app'),
        ),
      );

  @override
  Stream<AlphaXEvent> interceptStream(
    AlphaXRequest request,
    AlphaXStreamNext next,
  ) => next(
    request.copyWith(
      headers: request.headers.set('x-waypoint-client', 'reference-app'),
    ),
  );

  @override
  Future<AlphaXTransferResult> interceptDownload(
    AlphaXRequest request,
    AlphaXFileTarget target,
    AlphaXDownloadNext next,
  ) => next(
    request.copyWith(
      headers: request.headers.set('x-waypoint-client', 'reference-app'),
    ),
    target,
  );

  @override
  Future<AlphaXTransferResult> interceptUpload(
    AlphaXRequest request,
    AlphaXFileSource source,
    AlphaXUploadNext next,
  ) => next(
    request.copyWith(
      headers: request.headers.set('x-waypoint-client', 'reference-app'),
    ),
    source,
  );
}
