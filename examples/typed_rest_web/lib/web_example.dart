import 'package:alphax_web/alphax_web.dart';

import 'users_api.dart';

/// Shows browser setup, one generated request, and explicit client ownership.
Future<void> runWebUsersApiExample() async {
  final alpha = createAlphaXClient();
  try {
    final users = WebUsersApi(alpha);
    await users.getUser('42');
  } finally {
    await alpha.close();
  }
}

void main() {
  // The compile fixture does not contact a remote server.
}
