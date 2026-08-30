import 'package:alphax_native/alphax_native.dart';

import 'users_api.dart';

/// Shows the generated-client hand-off and lifecycle at the deployment boundary.
Future<void> runGeneratedNativeExample() async {
  final client = await createAlphaXClient();
  try {
    await UsersApi(client).getUser('42', 'example-request', true);
  } finally {
    await client.close();
  }
}
