import 'package:alphax/alphax.dart';
import 'package:alphax/annotations.dart';
import 'package:source_gen_test/annotations.dart';

@ShouldThrow(
  'AlphaX API method `MissingPathBindingApi.getUser` has no parameter for path placeholder {id}.',
  todo: 'Add exactly one @AlphaXPath("id") parameter.',
)
@AlphaXApi(baseUrl: 'https://api.example.test')
abstract class MissingPathBindingApi {
  factory MissingPathBindingApi(AlphaXClient client) => throw UnimplementedError();

  @AlphaXGet('/users/{id}')
  Future<String> getUser(@AlphaXQuery('page') int page);
}

@ShouldThrow(
  'AlphaX API method `DuplicateBodyApi.create` declares more than one body parameter.',
  todo: 'Keep at most one body binding.',
)
@AlphaXApi(baseUrl: 'https://api.example.test')
abstract class DuplicateBodyApi {
  factory DuplicateBodyApi(AlphaXClient client) => throw UnimplementedError();

  @AlphaXPost('/users')
  Future<String> create(
    @AlphaXBodyParam() Map<String, Object?> first,
    @AlphaXBodyParam() Map<String, Object?> second,
  );
}

final class UndecodableUser {
  const UndecodableUser();
}

@ShouldThrow(
  'AlphaX API method `MissingDecoderApi.getUsers` returns `UndecodableUser` without a decoder.',
  todo: 'Add @AlphaXDecode("Type.fromJson") or use a directly supported JSON type.',
)
@AlphaXApi(baseUrl: 'https://api.example.test')
abstract class MissingDecoderApi {
  factory MissingDecoderApi(AlphaXClient client) => throw UnimplementedError();

  @AlphaXGet('/users')
  Future<UndecodableUser> getUsers();
}

@ShouldGenerate(
  'class _ValidSurfaceApi implements ValidSurfaceApi',
  contains: true,
)
@AlphaXApi(baseUrl: 'https://api.example.test')
abstract class ValidSurfaceApi {
  factory ValidSurfaceApi(AlphaXClient client) => throw UnimplementedError();

  @AlphaXPost('/users/{id}')
  Future<String> update(
    @AlphaXPath('id') String id,
    @AlphaXQuery('page') int? page,
    @AlphaXHeader('X-Request-Id') String requestId,
    @AlphaXBodyParam() Map<String, Object?> body,
  );
}
