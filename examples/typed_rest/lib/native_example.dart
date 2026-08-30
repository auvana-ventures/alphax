import 'package:alphax_native/alphax_native.dart';

import 'users_api.dart';

/// Shows native setup, one generated request, and explicit client ownership.
Future<void> runNativeUsersApiExample() async {
  final alpha = await createAlphaXClient();
  try {
    final users = UsersApi(alpha);
    await users.getUser('42', null, 'example-token');
  } finally {
    await alpha.close();
  }
}
