import 'package:alphax/alphax.dart';

import '../domain/models.dart';
import 'waypoint_data_source.dart';

final class WaypointRepository {
  const WaypointRepository(this.source);

  final WaypointDataSource source;

  String get name => source.name;

  AlphaXCapabilities get capabilities => source.capabilities;

  AlphaXTlsPolicy get tlsPolicy => source.tlsPolicy;

  AlphaXProxyPolicy get proxyPolicy => source.proxyPolicy;

  bool get isDemo => source.isDemo;

  Future<WaypointHomeData> loadHome({
    AlphaXCancellationToken? cancellationToken,
  }) => source.loadHome(cancellationToken: cancellationToken);

  Future<List<WaypointPlace>> searchPlaces(
    String query, {
    AlphaXCancellationToken? cancellationToken,
  }) => source.searchPlaces(query, cancellationToken: cancellationToken);

  Future<WaypointTrip> loadTrip(
    String id, {
    AlphaXCancellationToken? cancellationToken,
  }) => source.loadTrip(id, cancellationToken: cancellationToken);

  Stream<WaypointActivity> watchActivity({
    AlphaXCancellationToken? cancellationToken,
  }) => source.watchActivity(cancellationToken: cancellationToken);

  Future<WaypointTransferSummary> downloadItinerary(
    String tripId, {
    AlphaXCancellationToken? cancellationToken,
    AlphaXProgressCallback? onProgress,
  }) => source.downloadItinerary(
    tripId,
    cancellationToken: cancellationToken,
    onProgress: onProgress,
  );

  Future<WaypointTransferSummary> uploadNote(
    String tripId, {
    AlphaXCancellationToken? cancellationToken,
    AlphaXProgressCallback? onProgress,
  }) => source.uploadNote(
    tripId,
    cancellationToken: cancellationToken,
    onProgress: onProgress,
  );

  Future<WaypointProtocolProbe> probe({
    AlphaXProtocolPreference preference = AlphaXProtocolPreference.http3,
    AlphaXProtocolRequirement? requirement,
  }) => source.probe(preference: preference, requirement: requirement);

  Future<void> close() => source.close();
}
