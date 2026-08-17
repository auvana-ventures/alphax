import 'dart:async';

import 'package:flutter/material.dart';

import 'app/waypoint_bootstrap.dart';
import 'app/waypoint_controller.dart';
import 'data/waypoint_data_source.dart';
import 'data/waypoint_repository.dart';
import 'ui/waypoint_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  late final WaypointDataSource source;
  String? startupMessage;
  try {
    source = await createWaypointDataSource();
  } catch (error) {
    source = DemoWaypointDataSource();
    startupMessage =
        'Network setup was unavailable, so Waypoint opened in safe demo mode.';
  }

  final controller = WaypointController(
    WaypointRepository(source),
    startupMessage: startupMessage,
  );
  runApp(WaypointApp(controller: controller));
  unawaited(controller.initialize());
}
