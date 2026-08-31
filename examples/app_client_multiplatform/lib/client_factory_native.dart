import 'package:alphax_native/alphax_native.dart';

/// Selects the native facade behind the app-local conditional export.
Future<AlphaXAppClient> createPlatformClient({required String baseUrl}) =>
    createAlphaXAppClient(baseUrl: baseUrl);
