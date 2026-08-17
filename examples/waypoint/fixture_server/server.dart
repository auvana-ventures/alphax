import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:waypoint/data/demo_waypoint_transport.dart';

Future<void> main(List<String> arguments) async {
  final host = _option(arguments, '--host') ?? '127.0.0.1';
  final port = int.tryParse(_option(arguments, '--port') ?? '8080') ?? 8080;
  final server = await HttpServer.bind(host, port);
  stdout.writeln('Waypoint fixture server listening at http://$host:$port/');
  stdout.writeln('Press Ctrl-C to stop.');

  await for (final request in server) {
    unawaited(_handle(request));
  }
}

Future<void> _handle(HttpRequest request) async {
  try {
    final path = request.uri.path;
    if (path == '/api/home') {
      await _json(request.response, WaypointFixturePayloads.home);
    } else if (path == '/api/search') {
      final query = (request.uri.queryParameters['q'] ?? '')
          .trim()
          .toLowerCase();
      final places = WaypointFixturePayloads.places.where((place) {
        if (query.isEmpty) {
          return true;
        }
        final haystack =
            '${place['name']} ${place['category']} ${place['location']}'
                .toLowerCase();
        return haystack.contains(query);
      });
      await _json(request.response, <String, Object?>{
        'places': places.toList(growable: false),
      });
    } else if (path.startsWith('/api/trips/') && path.endsWith('/itinerary')) {
      final bytes = utf8.encode(
        'WAYPOINT ITINERARY\nKyoto field notes\nLocal fixture export.',
      );
      request.response.headers.contentType = ContentType('application', 'pdf');
      request.response.headers.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    } else if (path.startsWith('/api/trips/')) {
      final id = path.split('/').last;
      final trip = WaypointFixturePayloads.trips.firstWhere(
        (candidate) => candidate['id'] == id,
        orElse: () => WaypointFixturePayloads.trips.first,
      );
      await _json(request.response, trip);
    } else if (path == '/api/activity') {
      await _streamActivity(request.response);
    } else if (path == '/api/documents' && request.method == 'POST') {
      await request.drain<void>();
      await _json(request.response, <String, Object?>{'uploaded': true});
    } else if (path == '/api/probe') {
      await _json(request.response, <String, Object?>{'ok': true});
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await _json(request.response, <String, Object?>{
        'error': 'Route not found',
      });
    }
  } catch (error) {
    request.response.statusCode = HttpStatus.internalServerError;
    await _json(request.response, <String, Object?>{'error': '$error'});
  }
}

Future<void> _streamActivity(HttpResponse response) async {
  response.headers.contentType = ContentType.json;
  response.headers.chunkedTransferEncoding = true;
  for (final activity in WaypointFixturePayloads.activities) {
    response.write('${jsonEncode(activity)}\n');
    await response.flush();
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }
  await response.close();
}

Future<void> _json(HttpResponse response, Object value) async {
  response.headers.contentType = ContentType.json;
  final bytes = utf8.encode(jsonEncode(value));
  response.headers.contentLength = bytes.length;
  response.add(bytes);
  await response.close();
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) {
    return null;
  }
  return arguments[index + 1];
}
