import 'package:alphax_native/alphax_native.dart';

part 'local_fixture_api.g.dart';

@AlphaXApi(baseUrl: 'http://127.0.0.1:45871')
abstract class LocalFixtureApi {
  factory LocalFixtureApi(AlphaXClient client) = _LocalFixtureApi;

  @AlphaXGet('/echo/{value}')
  Future<String> echo(@AlphaXPath('value') String value);

  @AlphaXPost('/json')
  Future<Map<String, dynamic>> postJson(
    @AlphaXBodyParam() Map<String, dynamic> body,
  );

  @AlphaXPut('/methods/put')
  Future<String> put(@AlphaXBodyParam() Map<String, dynamic> body);

  @AlphaXPatch('/methods/patch')
  Future<String> patch(@AlphaXBodyParam() Map<String, dynamic> body);

  @AlphaXDelete('/methods/delete')
  Future<void> remove();

  @AlphaXHead('/health')
  Future<AlphaXResponse> head();

  @AlphaXGet('/empty')
  Future<String?> empty();

  @AlphaXGet('/status')
  Future<AlphaXApiResponse<String>> status();

  @AlphaXGet('/slow')
  Future<String> slow({@AlphaXOptions() AlphaXRequestOptions? options});

  @AlphaXGet('/stream')
  Stream<List<int>> stream();

  @AlphaXPost('/multipart')
  Future<AlphaXResponse> multipart(
    @AlphaXBodyParam(encoding: AlphaXBodyEncoding.multipart)
    AlphaXMultipartBody body,
  );
}
