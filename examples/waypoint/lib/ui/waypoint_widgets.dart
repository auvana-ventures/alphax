import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'waypoint_theme.dart';

class WaypointLogo extends StatelessWidget {
  const WaypointLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: compact ? 34 : 40,
        height: compact ? 34 : 40,
        decoration: const BoxDecoration(
          color: WaypointColors.ink,
          borderRadius: BorderRadius.all(Radius.circular(13)),
        ),
        child: const Icon(
          Icons.explore_rounded,
          color: WaypointColors.mint,
          size: 22,
        ),
      ),
      if (!compact) ...<Widget>[
        const SizedBox(width: 10),
        Text(
          'waypoint',
          style: TextStyle(
            color: WaypointColors.ink,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ],
  );
}

class WaypointEyebrow extends StatelessWidget {
  const WaypointEyebrow(
    this.text, {
    super.key,
    this.color = WaypointColors.mintDeep,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
  );
}

class WaypointSectionHeader extends StatelessWidget {
  const WaypointSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.action,
  });

  final String eyebrow;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            WaypointEyebrow(eyebrow),
            const SizedBox(height: 7),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
      ?action,
    ],
  );
}

class WaypointSurface extends StatelessWidget {
  const WaypointSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: WaypointColors.paper,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      border: Border.all(color: WaypointColors.line),
    ),
    child: child,
  );
}

class WaypointStatusPill extends StatelessWidget {
  const WaypointStatusPill({
    super.key,
    required this.label,
    this.color = WaypointColors.mint,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.48),
      borderRadius: const BorderRadius.all(Radius.circular(100)),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: WaypointColors.ink),
    ),
  );
}

class WaypointMetric extends StatelessWidget {
  const WaypointMetric({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 2),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class WaypointProgressBar extends StatelessWidget {
  const WaypointProgressBar({super.key, required this.value, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      minHeight: height,
      value: value,
      backgroundColor: WaypointColors.ink.withValues(alpha: 0.12),
      valueColor: const AlwaysStoppedAnimation<Color>(WaypointColors.ink),
    ),
  );
}

class WaypointTripCard extends StatelessWidget {
  const WaypointTripCard({super.key, required this.trip, required this.onTap});

  final WaypointTrip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open ${trip.title}',
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: Ink(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[waypointColor(trip.accent), WaypointColors.paper],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          border: Border.all(color: WaypointColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: WaypointStatusPill(
                    label: trip.coverLabel,
                    color: Colors.white,
                  ),
                ),
                const Icon(
                  Icons.arrow_outward_rounded,
                  color: WaypointColors.ink,
                ),
              ],
            ),
            const Spacer(),
            Text(trip.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              trip.destination,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: WaypointProgressBar(value: trip.progress, height: 7),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(trip.progress * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: WaypointColors.muted,
                ),
                const SizedBox(width: 7),
                Text(
                  trip.dateRange,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  trip.durationLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class WaypointPlaceCard extends StatelessWidget {
  const WaypointPlaceCard({
    super.key,
    required this.place,
    this.onTap,
    this.width = 220,
  });

  final WaypointPlace place;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: const BorderRadius.all(Radius.circular(22)),
    child: Ink(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WaypointColors.paper,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: WaypointColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: waypointColor(place.accent),
              borderRadius: const BorderRadius.all(Radius.circular(17)),
            ),
            alignment: Alignment.center,
            child: Text(place.emoji, style: const TextStyle(fontSize: 42)),
          ),
          const SizedBox(height: 14),
          Text(place.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            place.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFE09A3E),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                place.rating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  place.distance,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class WaypointActivityTile extends StatelessWidget {
  const WaypointActivityTile({super.key, required this.activity});

  final WaypointActivity activity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: waypointColor(activity.accent),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Icon(
            _iconFor(activity.icon),
            color: WaypointColors.ink,
            size: 19,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                activity.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                activity.detail,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          activity.time,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: WaypointColors.muted),
        ),
      ],
    ),
  );

  IconData _iconFor(String icon) => switch (icon) {
    'bookmark' => Icons.bookmark_rounded,
    'group' => Icons.group_rounded,
    'cloud' => Icons.cloud_queue_rounded,
    _ => Icons.auto_awesome_rounded,
  };
}
