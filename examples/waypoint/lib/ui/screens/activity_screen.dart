import 'package:flutter/material.dart';

import '../../app/waypoint_controller.dart';
import '../waypoint_theme.dart';
import '../waypoint_widgets.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 52),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            WaypointSectionHeader(
              eyebrow: 'A living plan',
              title: 'Activity, as it happens.',
              action: FilledButton.icon(
                onPressed: controller.toggleLiveActivity,
                icon: Icon(
                  controller.isLive
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  controller.isLive ? 'Stop feed' : 'Start live feed',
                ),
              ),
            ),
            const SizedBox(height: 11),
            Text(
              'Watch a bounded response stream become useful UI, one update at a time.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 26),
            WaypointSurface(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: WaypointColors.lavender,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 28,
                      color: WaypointColors.ink,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          controller.isLive
                              ? 'Listening for changes'
                              : 'The group is in sync',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Streaming can be paused or cancelled without leaving an orphaned request.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (controller.isLive)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            WaypointSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const WaypointEyebrow('Latest updates'),
                      const Spacer(),
                      WaypointStatusPill(
                        label: '${controller.activities.length} notes',
                        color: WaypointColors.peach,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Column(
                      key: ValueKey<int>(controller.activities.length),
                      children: <Widget>[
                        for (final activity in controller.activities)
                          WaypointActivityTile(activity: activity),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
