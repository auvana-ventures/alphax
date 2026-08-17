import 'package:flutter/material.dart';

import '../../app/waypoint_controller.dart';
import '../../domain/models.dart';
import '../waypoint_theme.dart';
import '../waypoint_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.controller});

  final WaypointController controller;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final TextEditingController searchController;
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final places = widget.controller.visiblePlaces
          .where(_matchesFilter)
          .toList(growable: false);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 52),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                WaypointSectionHeader(
                  eyebrow: 'The good kind of lost',
                  title: 'Find your next yes.',
                  action: WaypointStatusPill(
                    label: widget.controller.isSearching
                        ? 'Searching…'
                        : '${places.length} ideas',
                    color: WaypointColors.peach,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  'Places with a point of view, saved for your pace.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: searchController,
                  onChanged: widget.controller.search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search coffee, gardens, quiet corners…',
                    prefixIcon: Icon(Icons.search_rounded),
                    suffixIcon: Icon(Icons.tune_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final value in <String>[
                        'All',
                        'Food',
                        'Nature',
                        'Culture',
                        'Stay',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(value),
                            selected: filter == value,
                            onSelected: (_) => setState(() => filter = value),
                            selectedColor: WaypointColors.ink,
                            labelStyle: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: filter == value
                                      ? Colors.white
                                      : WaypointColors.muted,
                                ),
                            backgroundColor: WaypointColors.paper,
                            side: const BorderSide(color: WaypointColors.line),
                            showCheckmark: false,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (places.isEmpty)
                  WaypointSurface(
                    child: Column(
                      children: <Widget>[
                        const Icon(
                          Icons.map_outlined,
                          size: 34,
                          color: WaypointColors.muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No place matches that yet.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Try a broader search and keep the door open.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900
                          ? 4
                          : constraints.maxWidth >= 600
                          ? 3
                          : 2;
                      final width =
                          (constraints.maxWidth - ((columns - 1) * 14)) /
                          columns;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: <Widget>[
                          for (final place in places)
                            SizedBox(
                              width: width,
                              child: WaypointPlaceCard(
                                place: place,
                                width: width,
                                onTap: () => _showPlace(context, place),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  bool _matchesFilter(WaypointPlace place) => switch (filter) {
    'Food' => place.kind == WaypointPlaceKind.food,
    'Nature' => place.kind == WaypointPlaceKind.nature,
    'Culture' => place.kind == WaypointPlaceKind.culture,
    'Stay' => place.kind == WaypointPlaceKind.stay,
    _ => true,
  };

  Future<void> _showPlace(BuildContext context, WaypointPlace place) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: WaypointColors.paper,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: waypointColor(place.accent),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(17),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        place.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            place.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            place.location,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.bookmark_border_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  place.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    WaypointStatusPill(
                      label: '${place.rating} rating',
                      color: WaypointColors.peach,
                    ),
                    const SizedBox(width: 8),
                    WaypointStatusPill(
                      label: place.distance,
                      color: WaypointColors.mint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
