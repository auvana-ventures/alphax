import 'package:alphax/alphax.dart';

enum WaypointSection { trips, discover, activity, settings }

enum WaypointPlaceKind { stay, food, culture, nature }

final class WaypointTrip {
  const WaypointTrip({
    required this.id,
    required this.title,
    required this.destination,
    required this.dateRange,
    required this.durationLabel,
    required this.coverLabel,
    required this.accent,
    required this.progress,
    required this.itinerary,
    required this.checklist,
    required this.documents,
  });

  final String id;
  final String title;
  final String destination;
  final String dateRange;
  final String durationLabel;
  final String coverLabel;
  final String accent;
  final double progress;
  final List<WaypointItineraryItem> itinerary;
  final List<WaypointChecklistItem> checklist;
  final List<WaypointDocument> documents;

  int get completedChecklistCount =>
      checklist.where((item) => item.done).length;

  WaypointTrip copyWith({List<WaypointDocument>? documents}) => WaypointTrip(
    id: id,
    title: title,
    destination: destination,
    dateRange: dateRange,
    durationLabel: durationLabel,
    coverLabel: coverLabel,
    accent: accent,
    progress: progress,
    itinerary: itinerary,
    checklist: checklist,
    documents: documents ?? this.documents,
  );
}

final class WaypointPlace {
  const WaypointPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.kind,
    required this.location,
    required this.description,
    required this.rating,
    required this.distance,
    required this.emoji,
    required this.accent,
    this.saved = false,
  });

  final String id;
  final String name;
  final String category;
  final WaypointPlaceKind kind;
  final String location;
  final String description;
  final double rating;
  final String distance;
  final String emoji;
  final String accent;
  final bool saved;
}

final class WaypointItineraryItem {
  const WaypointItineraryItem({
    required this.time,
    required this.title,
    required this.detail,
    required this.category,
    this.done = false,
  });

  final String time;
  final String title;
  final String detail;
  final String category;
  final bool done;
}

final class WaypointChecklistItem {
  const WaypointChecklistItem({
    required this.title,
    required this.detail,
    this.done = false,
  });

  final String title;
  final String detail;
  final bool done;
}

final class WaypointDocument {
  const WaypointDocument({
    required this.name,
    required this.kind,
    required this.sizeLabel,
    required this.icon,
  });

  final String name;
  final String kind;
  final String sizeLabel;
  final String icon;
}

final class WaypointActivity {
  const WaypointActivity({
    required this.title,
    required this.detail,
    required this.time,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String detail;
  final String time;
  final String icon;
  final String accent;
}

final class WaypointHomeData {
  const WaypointHomeData({
    required this.trips,
    required this.places,
    required this.activities,
  });

  final List<WaypointTrip> trips;
  final List<WaypointPlace> places;
  final List<WaypointActivity> activities;
}

final class WaypointTransferSummary {
  const WaypointTransferSummary({
    required this.operation,
    required this.bytes,
    required this.protocol,
  });

  final String operation;
  final int bytes;
  final AlphaXProtocol protocol;
}

final class WaypointProtocolProbe {
  const WaypointProtocolProbe({
    required this.protocol,
    required this.preference,
    required this.fallback,
    required this.metrics,
  });

  final AlphaXProtocol protocol;
  final AlphaXProtocolPreference preference;
  final AlphaXProtocolFallback? fallback;
  final AlphaXRequestMetrics metrics;
}
