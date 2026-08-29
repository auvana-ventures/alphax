import 'package:alphax_native/src/alpha_x_transport_factory.dart';
import 'package:test/test.dart';

void main() {
  group('alphaXTransportTargetForPlatform', () {
    test('selects Android Cronet first', () {
      expect(
        alphaXTransportTargetForPlatform(isAndroid: true, isApple: true),
        AlphaXTransportTarget.android,
      );
    });

    test('selects Apple URLSession for iOS and macOS', () {
      expect(
        alphaXTransportTargetForPlatform(isAndroid: false, isApple: true),
        AlphaXTransportTarget.apple,
      );
    });

    test('selects Dart IO for other native platforms', () {
      expect(
        alphaXTransportTargetForPlatform(isAndroid: false, isApple: false),
        AlphaXTransportTarget.dartIo,
      );
    });
  });
}
