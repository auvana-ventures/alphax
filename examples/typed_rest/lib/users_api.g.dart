// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_api.dart';

// **************************************************************************
// AlphaXApiGenerator
// **************************************************************************

class _UsersApi implements UsersApi {
  _UsersApi(this._client);

  final AlphaXClient _client;

  Uri _resolveUri(
    String endpoint,
    Map<String, Iterable<String>> queryParameters,
  ) {
    final base = Uri.parse("https://api.example.test/v1?tenant=alpha");
    final parsed = Uri.parse(endpoint);
    final resolved = parsed.isAbsolute ? parsed : base.resolveUri(parsed);
    final merged = <String, Iterable<String>>{};
    if (!parsed.isAbsolute) {
      for (final entry in base.queryParametersAll.entries) {
        merged[entry.key] = <String>[...entry.value];
      }
    }
    for (final entry in resolved.queryParametersAll.entries) {
      merged[entry.key] = <String>[
        ...(merged[entry.key] ?? const <String>[]),
        ...entry.value,
      ];
    }
    for (final entry in queryParameters.entries) {
      merged[entry.key] = <String>[
        ...(merged[entry.key] ?? const <String>[]),
        ...entry.value,
      ];
    }
    if (merged.isEmpty) {
      return resolved;
    }
    return resolved.replace(
      queryParameters: <String, dynamic>{
        for (final entry in merged.entries) entry.key: entry.value,
      },
    );
  }

