import 'package:alphax/alphax.dart';

import '../domain/models.dart';

final class WaypointDataException implements Exception {
  const WaypointDataException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}

final class WaypointJson {
  const WaypointJson._();

  static WaypointHomeData decodeHome(Object? value) {
    final map = _asMap(value);
    return WaypointHomeData(
      trips: _asList(map['trips']).map(decodeTrip).toList(growable: false),
      places: _asList(map['places']).map(decodePlace).toList(growable: false),
      activities: _asList(
        map['activities'],
      ).map(decodeActivity).toList(growable: false),
    );
  }

  static List<WaypointPlace> decodePlaces(Object? value) {
    final map = _asMap(value);
    return _asList(map['places']).map(decodePlace).toList(growable: false);
  }

  static WaypointTrip decodeTrip(Object? value) {
    final map = _asMap(value);
    return WaypointTrip(
      id: _string(map['id']),
      title: _string(map['title']),
      destination: _string(map['destination']),
      dateRange: _string(map['dateRange']),
      durationLabel: _string(map['durationLabel']),
      coverLabel: _string(map['coverLabel']),
      accent: _string(map['accent']),
      progress: _number(map['progress']),
      itinerary: _asList(
        map['itinerary'],
      ).map(decodeItinerary).toList(growable: false),
      checklist: _asList(
        map['checklist'],
      ).map(decodeChecklist).toList(growable: false),
      documents: _asList(
        map['documents'],
      ).map(decodeDocument).toList(growable: false),
    );
  }

  static WaypointPlace decodePlace(Object? value) {
    final map = _asMap(value);
    return WaypointPlace(
      id: _string(map['id']),
      name: _string(map['name']),
      category: _string(map['category']),
      kind: WaypointPlaceKind.values.byName(_string(map['kind'])),
      location: _string(map['location']),
      description: _string(map['description']),
      rating: _number(map['rating']),
      distance: _string(map['distance']),
      emoji: _string(map['emoji']),
      accent: _string(map['accent']),
      saved: map['saved'] == true,
    );
  }

  static WaypointItineraryItem decodeItinerary(Object? value) {
    final map = _asMap(value);
    return WaypointItineraryItem(
      time: _string(map['time']),
      title: _string(map['title']),
      detail: _string(map['detail']),
      category: _string(map['category']),
      done: map['done'] == true,
    );
  }

  static WaypointChecklistItem decodeChecklist(Object? value) {
    final map = _asMap(value);
    return WaypointChecklistItem(
      title: _string(map['title']),
      detail: _string(map['detail']),
      done: map['done'] == true,
    );
  }

  static WaypointDocument decodeDocument(Object? value) {
    final map = _asMap(value);
    return WaypointDocument(
      name: _string(map['name']),
      kind: _string(map['kind']),
      sizeLabel: _string(map['sizeLabel']),
      icon: _string(map['icon']),
    );
  }

  static WaypointActivity decodeActivity(Object? value) {
    final map = _asMap(value);
    return WaypointActivity(
      title: _string(map['title']),
      detail: _string(map['detail']),
      time: _string(map['time']),
      icon: _string(map['icon']),
      accent: _string(map['accent']),
    );
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Waypoint response was not an object');
  }

  static List<Object?> _asList(Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return List<Object?>.from(value);
    }
    throw const FormatException('Waypoint response field was not a list');
  }

  static String _string(Object? value) => value is String ? value : '$value';

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.parse('$value');

  static String protocolLabel(AlphaXProtocol protocol) => switch (protocol) {
    AlphaXProtocol.unknown => 'Unknown',
    AlphaXProtocol.http10 => 'H1.0',
    AlphaXProtocol.http11 => 'H1.1',
    AlphaXProtocol.http2 => 'H2',
    AlphaXProtocol.http3 => 'H3',
  };
}
