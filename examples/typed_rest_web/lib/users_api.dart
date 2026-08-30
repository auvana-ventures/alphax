import 'package:alphax_web/alphax_web.dart';

part 'users_api.g.dart';

final class WebUser {
  const WebUser({required this.id, required this.name});

  factory WebUser.fromJson(Object? value) {
    final json = value! as Map<String, dynamic>;
    return WebUser(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;
}

@AlphaXApi(baseUrl: 'https://api.example.test')
abstract class WebUsersApi {
  factory WebUsersApi(AlphaXClient client) = _WebUsersApi;

  @AlphaXGet('/users/{id}')
  @AlphaXDecode('WebUser.fromJson')
  Future<WebUser> getUser(@AlphaXPath('id') String id);
}
