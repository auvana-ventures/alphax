import 'package:alphax/alphax.dart';
import 'package:alphax/annotations.dart';

part 'users_api.g.dart';

final class User {
  const User({required this.id, required this.name});

  factory User.fromJson(Object? value) {
    final json = value! as Map<String, dynamic>;
    return User(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;
}

@AlphaXApi(baseUrl: 'https://api.example.test')
abstract class UsersApi {
  factory UsersApi(AlphaXClient client) = _UsersApi;

  @AlphaXGet('/users/{id}')
  @AlphaXDecode('User.fromJson')
  Future<User> getUser(@AlphaXPath('id') String id);
}
