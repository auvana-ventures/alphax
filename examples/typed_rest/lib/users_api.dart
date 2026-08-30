import 'package:alphax_native/alphax_native.dart';

import 'model_compatibility.dart';

part 'users_api.g.dart';

JsonSerializableUser decodeJsonSerializableUser(Object? value) =>
    JsonSerializableUser.fromJson(
      (value! as Map<Object?, Object?>).cast<String, Object?>(),
    );

FreezedUser decodeFreezedUser(Object? value) => FreezedUser.fromJson(
  (value! as Map<Object?, Object?>).cast<String, Object?>(),
);

/// Small caller-owned model used by the generator fixture.
final class User {
  const User({required this.id, required this.name});

  factory User.fromJson(Object? value) {
    final json = value! as Map<String, dynamic>;
    return User(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};
}

final class CreateUser {
  const CreateUser(this.name);

  final String name;

  Map<String, Object?> toJson() => <String, Object?>{'name': name};
}

@AlphaXApi(
  baseUrl: 'https://api.example.test/v1?tenant=alpha',
  headers: <String, String>{
    'x-client': 'typed-example',
    'X-Override': 'api',
  },
)
abstract class UsersApi {
  factory UsersApi(AlphaXClient client) = _UsersApi;

  @AlphaXGet(
    '/users/{id}',
    headers: <String, String>{'accept': 'application/json'},
  )
  @AlphaXDecode('User.fromJson')
  Future<User> getUser(
    @AlphaXPath('id') String id,
    @AlphaXQuery('page') int? page,
    @AlphaXHeader('Authorization') String token, {
    @AlphaXOptions() AlphaXRequestOptions? options,
  });

  @AlphaXPost('/users')
  @AlphaXDecode('User.fromJson')
  Future<User> createUser(@AlphaXBodyParam() CreateUser input);

  @AlphaXGet('/users')
  @AlphaXDecode('User.fromJson')
  Future<List<User>> listUsers();

  @AlphaXGet(
    '/header-precedence',
    headers: <String, String>{'x-override': 'method'},
  )
  Future<AlphaXResponse> headerPrecedence();

  @AlphaXPost('/text')
  Future<AlphaXResponse> sendText(
    @AlphaXBodyParam(
      encoding: AlphaXBodyEncoding.text,
      contentType: 'text/custom',
    )
    String body,
  );

  @AlphaXPost('/bytes')
  Future<AlphaXResponse> sendBytes(
    @AlphaXBodyParam(encoding: AlphaXBodyEncoding.bytes) List<int> body,
  );

  @AlphaXPost('/stream')
  Future<AlphaXResponse> sendStream(
    @AlphaXBodyParam(encoding: AlphaXBodyEncoding.stream)
    Stream<List<int>> body,
  );

  @AlphaXPost('/file-body')
  Future<AlphaXResponse> sendFileBody(
    @AlphaXBodyParam(encoding: AlphaXBodyEncoding.file) AlphaXFileSource source,
  );

  @AlphaXGet('/cancel')
  Future<AlphaXResponse> cancellable(
    @AlphaXCancellation() AlphaXCancellationToken? token,
  );

  @AlphaXGet('/search')
  Future<AlphaXResponse> search(@AlphaXQuery('tag') List<String> tags);

  @AlphaXGet('/json-serializable')
  @AlphaXDecode('decodeJsonSerializableUser')
  Future<JsonSerializableUser> getJsonSerializable();

  @AlphaXGet('/freezed')
  @AlphaXDecode('decodeFreezedUser')
  Future<FreezedUser> getFreezed();

  @AlphaXPut('/users/{id}')
  @AlphaXDecode('User.fromJson')
  Future<AlphaXApiResponse<User>> replaceUser(
    @AlphaXPath('id') String id,
    @AlphaXBodyParam() CreateUser input,
  );

  @AlphaXPatch('/users/{id}')
  @AlphaXDecode('User.fromJson')
  Future<User> patchUser(
    @AlphaXPath('id') String id,
    @AlphaXBodyParam() CreateUser input,
  );

  @AlphaXDelete('/users/{id}')
  Future<void> deleteUser(@AlphaXPath('id') String id);

  @AlphaXGet('/download')
  Future<AlphaXTransferResult> download(
    @AlphaXFileTargetParam() AlphaXFileTarget target,
  );

  @AlphaXPost('/upload')
  Future<AlphaXTransferResult> upload(
    @AlphaXFileSourceParam() AlphaXFileSource source,
  );

  @AlphaXGet('/raw')
  Future<AlphaXResponse> raw();

  @AlphaXHead('/health')
  Future<AlphaXResponse> head();

  @AlphaXGet('/stream')
  Stream<List<int>> stream();

  @AlphaXPost('/multipart')
  Future<AlphaXResponse> multipart(
    @AlphaXBodyParam(encoding: AlphaXBodyEncoding.multipart)
    AlphaXMultipartBody body,
  );
}
