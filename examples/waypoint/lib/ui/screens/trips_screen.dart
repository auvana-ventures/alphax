import 'package:flutter/material.dart';

import '../../app/waypoint_controller.dart';
import '../../domain/models.dart';
import '../waypoint_theme.dart';
import '../waypoint_widgets.dart';
import 'trip_detail_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key, required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.showingTrip && controller.selectedTrip != null) {
      return TripDetailScreen(controller: controller);
    }
    final data = controller.home;
    if (data == null) {
      return const Center(child: Text('Your trips could not be loaded.'));
    }
    return _PageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 46),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Greeting(),
                    const SizedBox(height: 28),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 6,
                            child: _PrimaryTrip(
                              trip: data.trips.first,
                              controller: controller,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 4,
                            child: _PlanPulse(controller: controller),
                          ),
                        ],
                      )
                    else ...<Widget>[
                      _PrimaryTrip(
                        trip: data.trips.first,
                        controller: controller,
                      ),
                      const SizedBox(height: 18),
                      _PlanPulse(controller: controller),
                    ],
                    const SizedBox(height: 38),
                    WaypointSectionHeader(
                      eyebrow: 'Keep exploring',
                      title: 'Saved for Kyoto',
                      action: TextButton.icon(
                        onPressed: () =>
                            controller.selectSection(WaypointSection.discover),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: const Text('See all'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 270,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: data.places.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) =>
                            WaypointPlaceCard(place: data.places[index]),
                      ),
                    ),
                    const SizedBox(height: 38),
                    _ActivityPreview(controller: controller),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: WaypointColors.canvas, child: child);
}

class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      WaypointEyebrow('Sunday, 16 March 2026'),
      const SizedBox(height: 8),
      Text(
        'Make room for wonder.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Your next small adventure is taking shape.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}

class _PrimaryTrip extends StatelessWidget {
  const _PrimaryTrip({required this.trip, required this.controller});

  final WaypointTrip trip;
  final WaypointController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 388,
    child: WaypointTripCard(trip: trip, onTap: () => controller.openTrip(trip)),
  );
}

class _PlanPulse extends StatelessWidget {
  const _PlanPulse({required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) {
    final trip = controller.home!.trips.first;
    return WaypointSurface(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const WaypointEyebrow('Plan pulse'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: WaypointColors.peach,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: WaypointColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'You are in the sweet spot.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            'The big decisions are done. Leave a little space for the best kind of plan: the one you make there.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          WaypointProgressBar(value: trip.progress, height: 10),
          const SizedBox(height: 9),
          Text(
            '${(trip.progress * 100).round()}% of your Kyoto plan is ready',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              WaypointMetric(
                value:
                    '${trip.completedChecklistCount}/${trip.checklist.length}',
                label: 'ready to go',
              ),
              const Spacer(),
              WaypointMetric(
                value: '${trip.documents.length}',
                label: 'documents',
              ),
              const Spacer(),
              WaypointMetric(
                value: '${trip.itinerary.length}',
                label: 'next stops',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityPreview extends StatelessWidget {
  const _ActivityPreview({required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) => WaypointSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: WaypointSectionHeader(
                eyebrow: 'From your group',
                title: 'A little movement',
              ),
            ),
            TextButton(
              onPressed: () =>
                  controller.selectSection(WaypointSection.activity),
              child: const Text('Open live feed'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final activity in controller.activities.take(2))
          WaypointActivityTile(activity: activity),
      ],
    ),
  );
}
