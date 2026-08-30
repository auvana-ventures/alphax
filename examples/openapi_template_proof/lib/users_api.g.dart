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
    final base = Uri.parse("http://127.0.0.1:45874/");
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
  Future<User?> createUser(CreateUser createUser) async {
    final uri = _resolveUri('/users', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: uri,
      headers: headers,
      body: AlphaXBody.json(createUser.toJson()),
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
    final dynamic json = await response.readAsJsonOrNull();
    if (json == null) {
      return null;
    }
    return User.fromJson(json);
  }

  @override
  Future<User?> getUser(String id, String xRequestID, bool? verbose) async {
    final queryParameters = <String, Iterable<String>>{};
    if (verbose != null) {
      queryParameters["verbose"] = <String>[verbose.toString()];
    }
    final uri = _resolveUri(
      '/users/${Uri.encodeComponent(id)}',
      queryParameters,
    );
    var headers = const AlphaXHeaders.empty();
    if (true) {
      headers = headers.set("X-Request-ID", xRequestID.toString());
    }
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
    final dynamic json = await response.readAsJsonOrNull();
    if (json == null) {
      return null;
    }
    return User.fromJson(json);
  }
}
