import 'dart:async';
import 'dart:convert';

import 'package:alphax/alphax.dart';

final class WaypointDemoTransport extends AlphaXTransport {
  WaypointDemoTransport({this.latency = const Duration(milliseconds: 180)});

  final Duration latency;
  bool _closed = false;

  @override
  AlphaXCapabilities get capabilities => const AlphaXCapabilities(
    transportName: 'Waypoint demo transport',
    transportVersion: 'local-fixture',
    http11: AlphaXSupport.supported,
    streamingUpload: AlphaXSupport.supported,
    streamingDownload: AlphaXSupport.supported,
    uploadProgress: AlphaXSupport.supported,
    downloadProgress: AlphaXSupport.supported,
    tlsDefaultTrust: AlphaXSupport.unsupported,
    systemProxy: AlphaXSupport.unsupported,
    proxyConfiguration: AlphaXSupport.unsupported,
    protocolRequirement: AlphaXSupport.supported,
    negotiatedProtocolReporting: AlphaXSupport.supported,
  );

  @override
  Future<AlphaXResponse> send(AlphaXRequest request) async {
    _ensureOpen();
    await _wait(request.cancellationToken);
    _enforceRequirement(request);

    final path = request.uri.path;
    if (path == '/api/activity') {
      final completion = Completer<AlphaXRequestMetrics>();
      return AlphaXResponse(
        statusCode: 200,
        headers: AlphaXHeaders({'content-type': 'application/x-ndjson'}),
        body: AlphaXResponseBody.stream(_activityBody(request, completion)),
        protocol: AlphaXProtocol.http11,
        requestedProtocol: _requestedProtocol(request),
        requiredProtocol: request.protocolRequirement,
        protocolFallback: _fallback(request),
        completionMetrics: completion.future,
      );
    }
    final body = switch (path) {
      '/api/home' => _json(WaypointFixturePayloads.home),
      '/api/search' => _json({
        'places': _search(request.uri.queryParameters['q']),
      }),
      _ when path.startsWith('/api/trips/') => _json(_trip(path)),
      '/api/documents' => _json({
        'uploaded': true,
        'name': request.body.contentType ?? 'document',
      }),
      '/api/probe' => _json({'ok': true}),
      _ => _json({'error': 'Waypoint demo route not found'}),
    };
    final statusCode = path.startsWith('/api/') ? 200 : 404;
    return _response(request, body, statusCode: statusCode);
  }

