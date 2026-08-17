import 'dart:async';

import 'package:alphax/alphax.dart';
import 'package:flutter/foundation.dart';

import '../data/waypoint_repository.dart';
import '../domain/models.dart';

final class WaypointController extends ChangeNotifier {
  WaypointController(this.repository, {this.startupMessage});

  final WaypointRepository repository;
  final String? startupMessage;

  WaypointHomeData? home;
  WaypointTrip? selectedTrip;
  bool showingTrip = false;
  WaypointSection section = WaypointSection.trips;
  List<WaypointPlace> searchResults = const <WaypointPlace>[];
  String searchQuery = '';
  List<WaypointActivity> liveActivities = const <WaypointActivity>[];
  String? message;
  bool isLoading = true;
  bool isSearching = false;
  bool isLive = false;
  bool isTransferring = false;
  double? transferProgress;
  WaypointProtocolProbe? lastProbe;

  AlphaXCancellationToken? _searchCancellation;
  AlphaXCancellationToken? _activityCancellation;
  int _searchGeneration = 0;

  List<WaypointPlace> get visiblePlaces => searchQuery.trim().isEmpty
      ? home?.places ?? const <WaypointPlace>[]
      : searchResults;

  List<WaypointActivity> get activities => liveActivities.isEmpty
      ? home?.activities ?? const <WaypointActivity>[]
      : liveActivities;

  AlphaXCapabilities get capabilities => repository.capabilities;

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    try {
      home = await repository.loadHome();
      final trips = home?.trips ?? const <WaypointTrip>[];
      selectedTrip = trips.isEmpty ? null : trips.first;
      searchResults = home?.places ?? const <WaypointPlace>[];
      message = startupMessage;
    } catch (error) {
      message = _friendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectSection(WaypointSection value) {
    section = value;
    notifyListeners();
  }

  Future<void> selectTrip(WaypointTrip trip) async {
    selectedTrip = trip;
    notifyListeners();
    try {
      selectedTrip = await repository.loadTrip(trip.id);
    } catch (error) {
      message = _friendlyError(error);
    }
    notifyListeners();
  }

  Future<void> openTrip(WaypointTrip trip) async {
    showingTrip = true;
    await selectTrip(trip);
  }

  void closeTrip() {
    showingTrip = false;
    notifyListeners();
  }

  Future<void> search(String value) async {
    searchQuery = value;
    _searchCancellation?.cancel('A newer search started');
    final generation = ++_searchGeneration;
    final query = value.trim();
    if (query.isEmpty) {
      searchResults = home?.places ?? const <WaypointPlace>[];
      isSearching = false;
      notifyListeners();
      return;
    }

    final token = AlphaXCancellationToken();
    _searchCancellation = token;
    isSearching = true;
    notifyListeners();
    try {
      searchResults = await repository.searchPlaces(
        query,
        cancellationToken: token,
      );
    } catch (error) {
      if (error is! AlphaXCancellationException) {
        message = _friendlyError(error);
      }
    } finally {
      if (generation == _searchGeneration) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleLiveActivity() async {
    if (isLive) {
      _activityCancellation?.cancel('Activity stream stopped by the user');
      isLive = false;
      notifyListeners();
      return;
    }

    _activityCancellation = AlphaXCancellationToken();
    liveActivities = <WaypointActivity>[];
    isLive = true;
    message = 'Listening for itinerary updates…';
    notifyListeners();
    try {
      await for (final activity in repository.watchActivity(
        cancellationToken: _activityCancellation,
      )) {
        liveActivities = <WaypointActivity>[activity, ...liveActivities];
        notifyListeners();
      }
      message = 'Activity stream complete.';
    } catch (error) {
      if (error is! AlphaXCancellationException) {
        message = _friendlyError(error);
      }
    } finally {
      isLive = false;
      notifyListeners();
    }
  }

  Future<void> transfer({required bool upload}) async {
    final trip = selectedTrip;
    if (trip == null || isTransferring) {
      return;
    }
    isTransferring = true;
    transferProgress = 0;
    message = upload ? 'Uploading a travel note…' : 'Preparing your itinerary…';
    notifyListeners();
    final token = AlphaXCancellationToken();
    try {
      final result = upload
          ? await repository.uploadNote(
              trip.id,
              cancellationToken: token,
              onProgress: _updateTransferProgress,
            )
          : await repository.downloadItinerary(
              trip.id,
              cancellationToken: token,
              onProgress: _updateTransferProgress,
            );
      message =
          '${result.operation} · ${result.bytes} bytes · ${result.protocol.name.toUpperCase()}';
    } catch (error) {
      message = _friendlyError(error);
    } finally {
      isTransferring = false;
      transferProgress = null;
      notifyListeners();
    }
  }

  void _updateTransferProgress(AlphaXProgress progress) {
    final total = progress.totalBytes;
    transferProgress = total == null || total == 0
        ? null
        : progress.bytesTransferred / total;
    notifyListeners();
  }

  Future<void> probe({bool requireHttp3 = false}) async {
    message = requireHttp3
        ? 'Checking whether H3 can be required…'
        : 'Checking the preferred protocol…';
    notifyListeners();
    try {
      lastProbe = await repository.probe(
        preference: AlphaXProtocolPreference.http3,
        requirement: requireHttp3 ? AlphaXProtocolRequirement.http3 : null,
      );
      final fallback = lastProbe?.fallback;
      message = fallback == null
          ? 'The request completed with ${lastProbe!.protocol.name.toUpperCase()}.'
          : 'H3 was preferred; the request truthfully fell back to ${lastProbe!.protocol.name.toUpperCase()}.';
    } catch (error) {
      message = _friendlyError(error);
    }
    notifyListeners();
  }

  Future<void> close() async {
    _searchCancellation?.cancel('Waypoint is closing');
    _activityCancellation?.cancel('Waypoint is closing');
    await repository.close();
  }

  String _friendlyError(Object error) {
    if (error is AlphaXProtocolRequirementException) {
      return 'Required H3 was not negotiated, so AlphaX failed closed as requested.';
    }
    if (error is AlphaXCancellationException) {
      return 'The operation was cancelled safely.';
    }
    if (error is AlphaXException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
