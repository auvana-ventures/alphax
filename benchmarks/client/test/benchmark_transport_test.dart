import 'package:alphax_benchmark_client/alphax_benchmark_client.dart';
import 'package:test/test.dart';

void main() {
  test('freezes headers case-insensitively and retains repeated values', () {
    final response = BenchmarkResponse(
      statusCode: 200,
      headers: <String, Iterable<String>>{
        'X-Trace': <String>['one'],
        'x-trace': <String>['two'],
      },
      bodyBytes: <int>[1, 2],
      elapsed: Duration.zero,
    );

    expect(response.headerValues('X-TRACE'), <String>['one', 'two']);
    expect(response.header('x-trace'), 'one');
    expect(() => response.headers['x-trace']!.add('three'), throwsUnsupportedError);
  });

  test('cancellation is idempotent and observable', () async {
    final token = BenchmarkCancellationToken();
    var notifications = 0;
    final notification = token.whenCancelled.then((_) => notifications++);

    token.cancel();
    token.cancel();
    await notification;

    expect(token.isCancelled, isTrue);
    expect(notifications, 1);
  });
}
