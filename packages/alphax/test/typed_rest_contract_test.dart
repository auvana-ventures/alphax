import 'package:alphax/alphax.dart';
import 'package:test/test.dart';

void main() {
  test('AlphaXRequestOptions bundles existing request policies', () {
    final token = AlphaXCancellationToken();
    final options = AlphaXRequestOptions(
      timeouts: const AlphaXTimeouts(read: Duration(seconds: 3)),
      cancellationToken: token,
      protocolPreference: AlphaXProtocolPreference.http2,
      protocolRequirement: AlphaXProtocolRequirement.http2,
      redirectPolicy: const AlphaXRedirectPolicy(mode: AlphaXRedirectMode.manual),
      priority: AlphaXPriority.high,
    );

    expect(options.timeouts.read, const Duration(seconds: 3));
    expect(options.cancellationToken, same(token));
    expect(options.protocolPreference, AlphaXProtocolPreference.http2);
    expect(options.protocolRequirement, AlphaXProtocolRequirement.http2);
    expect(options.redirectPolicy.mode, AlphaXRedirectMode.manual);
    expect(options.priority, AlphaXPriority.high);
  });

  test('typed response keeps metadata and distinguishes an empty body', () async {
    final response = AlphaXResponse(statusCode: 204);
    final typed = AlphaXApiResponse<String?>(data: null, response: response);

    expect(await response.readAsBytesOrNull(), isNull);
    expect(await response.readAsStringOrNull(), isNull);
    expect(await response.readAsJsonOrNull(), isNull);
    expect(typed.statusCode, 204);
    expect(typed.headers, same(response.headers));
    expect(typed.protocol, response.protocol);
  });
}
