import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'platform_client.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? createClient();
  final http.Client _client;
  final Duration requestTimeout;
  String baseUrl = '';
  String? token;
  String? csrf;
  String? serverToday;
  String generationMode = 'test';
  VoidCallback? onUnauthorized;
  final Map<String, String> _operationKeys = {};
  void clearOperations() => _operationKeys.clear();

  Future<void> configure() async {
    const configured = String.fromEnvironment('API_BASE_URL');
    final stored = await readSetting('server');
    final host = webHost();
    baseUrl =
        stored ??
        (configured.isNotEmpty
            ? configured
            : host != null
            ? 'http://$host:8000'
            : defaultTargetPlatform == TargetPlatform.android
            ? ''
            : 'http://localhost:8000');
    token = kIsWeb ? null : await readSetting('token');
  }

  String validateServer(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ApiException(
        'INVALID_INPUT',
        'Usa la dirección raíz del servidor: http://equipo:8000',
      );
    }
    final host = webHost();
    if (host != null && uri.host != host) {
      throw ApiException(
        'INVALID_INPUT',
        'En web, el servidor debe usar el mismo host que esta página ($host).',
      );
    }
    return uri.replace(path: '').toString();
  }

  Future<void> setServer(String value) async {
    final validated = validateServer(value);
    token = null;
    csrf = null;
    clearOperations();
    await writeSetting('token', null);
    baseUrl = validated;
    await writeSetting('server', validated);
  }

  Future<ApiResult> request(
    String method,
    String path, {
    Json? body,
    String? key,
  }) async {
    if (baseUrl.isEmpty) {
      throw const ApiException(
        'SERVER_REQUIRED',
        'Configura la dirección del servidor LAN.',
      );
    }
    final request = http.Request(method, Uri.parse('$baseUrl/api/v1$path'));
    request.headers['Content-Type'] = 'application/json';
    if (!kIsWeb && token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (csrf != null) request.headers['X-CSRF-Token'] = csrf!;
    if (key != null) request.headers['Idempotency-Key'] = key;
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(requestTimeout);
    } on Exception {
      throw ApiException(
        'OFFLINE',
        method == 'GET'
            ? 'No se puede conectar con el servidor. Comprueba la red y su dirección.'
            : 'No se pudo confirmar el guardado. Comprueba el estado antes de repetir.',
        uncertain: method != 'GET',
      );
    }
    if (response.statusCode == 204) return const ApiResult(null, {}, 204);
    if (response.statusCode == 401) onUnauthorized?.call();
    Json payload, meta;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Json || decoded['meta'] is! Json) {
        throw const FormatException('Invalid envelope');
      }
      payload = decoded;
      meta = decoded['meta'] as Json;
      if ((meta['server_today'] != null && meta['server_today'] is! String) ||
          (meta['generation_mode'] != null &&
              meta['generation_mode'] is! String)) {
        throw const FormatException('Invalid metadata');
      }
      if (response.statusCode >= 400) {
        final error = payload['error'];
        if (error is! Json ||
            error['code'] is! String ||
            error['message'] is! String ||
            error['details'] is! Json) {
          throw const FormatException('Invalid error');
        }
      } else if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          !payload.containsKey('data')) {
        throw const FormatException('Invalid success');
      }
    } on FormatException {
      throw ApiException(
        'INVALID_RESPONSE',
        method == 'GET'
            ? 'El servidor no devolvió una respuesta válida.'
            : 'La respuesta del servidor no permite confirmar el guardado. Comprueba su estado antes de repetir.',
        uncertain: method != 'GET',
      );
    }
    serverToday = meta['server_today'] as String? ?? serverToday;
    generationMode = meta['generation_mode'] as String? ?? generationMode;
    if (response.statusCode >= 400) {
      final error = (payload['error'] as Json?) ?? {};
      throw ApiException(
        error['code'] as String? ?? 'SERVER_ERROR',
        error['message'] as String? ?? 'No se pudo completar la operación.',
        details: (error['details'] as Json?) ?? {},
        uncertain: method != 'GET' && response.statusCode >= 500,
      );
    }
    return ApiResult(payload['data'], meta, response.statusCode);
  }

  ApiResult _recovered(ApiResult recovery) {
    final data = recovery.data;
    final result = data is Json ? data['result'] : null;
    if (result is! Json ||
        result['status'] is! int ||
        !result.containsKey('data')) {
      throw const ApiException(
        'INVALID_RESPONSE',
        'No se pudo comprobar el resultado del guardado.',
        uncertain: true,
      );
    }
    return ApiResult(result['data'], recovery.meta, result['status'] as int);
  }

  Future<ApiResult> operation(
    String method,
    String path,
    Json body, {
    String? operationKey,
  }) async {
    final fingerprint = '$method $path ${jsonEncode(body)}';
    final pending = _operationKeys.containsKey(fingerprint);
    final key = operationKey ?? _operationKeys[fingerprint] ?? newKey();
    _operationKeys[fingerprint] = key;
    if (pending) {
      try {
        final recovery = await request('GET', '/operations/$key');
        final result = _recovered(recovery);
        _operationKeys.remove(fingerprint);
        return result;
      } on ApiException catch (lookup) {
        if (lookup.code != 'NOT_FOUND') rethrow;
      }
    }
    try {
      final result = await request(method, path, body: body, key: key);
      _operationKeys.remove(fingerprint);
      return result;
    } on ApiException catch (error) {
      if (!error.uncertain) {
        _operationKeys.remove(fingerprint);
        rethrow;
      }
      try {
        final recovery = await request('GET', '/operations/$key');
        final result = _recovered(recovery);
        _operationKeys.remove(fingerprint);
        return result;
      } on ApiException catch (lookup) {
        if (lookup.code != 'NOT_FOUND') rethrow;
        final result = await request(method, path, body: body, key: key);
        _operationKeys.remove(fingerprint);
        return result;
      }
    }
  }

  static String newKey() {
    final random = Random.secure();
    final b = List.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  void close() => _client.close();
}
