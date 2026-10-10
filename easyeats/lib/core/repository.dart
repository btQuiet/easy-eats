import 'api_client.dart';
import 'models.dart';

class AppRepository {
  AppRepository(this.api);
  final ApiClient api;
  Future<Json> get(String path) async =>
      _object((await api.request('GET', path)).data);
  Future<List<dynamic>> list(String path) async {
    final data = (await api.request('GET', path)).data;
    if (data is! List) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'El servidor no devolvió la lista esperada.',
      );
    }
    return data;
  }

  Future<Json> write(String method, String path, Json body) async => _object(
    (await api.request(method, path, body: body)).data,
    uncertain: true,
  );
  Json _object(dynamic data, {bool uncertain = false}) {
    if (data is! Json) {
      throw ApiException(
        'INVALID_RESPONSE',
        'El servidor no devolvió los datos esperados.',
        uncertain: uncertain,
      );
    }
    return data;
  }

  Future<ApiResult> operation(String method, String path, Json body) =>
      api.operation(method, path, body);
}
