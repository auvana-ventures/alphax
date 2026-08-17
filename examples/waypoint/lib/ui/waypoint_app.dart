import 'dart:async';

import 'package:flutter/material.dart';

import '../app/waypoint_controller.dart';
import '../domain/models.dart';
import 'screens/activity_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trips_screen.dart';
import 'waypoint_theme.dart';
import 'waypoint_widgets.dart';

class WaypointApp extends StatefulWidget {
  const WaypointApp({super.key, required this.controller});

  final WaypointController controller;

  @override
  State<WaypointApp> createState() => _WaypointAppState();
}

class _WaypointAppState extends State<WaypointApp> {
  @override
  void dispose() {
    unawaited(widget.controller.close());
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Waypoint',
    debugShowCheckedModeBanner: false,
    theme: waypointTheme(),
    home: WaypointShell(controller: widget.controller),
  );
}

class WaypointShell extends StatelessWidget {
  const WaypointShell({super.key, required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final isWide = MediaQuery.sizeOf(context).width >= 940;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: <Widget>[
              if (isWide) _SideNavigation(controller: controller),
              Expanded(
                child: Column(
                  children: <Widget>[
                    if (!isWide) const _MobileHeader(),
                    if (controller.message != null)
                      _MessageBanner(message: controller.message!),
                    Expanded(child: _PageBody(controller: controller)),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: isWide
            ? null
            : _BottomNavigation(controller: controller),
      );
    },
  );
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
    child: Row(
      children: <Widget>[
        const WaypointLogo(compact: true),
        const Spacer(),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: WaypointColors.peach,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text('AR', style: Theme.of(context).textTheme.labelLarge),
        ),
      ],
    ),
  );
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) => Container(
    width: 244,
    padding: const EdgeInsets.fromLTRB(24, 28, 18, 24),
    decoration: const BoxDecoration(
      color: WaypointColors.paper,
      border: Border(right: BorderSide(color: WaypointColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const WaypointLogo(),
        const SizedBox(height: 56),
        Text(
          'Your space',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: WaypointColors.muted),
        ),
        const SizedBox(height: 12),
        _NavButton(
          icon: Icons.luggage_rounded,
          label: 'Trips',
          selected: controller.section == WaypointSection.trips,
          onTap: () => controller.selectSection(WaypointSection.trips),
        ),
        _NavButton(
          icon: Icons.travel_explore_rounded,
          label: 'Discover',
          selected: controller.section == WaypointSection.discover,
          onTap: () => controller.selectSection(WaypointSection.discover),
        ),
        _NavButton(
          icon: Icons.bolt_rounded,
          label: 'Live activity',
          selected: controller.section == WaypointSection.activity,
          onTap: () => controller.selectSection(WaypointSection.activity),
        ),
        _NavButton(
          icon: Icons.tune_rounded,
          label: 'Transport lab',
          selected: controller.section == WaypointSection.settings,
          onTap: () => controller.selectSection(WaypointSection.settings),
        ),
        const Spacer(),
        WaypointSurface(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.wb_sunny_outlined,
                color: WaypointColors.mintDeep,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Keep the plan light.',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: selected
          ? WaypointColors.mint.withValues(alpha: 0.62)
          : Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: selected ? WaypointColors.ink : WaypointColors.muted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? WaypointColors.ink : WaypointColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: controller.section.index,
    onDestinationSelected: (index) =>
        controller.selectSection(WaypointSection.values[index]),
    backgroundColor: WaypointColors.paper,
    indicatorColor: WaypointColors.mint,
    destinations: const <NavigationDestination>[
      NavigationDestination(
        icon: Icon(Icons.luggage_outlined),
        selectedIcon: Icon(Icons.luggage_rounded),
        label: 'Trips',
      ),
      NavigationDestination(
        icon: Icon(Icons.travel_explore_outlined),
        selectedIcon: Icon(Icons.travel_explore_rounded),
        label: 'Discover',
      ),
      NavigationDestination(
        icon: Icon(Icons.bolt_outlined),
        selectedIcon: Icon(Icons.bolt_rounded),
        label: 'Activity',
      ),
      NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune_rounded),
        label: 'Lab',
      ),
    ],
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: WaypointColors.mint.withValues(alpha: 0.38),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: WaypointColors.mintDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: WaypointColors.ink),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.controller});

  final WaypointController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const _LoadingPage();
    }
    final child = switch (controller.section) {
      WaypointSection.trips => TripsScreen(controller: controller),
      WaypointSection.discover => DiscoverScreen(controller: controller),
      WaypointSection.activity => ActivityScreen(controller: controller),
      WaypointSection.settings => SettingsScreen(controller: controller),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: child,
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const WaypointLogo(),
        const SizedBox(height: 28),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: 14),
        Text(
          'Gathering your places…',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
