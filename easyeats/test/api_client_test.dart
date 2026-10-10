import 'dart:convert';
import 'dart:async';
import 'package:easyeats/core/api_client.dart';
import 'package:easyeats/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'El tiempo de espera cubre las cabeceras y mantiene la escritura incierta',
    () async {
      final api = ApiClient(
        requestTimeout: const Duration(milliseconds: 20),
        client: MockClient((_) => Completer<http.Response>().future),
      )..baseUrl = 'http://localhost:8000';
      await expectLater(
        api.request('PUT', '/profile', body: {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'OFFLINE')
              .having((e) => e.uncertain, 'uncertain', true),
        ),
      );
    },
  );

  test(
    'Respuestas con estructura incorrecta devuelven un error controlado',
    () async {
      for (final body in [
        '[]',
        'null',
        '{"data":{},"meta":[]}',
        '{"data":{},"meta":{"server_today":123}}',
        '{"meta":{}}',
      ]) {
        final api = ApiClient(
          client: MockClient((_) async => http.Response(body, 200)),
        )..baseUrl = 'http://localhost:8000';
        await expectLater(
          api.request('GET', '/profile'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'INVALID_RESPONSE',
            ),
          ),
        );
      }
    },
  );

  test(
    'Respuesta malformada de una escritura recupera el resultado confirmado',
    () async {
      var writes = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            writes++;
            return http.Response('<html>proxy</html>', 200);
          }
          return http.Response(
            jsonEncode({
              'data': {
                'state': 'completed',
                'result': {
                  'status': 200,
                  'data': {'swap_id': 'recovered'},
                },
              },
              'meta': {},
            }),
            200,
          );
        }),
      )..baseUrl = 'http://localhost:8000';
      final result = await api.operation(
        'PUT',
        '/menus/items/meal1/substitution',
        {},
      );
      expect(result.data['swap_id'], 'recovered');
      expect(writes, 1);
    },
  );

  test(
    'Una comprobación malformada conserva la clave para reintentar con seguridad',
    () async {
      var recovering = false;
      String? key;
      var writes = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            writes++;
            key = request.headers['Idempotency-Key'];
            throw http.ClientException('Lost response');
          }
          expect(request.url.path, '/api/v1/operations/$key');
          return http.Response(
            jsonEncode({
              'data': recovering
                  ? {
                      'result': {
                        'status': 200,
                        'data': {'swap_id': 'same_operation'},
                      },
                    }
                  : {'result': []},
              'meta': {},
            }),
            200,
          );
        }),
      )..baseUrl = 'http://localhost:8000';
      await expectLater(
        api.operation('PUT', '/menus/items/meal1/substitution', {}),
        throwsA(
          isA<ApiException>().having((e) => e.uncertain, 'uncertain', true),
        ),
      );
      recovering = true;
      final result = await api.operation(
        'PUT',
        '/menus/items/meal1/substitution',
        {},
      );
      expect(result.data['swap_id'], 'same_operation');
      expect(writes, 1);
    },
  );

  test('Un 401 sin JSON también invalida la sesión', () async {
    var expired = false;
    final api =
        ApiClient(client: MockClient((_) async => http.Response('', 401)))
          ..baseUrl = 'http://localhost:8000'
          ..onUnauthorized = () => expired = true;
    await expectLater(
      api.request('GET', '/profile'),
      throwsA(isA<ApiException>()),
    );
    expect(expired, isTrue);
  });
  test(
    'Una respuesta perdida recupera la misma operación sin duplicar escritura',
    () async {
      var writes = 0;
      String? key;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            writes++;
            key = request.headers['Idempotency-Key'];
            throw http.ClientException('Lost response');
          }
          expect(request.url.path, '/api/v1/operations/$key');
          return http.Response(
            jsonEncode({
              'data': {
                'state': 'completed',
                'result': {
                  'status': 200,
                  'data': {'swap_id': 'swap1'},
                },
              },
              'meta': {'server_today': '2026-10-10'},
            }),
            200,
          );
        }),
      )..baseUrl = 'http://localhost:8000';
      final result = await api.operation(
        'PUT',
        '/menus/items/meal1/substitution',
        {'expected_version': 1, 'recipe_code': 'com001'},
      );
      expect(writes, 1);
      expect(result.data['swap_id'], 'swap1');
    },
  );
  test('Conflicto conserva los detalles de versión', () async {
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'VERSION_CONFLICT',
              'message': 'Recarga',
              'details': {'current_version': 3},
            },
            'meta': {},
          }),
          409,
        ),
      ),
    )..baseUrl = 'http://localhost:8000';
    expect(
      () => api.request('PUT', '/profile', body: {'expected_version': 1}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.details['current_version'],
          'version',
          3,
        ),
      ),
    );
  });
  test('Dirección API rechaza credenciales y rutas', () {
    final api = ApiClient();
    for (final url in [
      'http://user:secret@host:8000',
      'http://host:8000/api/v1',
      'file:///tmp',
      'http://host?token=x',
    ]) {
      expect(() => api.validateServer(url), throwsA(isA<ApiException>()));
    }
    expect(
      api.validateServer('http://192.168.1.20:8000/'),
      'http://192.168.1.20:8000',
    );
  });
}