  @override
  Stream<AlphaXEvent> sendStreaming(AlphaXRequest request) async* {
    _ensureOpen();
    await _wait(request.cancellationToken);
    _enforceRequirement(request);

    final path = request.uri.path;
    final requestedProtocol = _requestedProtocol(request);
    final fallback = _fallback(request);
    yield AlphaXResponseStarted(
      statusCode: 200,
      headers: AlphaXHeaders({'content-type': 'application/json'}),
      protocol: AlphaXProtocol.unknown,
      requestedProtocol: requestedProtocol,
      requiredProtocol: request.protocolRequirement,
      protocolFallback: null,
    );

    var bytesReceived = 0;
    if (path == '/api/activity') {
      for (final activity in WaypointFixturePayloads.activities) {
        request.cancellationToken?.throwIfCancelled();
        await Future<void>.delayed(latency);
        final bytes = utf8.encode('${jsonEncode(activity)}\n');
        bytesReceived += bytes.length;
        yield AlphaXResponseChunk(bytes);
      }
    } else if (path.contains('/itinerary')) {
      final bytes = utf8.encode(
        'WAYPOINT ITINERARY\nKyoto field notes\nPacked with AlphaX.',
      );
      for (final chunk in _chunks(bytes, 14)) {
        request.cancellationToken?.throwIfCancelled();
        await Future<void>.delayed(latency ~/ 2);
        bytesReceived += chunk.length;
        yield AlphaXResponseChunk(chunk);
      }
    } else {
      final bytes = _json({'error': 'Waypoint demo stream route not found'});
      bytesReceived = bytes.length;
      yield AlphaXResponseChunk(bytes);
    }

    yield AlphaXResponseCompleted(
      metrics: _metrics(bytesReceived),
      bytesReceived: bytesReceived,
      requestedProtocol: requestedProtocol,
      requiredProtocol: request.protocolRequirement,
      protocolFallback: fallback,
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  Stream<List<int>> _activityBody(
    AlphaXRequest request,
    Completer<AlphaXRequestMetrics> completion,
  ) async* {
    var bytesReceived = 0;
    try {
      for (final activity in WaypointFixturePayloads.activities) {
        request.cancellationToken?.throwIfCancelled();
        await Future<void>.delayed(latency);
        final bytes = utf8.encode('${jsonEncode(activity)}\n');
        bytesReceived += bytes.length;
        yield bytes;
      }
      if (!completion.isCompleted) {
        completion.complete(_metrics(bytesReceived));
      }
    } catch (error, stackTrace) {
      if (!completion.isCompleted) {
        completion.completeError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _wait(AlphaXCancellationToken? token) async {
    token?.throwIfCancelled();
    if (latency == Duration.zero) {
      return;
    }
    if (token == null) {
      await Future<void>.delayed(latency);
      return;
    }
    await Future.any<void>(<Future<void>>[
      Future<void>.delayed(latency),
      token.whenCancelled,
    ]);
    token.throwIfCancelled();
  }

  void _ensureOpen() {
    if (_closed) {
      throw const AlphaXClientClosedException(
        'Waypoint demo transport is closed',
      );
    }
  }

  void _enforceRequirement(AlphaXRequest request) {
    final requirement = request.protocolRequirement;
    if (requirement != null &&
        !requirement.isSatisfiedBy(AlphaXProtocol.http11)) {
      throw AlphaXProtocolRequirementException(
        requiredProtocol: requirement,
        actualProtocol: AlphaXProtocol.http11,
      );
    }
  }

  AlphaXResponse _response(
    AlphaXRequest request,
    List<int> body, {
    required int statusCode,
  }) => AlphaXResponse(
    statusCode: statusCode,
    headers: AlphaXHeaders.fromEntries(<MapEntry<String, String>>[
      const MapEntry<String, String>('content-type', 'application/json'),
      MapEntry<String, String>('content-length', '${body.length}'),
    ]),
    bodyBytes: body,
    protocol: AlphaXProtocol.http11,
    requestedProtocol: _requestedProtocol(request),
    requiredProtocol: request.protocolRequirement,
    protocolFallback: _fallback(request),
    metrics: _metrics(body.length),
  );

  AlphaXRequestMetrics _metrics(int bytes) => AlphaXRequestMetrics(
    negotiatedProtocol: AlphaXProtocol.http11,
    totalDuration: const Duration(milliseconds: 180),
    timeToFirstByte: const Duration(milliseconds: 42),
    transferDuration: const Duration(milliseconds: 38),
    downloadedBytes: bytes,
  );

  AlphaXProtocolPreference? _requestedProtocol(AlphaXRequest request) =>
      request.protocolPreference == AlphaXProtocolPreference.auto
      ? null
      : request.protocolPreference;

  AlphaXProtocolFallback? _fallback(AlphaXRequest request) {
    final requested = _requestedProtocol(request);
    if (requested == null || requested == AlphaXProtocolPreference.http11) {
      return null;
    }
    return AlphaXProtocolFallback(
      requested: requested,
      negotiated: AlphaXProtocol.http11,
      reason: AlphaXProtocolFallbackReason.unsupported,
    );
  }

  List<int> _json(Object value) => utf8.encode(jsonEncode(value));

  List<Map<String, Object?>> _search(String? query) {
    final normalized = (query ?? '').trim().toLowerCase();
    return WaypointFixturePayloads.places
        .where((place) {
          if (normalized.isEmpty) {
            return true;
          }
          final haystack =
              '${place['name']} ${place['category']} ${place['location']}'
                  .toLowerCase();
          return haystack.contains(normalized);
        })
        .toList(growable: false);
  }

  Map<String, Object?> _trip(String path) {
    final id = path.split('/').last;
    return WaypointFixturePayloads.trips.firstWhere(
      (trip) => trip['id'] == id,
      orElse: () => WaypointFixturePayloads.trips.first,
    );
  }

  Iterable<List<int>> _chunks(List<int> bytes, int size) sync* {
    for (var offset = 0; offset < bytes.length; offset += size) {
      final end = (offset + size).clamp(0, bytes.length);
      yield bytes.sublist(offset, end);
    }
  }
}

final class WaypointFixturePayloads {
  const WaypointFixturePayloads._();

  static final List<Map<String, Object?>> trips = <Map<String, Object?>>[
    <String, Object?>{
      'id': 'kyoto',
      'title': 'Kyoto, slowly',
      'destination': 'Kyoto, Japan',
      'dateRange': '12–19 Apr 2026',
      'durationLabel': '7 days · 6 nights',
      'coverLabel': 'KYOTO',
      'accent': '#B7D9D0',
      'progress': 0.72,
      'itinerary': <Map<String, Object?>>[
        <String, Object?>{
          'time': '09:00',
          'title': 'Fushimi Inari Taisha',
          'detail': 'Early morning walk through the vermilion gates',
          'category': 'Explore',
          'done': true,
        },
        <String, Object?>{
          'time': '12:30',
          'title': 'Lunch at Omen',
          'detail': 'Handmade udon near Gion',
          'category': 'Eat',
          'done': false,
        },
        <String, Object?>{
          'time': '15:00',
          'title': 'Gion afternoon',
          'detail': 'A quiet route through old machiya streets',
          'category': 'Explore',
          'done': false,
        },
      ],
      'checklist': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Reserve the tea ceremony',
          'detail': 'Gion Hatanaka · 18 Apr',
          'done': true,
        },
        <String, Object?>{
          'title': 'Download rail pass',
          'detail': 'Keep it available offline',
          'done': true,
        },
        <String, Object?>{
          'title': 'Add one rainy-day idea',
          'detail': 'A small museum or bookshop',
          'done': false,
        },
        <String, Object?>{
          'title': 'Share the plan',
          'detail': 'Send the itinerary to your group',
          'done': false,
        },
      ],
      'documents': <Map<String, Object?>>[
        <String, Object?>{
          'name': 'Kyoto itinerary.pdf',
          'kind': 'PDF',
          'sizeLabel': '248 KB',
          'icon': 'description',
        },
        <String, Object?>{
          'name': 'JR pass receipt',
          'kind': 'IMAGE',
          'sizeLabel': '1.2 MB',
          'icon': 'image',
        },
      ],
    },
    <String, Object?>{
      'id': 'lisbon',
      'title': 'A long weekend in Lisbon',
      'destination': 'Lisbon, Portugal',
      'dateRange': '08–11 Jun 2026',
      'durationLabel': '4 days · 3 nights',
      'coverLabel': 'LISBON',
      'accent': '#F3D4B2',
      'progress': 0.28,
      'itinerary': <Map<String, Object?>>[
        <String, Object?>{
          'time': '10:00',
          'title': 'Alfama wander',
          'detail': 'Tiles, viewpoints, and a slow coffee',
          'category': 'Explore',
          'done': false,
        },
        <String, Object?>{
          'time': '19:30',
          'title': 'Dinner at Prado',
          'detail': 'Seasonal plates and Portuguese wine',
          'category': 'Eat',
          'done': false,
        },
      ],
      'checklist': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Choose a hotel',
          'detail': 'Three saved options',
          'done': true,
        },
        <String, Object?>{
          'title': 'Book the train',
          'detail': 'Airport to city centre',
          'done': false,
        },
        <String, Object?>{
          'title': 'Save a fado set',
          'detail': 'Keep one evening open',
          'done': false,
        },
      ],
      'documents': <Map<String, Object?>>[],
    },
  ];

  static final List<Map<String, Object?>> places = <Map<String, Object?>>[
    <String, Object?>{
      'id': 'sora',
      'name': 'Sora Coffee',
      'category': 'Coffee · Quiet morning',
      'kind': 'food',
      'location': 'Higashiyama · 0.8 km',
      'description': 'A tiny counter for thoughtful coffee and warm pastries.',
      'rating': 4.8,
      'distance': '8 min walk',
      'emoji': '☕',
      'accent': '#F1D6B8',
      'saved': true,
    },
    <String, Object?>{
      'id': 'garden',
      'name': 'Shosei-en Garden',
      'category': 'Nature · Quiet route',
      'kind': 'nature',
      'location': 'Shimogyo · 1.4 km',
      'description': 'A calm pond garden hiding behind the city streets.',
      'rating': 4.7,
      'distance': '17 min walk',
      'emoji': '🌿',
      'accent': '#C8DEC3',
      'saved': false,
    },
    <String, Object?>{
      'id': 'higashiyama',
      'name': 'Higashiyama walk',
      'category': 'Culture · Golden hour',
      'kind': 'culture',
      'location': 'Gion · 2.1 km',
      'description':
          'A gentle route from Yasaka to the old lanes above the river.',
      'rating': 4.9,
      'distance': '25 min walk',
      'emoji': '⛩️',
      'accent': '#D7C5E9',
      'saved': true,
    },
    <String, Object?>{
      'id': 'machiya',
      'name': 'Mamebashi Stay',
      'category': 'Stay · Design-led',
      'kind': 'stay',
      'location': 'Nakagyo · 2.8 km',
      'description':
          'A small machiya stay with a garden courtyard and low light.',
      'rating': 4.6,
      'distance': '12 min by taxi',
      'emoji': '🛏️',
      'accent': '#C9D8E8',
      'saved': false,
    },
  ];

  static final List<Map<String, Object?>> activities = <Map<String, Object?>>[
    <String, Object?>{
      'title': 'A new idea was saved',
      'detail': 'Shosei-en Garden · Kyoto',
      'time': 'Just now',
      'icon': 'bookmark',
      'accent': '#A7CDBE',
    },
    <String, Object?>{
      'title': 'Itinerary shared with Maya',
      'detail': 'Kyoto, slowly · 2 collaborators',
      'time': '8 min ago',
      'icon': 'group',
      'accent': '#D7C5E9',
    },
    <String, Object?>{
      'title': 'Rain is possible on Thursday',
      'detail': 'A museum day could fit beautifully',
      'time': '24 min ago',
      'icon': 'cloud',
      'accent': '#F3D4B2',
    },
  ];

  static Map<String, Object?> get home => <String, Object?>{
    'trips': trips,
    'places': places,
    'activities': activities,
  };
}
