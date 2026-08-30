// Generated from OpenAPI by the AlphaX bounded template proof.
// The template emits declarations; alphax_generator emits the implementation.

import 'package:alphax/alphax.dart';
import 'package:alphax/annotations.dart';
import 'package:alphax_openapi_template_proof/fixture_models.dart';

part 'users_api.g.dart';

@AlphaXApi(baseUrl: 'http://127.0.0.1:45874/')
abstract class UsersApi {
  factory UsersApi(AlphaXClient client) = _UsersApi;

  @AlphaXPost('/users')
  @AlphaXDecode('User.fromJson')
  Future<User?> createUser(@AlphaXBodyParam() CreateUser createUser);

  @AlphaXGet('/users/{id}')
  @AlphaXDecode('User.fromJson')
  Future<User?> getUser(
    @AlphaXPath('id') String id,
    @AlphaXHeader('X-Request-ID') String xRequestID,
    @AlphaXQuery('verbose') bool? verbose,
  );
}
