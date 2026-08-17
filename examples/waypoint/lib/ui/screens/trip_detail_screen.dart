import 'package:flutter/material.dart';

import '../../app/waypoint_controller.dart';
import '../../domain/models.dart';
import '../waypoint_theme.dart';
import '../waypoint_widgets.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.controller});

  final WaypointController controller;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final trip = widget.controller.selectedTrip!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 52),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextButton.icon(
                onPressed: widget.controller.closeTrip,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('All trips'),
              ),
              const SizedBox(height: 18),
              _TripHeader(trip: trip),
              const SizedBox(height: 24),
              _TripTabs(
                selected: tab,
                onChanged: (value) => setState(() => tab = value),
              ),
              const SizedBox(height: 22),
              switch (tab) {
                0 => _Overview(trip: trip),
                1 => _Itinerary(trip: trip),
                _ => _Documents(controller: widget.controller, trip: trip),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});

  final WaypointTrip trip;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
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
            WaypointStatusPill(label: trip.coverLabel, color: Colors.white),
            const Spacer(),
            const Icon(Icons.more_horiz_rounded, color: WaypointColors.ink),
          ],
        ),
        const SizedBox(height: 34),
        Text(trip.title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 6),
        Text(trip.destination, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: <Widget>[
            _TripMeta(
              icon: Icons.calendar_today_rounded,
              label: trip.dateRange,
            ),
            _TripMeta(
              icon: Icons.nights_stay_outlined,
              label: trip.durationLabel,
            ),
          ],
        ),
      ],
    ),
  );
}

class _TripMeta extends StatelessWidget {
  const _TripMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 16, color: WaypointColors.muted),
      const SizedBox(width: 8),
      Text(label, style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}

class _TripTabs extends StatelessWidget {
  const _TripTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: <Widget>[
        _Tab(
          label: 'Overview',
          selected: selected == 0,
          onTap: () => onChanged(0),
        ),
        _Tab(
          label: 'Itinerary',
          selected: selected == 1,
          onTap: () => onChanged(1),
        ),
        _Tab(
          label: 'Documents',
          selected: selected == 2,
          onTap: () => onChanged(2),
        ),
      ],
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: WaypointColors.ink,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? Colors.white : WaypointColors.muted,
      ),
      backgroundColor: WaypointColors.paper,
      side: const BorderSide(color: WaypointColors.line),
      showCheckmark: false,
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.trip});

  final WaypointTrip trip;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _ItineraryPreview(trip: trip)),
          const SizedBox(width: 18),
          Expanded(child: _Checklist(trip: trip)),
        ],
      ),
    ],
  );
}

class _ItineraryPreview extends StatelessWidget {
  const _ItineraryPreview({required this.trip});

  final WaypointTrip trip;

  @override
  Widget build(BuildContext context) => WaypointSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        WaypointEyebrow('First morning'),
        const SizedBox(height: 7),
        Text('A gentle start', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 22),
        for (var index = 0; index < trip.itinerary.length; index++)
          _TimelineItem(
            item: trip.itinerary[index],
            isLast: index == trip.itinerary.length - 1,
          ),
      ],
    ),
  );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item, required this.isLast});

  final WaypointItineraryItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 52,
          child: Text(
            item.time,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: WaypointColors.muted),
          ),
        ),
        Column(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.done
                    ? WaypointColors.mintDeep
                    : WaypointColors.paper,
                shape: BoxShape.circle,
                border: Border.all(color: WaypointColors.mintDeep, width: 2),
              ),
            ),
            if (!isLast)
              Expanded(child: Container(width: 1, color: WaypointColors.line)),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.detail,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 7),
                WaypointStatusPill(
                  label: item.category,
                  color: WaypointColors.mint,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.trip});

  final WaypointTrip trip;

  @override
  Widget build(BuildContext context) => WaypointSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const WaypointEyebrow('Before you go'),
                  const SizedBox(height: 7),
                  Text(
                    'Tiny checklist',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Text(
              '${trip.completedChecklistCount}/${trip.checklist.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 21),
        for (final item in trip.checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  item.done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: item.done
                      ? WaypointColors.mintDeep
                      : WaypointColors.line,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              decoration: item.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.detail,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _Itinerary extends StatelessWidget {
  const _Itinerary({required this.trip});

  final WaypointTrip trip;

  @override
  Widget build(BuildContext context) => WaypointSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const WaypointEyebrow('Your days'),
        const SizedBox(height: 7),
        Text(
          'A plan with breathing room',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 22),
        for (final item in trip.itinerary)
          _TimelineItem(item: item, isLast: item == trip.itinerary.last),
      ],
    ),
  );
}

class _Documents extends StatelessWidget {
  const _Documents({required this.controller, required this.trip});

  final WaypointController controller;
  final WaypointTrip trip;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      WaypointSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const WaypointEyebrow('Keep it close'),
            const SizedBox(height: 7),
            Text(
              'Travel documents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            if (trip.documents.isEmpty)
              Text(
                'Nothing here yet. Add your first note or itinerary export.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final document in trip.documents)
                _DocumentRow(document: document),
          ],
        ),
      ),
      if (controller.isTransferring) ...<Widget>[
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: controller.transferProgress,
          minHeight: 7,
          borderRadius: BorderRadius.circular(7),
          backgroundColor: WaypointColors.line,
          valueColor: const AlwaysStoppedAnimation<Color>(
            WaypointColors.mintDeep,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          controller.transferProgress == null
              ? 'Moving bytes safely…'
              : 'Moving bytes safely · ${(controller.transferProgress! * 100).round()}%',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          final download = FilledButton.icon(
            onPressed: controller.isTransferring
                ? null
                : () => controller.transfer(upload: false),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download itinerary'),
          );
          final upload = OutlinedButton.icon(
            onPressed: controller.isTransferring
                ? null
                : () => controller.transfer(upload: true),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload a note'),
          );
          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[download, const SizedBox(height: 10), upload],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: download),
              const SizedBox(width: 12),
              Expanded(child: upload),
            ],
          );
        },
      ),
    ],
  );
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final WaypointDocument document;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: WaypointColors.peach,
            borderRadius: BorderRadius.all(Radius.circular(13)),
          ),
          child: Icon(
            document.icon == 'image'
                ? Icons.image_outlined
                : Icons.description_outlined,
            color: WaypointColors.ink,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                document.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                '${document.kind} · ${document.sizeLabel}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const Icon(Icons.more_horiz_rounded, color: WaypointColors.muted),
      ],
    ),
  );
}
