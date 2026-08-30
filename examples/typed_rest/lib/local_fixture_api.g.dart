// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_fixture_api.dart';

// **************************************************************************
// AlphaXApiGenerator
// **************************************************************************

class _LocalFixtureApi implements LocalFixtureApi {
  _LocalFixtureApi(this._client);

  final AlphaXClient _client;

  Uri _resolveUri(
    String endpoint,
    Map<String, Iterable<String>> queryParameters,
  ) {
    final base = Uri.parse("http://127.0.0.1:45871");
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
  Future<String> echo(String value) async {
    final uri = _resolveUri(
      '/echo/${Uri.encodeComponent(value)}',
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
    return await response.readAsString();
  }

  @override
  Future<Map<String, dynamic>> postJson(Map<String, dynamic> body) async {
    final uri = _resolveUri('/json', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    final request = AlphaXRequest(
      method: HttpMethod.post,
      uri: uri,
      headers: headers,
      body: AlphaXBody.json(body),
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
    return (await response.readAsJson()) as Map<String, dynamic>;
  }

  @override
  Future<String> put(Map<String, dynamic> body) async {
    final uri = _resolveUri('/methods/put', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
    final request = AlphaXRequest(
      method: HttpMethod.put,
      uri: uri,
      headers: headers,
      body: AlphaXBody.json(body),
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
    return await response.readAsString();
  }

  @override
  Future<String> patch(Map<String, dynamic> body) async {
    final uri = _resolveUri(
      '/methods/patch',
      const <String, Iterable<String>>{},
    );
    var headers = const AlphaXHeaders.empty();
    final request = AlphaXRequest(
      method: HttpMethod.patch,
      uri: uri,
      headers: headers,
      body: AlphaXBody.json(body),
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
    return await response.readAsString();
  }

  @override
  Future<void> remove() async {
    final uri = _resolveUri(
      '/methods/delete',
      const <String, Iterable<String>>{},
    );
    var headers = const AlphaXHeaders.empty();
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
  Future<AlphaXResponse> head() async {
    final uri = _resolveUri('/health', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
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
  Future<String?> empty() async {
    final uri = _resolveUri('/empty', const <String, Iterable<String>>{});
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
    return await response.readAsStringOrNull();
  }

  @override
  Future<AlphaXApiResponse<String>> status() async {
    final uri = _resolveUri('/status', const <String, Iterable<String>>{});
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
    return AlphaXApiResponse<String>(
      data: await response.readAsString(),
      response: response,
    );
  }

  @override
  Future<String> slow({AlphaXRequestOptions? options}) async {
    final uri = _resolveUri('/slow', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
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
    return await response.readAsString();
  }

  @override
  Stream<List<int>> stream() async* {
    final uri = _resolveUri('/stream', const <String, Iterable<String>>{});
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
    yield* response.stream;
  }

  @override
  Future<AlphaXResponse> multipart(AlphaXMultipartBody body) async {
    final uri = _resolveUri('/multipart', const <String, Iterable<String>>{});
    var headers = const AlphaXHeaders.empty();
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
