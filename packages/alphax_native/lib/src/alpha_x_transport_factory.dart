import 'dart:io';

import 'package:alphax/alphax.dart';

import 'android_cronet_transport.dart';
import 'apple_url_session_transport.dart';
import 'dart_io_transport.dart';

/// Selects the AlphaX native transport for the current Dart VM platform.
///
/// Android uses the provider-selected Cronet/HttpEngine adapter, iOS and
/// macOS use URLSession, and other native Dart VM platforms use the Dart IO
/// fallback. Web applications should use `WebFetchTransport` from the
/// separate `alphax_web` package instead; this package is not a browser
/// transport.
///
/// The returned transport is initialized before the future completes. Pass
/// the same transport to one long-lived [AlphaXClient] and close that client
/// when its owning scope ends. The default TLS and proxy policies are secure
/// platform trust and the system proxy policy.
Future<AlphaXTransport> createAlphaXTransport({
  AlphaXTlsPolicy tlsPolicy = const AlphaXTlsPolicy.platformDefault(),
  AlphaXProxyPolicy proxyPolicy = const AlphaXProxyPolicy.system(),
}) async {
  switch (alphaXTransportTargetForPlatform(
    isAndroid: Platform.isAndroid,
    isApple: Platform.isIOS || Platform.isMacOS,
  )) {
    case AlphaXTransportTarget.android:
      return AndroidCronetTransport.create(
        tlsPolicy: tlsPolicy,
        proxyPolicy: proxyPolicy,
      );
    case AlphaXTransportTarget.apple:
      return AppleUrlSessionTransport.create(
        tlsPolicy: tlsPolicy,
        proxyPolicy: proxyPolicy,
      );
    case AlphaXTransportTarget.dartIo:
      return DartIoTransport(
        tlsPolicy: tlsPolicy,
        proxyPolicy: proxyPolicy,
      );
  }
}

/// Internal platform-selection values used to test the automatic mapping.
///
/// This enum is intentionally not exported from `alphax_native.dart`; callers
/// should use [createAlphaXTransport] or construct a concrete adapter when
/// they need explicit control.
enum AlphaXTransportTarget { android, apple, dartIo }

/// Returns the target selected by the automatic native transport policy.
///
/// This helper is kept in `src/` so the platform mapping can be tested without
/// initializing a Flutter plugin. It is not part of the package's supported
/// public API.
AlphaXTransportTarget alphaXTransportTargetForPlatform({
  required bool isAndroid,
  required bool isApple,
}) {
  if (isAndroid) return AlphaXTransportTarget.android;
  if (isApple) return AlphaXTransportTarget.apple;
  return AlphaXTransportTarget.dartIo;
}