  @override
  Future<User> getUser(
    String id,
    int? page,
    String token, {
    AlphaXRequestOptions? options,
  }) async {
    final queryParameters = <String, Iterable<String>>{};
    if (page != null) {
      queryParameters["page"] = <String>[page.toString()];
    }
    final uri = _resolveUri(
      '/users/${Uri.encodeComponent(id)}',
      queryParameters,
    );
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    headers = headers.set("accept", "application/json");
    if (true) {
      headers = headers.set("Authorization", token.toString());
    }
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: options?.timeouts ?? const AlphaXTimeouts(),
      cancellationToken: options?.cancellationToken,
      protocolPreference:
          options?.protocolPreference ?? AlphaXProtocolPreference.auto,
      protocolRequirement: options?.protocolRequirement,
      redirectPolicy: options?.redirectPolicy ?? const AlphaXRedirectPolicy(),
      priority: options?.priority ?? AlphaXPriority.normal,
      onUploadProgress: options?.onUploadProgress,
      onDownloadProgress: options?.onDownloadProgress,
    );
    final response = await _client.send(request);
    final dynamic json = await response.readAsJson();
    return User.fromJson(json);
  }

  @override
  Future<User> createUser(CreateUser input) async {
    final uri = _resolveUri('/users', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: uri,
      headers: headers,
      body: AlphaXBody.json(input.toJson()),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    final dynamic json = await response.readAsJson();
    return User.fromJson(json);
  }

  @override
  Future<List<User>> listUsers() async {
    final uri = _resolveUri('/users', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    final dynamic json = await response.readAsJson();
    return (json as List<dynamic>)
        .map<User>((item) => User.fromJson(item))
        .toList(growable: false);
  }

  @override
  Future<AlphaXResponse> headerPrecedence() async {
    final uri = _resolveUri(
      '/header-precedence',
      const <String, Iterable<String>>{},
    );
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "method");
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Future<AlphaXResponse> sendText(String body) async {
    final uri = _resolveUri('/text', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: uri,
      headers: headers,
      body: AlphaXBody.text(body, contentType: "text/custom"),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Future<AlphaXResponse> sendBytes(List<int> body) async {
    final uri = _resolveUri('/bytes', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: uri,
      headers: headers,
      body: AlphaXBody.bytes(body),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Future<AlphaXResponse> sendStream(Stream<List<int>> body) async {
    final uri = _resolveUri('/stream', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: uri,
      headers: headers,
      body: AlphaXStreamBody(body),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Future<AlphaXResponse> sendFileBody(AlphaXFileSource source) async {
    final uri = _resolveUri('/file-body', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: uri,
      headers: headers,
      body: AlphaXFileBody(source),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Future<AlphaXResponse> cancellable(AlphaXCancellationToken? token) async {
    final uri = _resolveUri('/cancel', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: token,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Future<AlphaXResponse> search(List<String> tags) async {
    final queryParameters = <String, Iterable<String>>{};
    if (true) {
      queryParameters["tag"] = tags.map((value) => value.toString());
    }
    final uri = _resolveUri('/search', queryParameters);
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Future<JsonSerializableUser> getJsonSerializable() async {
    final uri = _resolveUri(
      '/json-serializable',
      const <String, Iterable<String>>{},
    );
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    final dynamic json = await response.readAsJson();
    return decodeJsonSerializableUser(json);
  }

  @override
  Future<FreezedUser> getFreezed() async {
    final uri = _resolveUri('/freezed', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    final dynamic json = await response.readAsJson();
    return decodeFreezedUser(json);
  }

  @override
  Future<AlphaXApiResponse<User>> replaceUser(
    String id,
    CreateUser input,
  ) async {
    final uri = _resolveUri(
      '/users/${Uri.encodeComponent(id)}',
      const <String, Iterable<String>>{},
    );
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.put,
      uri: uri,
      headers: headers,
      body: AlphaXBody.json(input.toJson()),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    final dynamic json = await response.readAsJson();
    return AlphaXApiResponse<User>(
      data: User.fromJson(json),
      response: response,
    );
  }

  @override
  Future<User> patchUser(String id, CreateUser input) async {
    final uri = _resolveUri(
      '/users/${Uri.encodeComponent(id)}',
      const <String, Iterable<String>>{},
    );
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.patch,
      uri: uri,
      headers: headers,
      body: AlphaXBody.json(input.toJson()),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    final dynamic json = await response.readAsJson();
    return User.fromJson(json);
  }

  @override
  Future<void> deleteUser(String id) async {
    final uri = _resolveUri(
      '/users/${Uri.encodeComponent(id)}',
      const <String, Iterable<String>>{},
    );
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.delete,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    await response.readAsBytes();
    return;
  }

  @override
  Future<AlphaXTransferResult> download(AlphaXFileTarget target) async {
    final uri = _resolveUri('/download', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    return _client.download(
      uri,
      to: target,
      headers: headers,
      timeout: null,
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      onDownloadProgress: null,
    );
  }

  @override
  Future<AlphaXTransferResult> upload(AlphaXFileSource source) async {
    final uri = _resolveUri('/upload', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    return _client.upload(
      uri,
      from: source,
      method: HttpMethod.post,
      headers: headers,
      timeout: null,
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      onUploadProgress: null,
    );
  }

  @override
  Future<AlphaXResponse> raw() async {
    final uri = _resolveUri('/raw', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Future<AlphaXResponse> head() async {
    final uri = _resolveUri('/health', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.head,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }

  @override
  Stream<List<int>> stream() async* {
    final uri = _resolveUri('/stream', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.get,
      uri: uri,
      headers: headers,
      body: const AlphaXEmptyBody(),
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    yield* response.stream;
  }

  @override
  Future<AlphaXResponse> multipart(AlphaXMultipartBody body) async {
    final uri = _resolveUri('/multipart', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    headers = headers.set("x-client", "typed-example");
    headers = headers.set("x-override", "api");
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: uri,
      headers: headers,
      body: body,
      timeouts: const AlphaXTimeouts(),
      cancellationToken: null,
      protocolPreference: AlphaXProtocolPreference.auto,
      protocolRequirement: null,
      redirectPolicy: const AlphaXRedirectPolicy(),
      priority: AlphaXPriority.normal,
      onUploadProgress: null,
      onDownloadProgress: null,
    );
    final response = await _client.send(request);
    return response;
  }
}
