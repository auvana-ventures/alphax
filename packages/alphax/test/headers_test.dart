import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  group('AlphaXHeaders', () {
    test('normalizes names and retains repeated values', () {
      final headers = AlphaXHeaders.fromEntries(<MapEntry<String, String>>[
        const MapEntry<String, String>('X-Trace', 'one'),
        const MapEntry<String, String>('x-trace', 'two'),
      ]);

      expect(headers.contains('X-TRACE'), isTrue);
      expect(headers.values('x-trace'), <String>['one', 'two']);
      expect(headers['X-Trace'], 'one, two');
    });

    test('derived mutations do not change the original collection', () {
      const original = AlphaXHeaders.empty();
      final updated = original.add('Accept', 'application/json');

      expect(original.contains('accept'), isFalse);
      expect(updated['ACCEPT'], 'application/json');
      expect(updated.remove('accept').contains('accept'), isFalse);
    });

    test('rejects unsafe header values', () {
      expect(
        () => AlphaXHeaders(<String, String>{'X-Test': 'bad\nvalue'}),
        throwsArgumentError,
      );
    });
  });
}
