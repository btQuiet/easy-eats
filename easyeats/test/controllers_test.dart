import 'dart:async';
import 'dart:convert';
import 'package:easyeats/core/api_client.dart';
import 'package:easyeats/core/controllers.dart';
import 'package:easyeats/core/models.dart';
import 'package:easyeats/core/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class ConfiguredClient extends ApiClient {
  ConfiguredClient(http.Client client) : super(client: client);
  @override
  Future<void> configure() async {
    baseUrl = 'http://localhost:8000';
  }
}

void main() {
  test(
    'Cerrar sesión sin red impide recuperar la cookie anterior y un nuevo acceso limpia el cierre',
    () async {
      final stored = <String, String>{};
      var sessionRequests = 0;
      final sessionData = {
        'user': {'id': '1', 'alias': 'demo', 'role': 'client'},
        'onboarding_completed': true,
        'csrf_token': 'csrf',
      };
      final repo = AppRepository(
        ConfiguredClient(
          MockClient((request) async {
            if (request.url.path.endsWith('/logout')) {
              throw http.ClientException('Offline');
            }
            if (request.url.path.endsWith('/session')) sessionRequests++;
            return http.Response(
              jsonEncode({
                'data': request.url.path.endsWith('/capabilities')
                    ? {}
                    : sessionData,
                'meta': {},
              }),
              200,
            );
          }),
        ),
      );
      Future<String?> read(String key) async => stored[key];
      Future<void> write(String key, String? value) async {
        if (value == null) {
          stored.remove(key);
        } else {
          stored[key] = value;
        }
      }

      final first = SessionController(
        repo,
        readConfiguration: read,
        writeConfiguration: write,
      )..session = sessionData;
      await first.logout();
      expect(first.signedIn, isFalse);
      expect(stored['session_closed'], 'true');
      final restored = SessionController(
        repo,
        readConfiguration: read,
        writeConfiguration: write,
      );
      await restored.restore();
      expect(restored.signedIn, isFalse);
      expect(sessionRequests, 0);
      await restored.authenticate('demo', 'fictional_password', false);
      expect(restored.signedIn, isTrue);
      expect(stored['session_closed'], isNull);
      await restored.restore();
      expect(sessionRequests, 1);
      first.dispose();
      restored.dispose();
    },
  );
  test(
    'Restauración pendiente no notifica después de destruir la sesión',
    () async {
      final pending = Completer<http.Response>();
      final repo = AppRepository(
        ConfiguredClient(MockClient((_) => pending.future)),
      );
      final session = SessionController(
        repo,
        readConfiguration: (_) async => 'true',
        writeConfiguration: (_, _) async {},
      );
      final restoration = session.restore();
      await Future<void>.delayed(Duration.zero);
      session.dispose();
      pending.complete(http.Response('{"data":{},"meta":{}}', 200));
      await restoration;
      expect(repo.api.onUnauthorized, isNull);
    },
  );
  test('Las respuestas antiguas no reemplazan datos recientes', () async {
    final controller = LoadController<int>();
    final old = Completer<int>();
    final newResult = Completer<int>();
    final oldRequest = controller.load(() => old.future);
    final newRequest = controller.load(() => newResult.future);
    newResult.complete(2);
    await newRequest;
    old.complete(1);
    await oldRequest;
    expect(controller.data, 2);
    expect(controller.loading, isFalse);
    controller.dispose();
  });
  test(
    'Una respuesta con data incorrecto conserva la vista y termina la carga',
    () async {
      final repo = AppRepository(
        ConfiguredClient(
          MockClient((_) async => http.Response('{"data":[],"meta":{}}', 200)),
        ),
      )..api.baseUrl = 'http://localhost:8000';
      final controller = LoadController<Json>()..data = {'cached': true};
      await controller.load(() => repo.get('/profile'));
      expect(controller.error?.code, 'INVALID_RESPONSE');
      expect(controller.data?['cached'], isTrue);
      expect(controller.loading, isFalse);
      controller.dispose();
    },
  );
}
