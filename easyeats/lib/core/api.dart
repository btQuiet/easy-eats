import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiError implements Exception {
  final String message;
  final int? status;
  final String? code;

  const ApiError(this.message, {this.status, this.code});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:8000',
          );

  String baseUrl;
  String? token;
  final http.Client _client = http.Client();

  void dispose() => _client.close();

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) =>
      _request('POST', path, body: body);

  Future<dynamic> put(String path, Object body) =>
      _request('PUT', path, body: body);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    try {
      final uri = Uri.parse(
        '${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path',
      ).replace(queryParameters: query);
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 100));
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 400) {
        final detail = decoded is Map ? decoded['detail'] : null;
        final message = detail is String
            ? detail
            : detail is List
            ? detail.map((value) => value['msg'] ?? value.toString()).join(', ')
            : 'Error del servidor (${response.statusCode})';
        throw ApiError(
          message,
          status: response.statusCode,
          code: decoded is Map ? decoded['code']?.toString() : null,
        );
      }
      return decoded;
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        'No se pudo conectar con FastAPI. Revisa la dirección del servidor y la LAN.',
      );
    }
  }
}
