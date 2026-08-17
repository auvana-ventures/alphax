import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/app/waypoint_controller.dart';
import 'package:waypoint/data/waypoint_data_source.dart';
import 'package:waypoint/data/waypoint_repository.dart';
import 'package:waypoint/ui/waypoint_app.dart';

void main() {
  testWidgets('moves from trips to discovery and into a trip workspace', (
    tester,
  ) async {
    final source = DemoWaypointDataSource();
    final controller = WaypointController(WaypointRepository(source));
    final initialize = controller.initialize();
    await tester.pump(const Duration(milliseconds: 250));
    await initialize;

    await tester.pumpWidget(WaypointApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Make room for wonder.'), findsOneWidget);
    await tester.tap(find.text('Discover').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Find your next yes.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'garden');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Shosei-en Garden'), findsOneWidget);

    await tester.tap(find.text('Trips').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Kyoto, slowly').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('A gentle start'), findsOneWidget);
    expect(find.text('Tiny checklist'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await controller.close();
  });
}
