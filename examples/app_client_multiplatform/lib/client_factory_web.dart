import 'package:alphax_web/alphax_web.dart';

/// Selects the browser facade behind the app-local conditional export.
Future<AlphaXAppClient> createPlatformClient({required String baseUrl}) =>
    createAlphaXAppClient(baseUrl: baseUrl);
