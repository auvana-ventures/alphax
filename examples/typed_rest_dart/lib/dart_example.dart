import 'package:alphax/alphax.dart';

import 'users_api.dart';

/// Shows the pure-Dart custom-transport hand-off to a generated service.
UsersApi createDartUsersApi(AlphaXClient client) => UsersApi(client);

void main() {
  // Pure-Dart applications provide their own AlphaXTransport.
}
