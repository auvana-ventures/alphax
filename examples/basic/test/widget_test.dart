import 'package:alphax_basic_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the AlphaX example controls', (tester) async {
    await tester.pumpWidget(const AlphaXExampleApp());

    expect(find.text('AlphaX example'), findsOneWidget);
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);
    expect(find.text('Stream response'), findsOneWidget);
    expect(find.text('Download/upload file'), findsOneWidget);
    expect(find.text('Show capabilities'), findsOneWidget);
  });
}
