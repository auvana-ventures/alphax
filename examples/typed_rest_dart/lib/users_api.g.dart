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
    final base = Uri.parse("https://api.example.test");
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
  Future<User> getUser(String id) async {
    final uri = _resolveUri(
      '/users/${Uri.encodeComponent(id)}',
      const <String, Iterable<String>>{},
    );
    var headers = const AlphaXHeaders.empty();
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
    return User.fromJson(json);
  }
}
