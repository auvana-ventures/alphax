import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  test('cancellation completes its notification future once', () async {
    final token = AlphaXCancellationToken();
    var notifications = 0;
    final notification = token.whenCancelled.then((_) => notifications++);

    token.cancel('network was interrupted');
    token.cancel('ignored');
    await notification;

    expect(token.isCancelled, isTrue);
    expect(token.reason, 'network was interrupted');
    expect(notifications, 1);
    expect(() => token.throwIfCancelled(), throwsA(isA<AlphaXCancelledException>()));
  });
}
