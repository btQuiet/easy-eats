import 'dart:convert';
import 'package:easyeats/app/app.dart';
import 'package:easyeats/app/theme/app_theme.dart';
import 'package:easyeats/core/api_client.dart';
import 'package:easyeats/core/controllers.dart';
import 'package:easyeats/core/models.dart';
import 'package:easyeats/core/repository.dart';
import 'package:easyeats/features/onboarding/configuration_fields.dart';
import 'package:easyeats/features/menu/week_screen.dart';
import 'package:easyeats/features/operator/operator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final recipe = <String, dynamic>{
  'code': 'com001',
  'name': 'Arroz de temporada',
  'category': 'arroz',
  'ingredients': [
    {'code': 'arroz', 'name': 'Arroz'},
  ],
  'allergens': [],
  'is_vegan': true,
  'is_vegetarian': true,
  'compatible': true,
};
final profile = <String, dynamic>{
  ...defaultConfiguration(),
  'version': 1,
  'completed': true,
  'initial_review_completed': true,
  'service_start_date': '2026-10-11',
  'next_calendar_effective_month': '2026-11',
};

AppRepository repository({
  List<http.Request>? requests,
  bool pendingReview = false,
}) {
  final api = ApiClient(
    client: MockClient((request) async {
      requests?.add(request);
      dynamic data = {};
      final path = request.url.path;
      if (path.endsWith('/profile')) {
        data = profile;
      } else if (path.endsWith('/plan')) {
        data = {
          'version': 1,
          'current_plan': 'free',
          'pending_plan': null,
          'can_view_delivery': false,
        };
      } else if (path.endsWith('/options')) {
        data = {
          'ingredients': recipe['ingredients'],
          'allergens': [],
          'categories': ['arroz'],
        };
      } else if (path.endsWith('/recipes')) {
        data = [recipe];
      } else if (path.endsWith('/address')) {
        data = null;
      } else if (path.endsWith('/week')) {
        final start = DateTime.parse(request.url.queryParameters['start']!);
        final meal = {
          'id': 'meal1',
          'cycle_id': 'cycle1',
          'date': '2026-10-11',
          'meal_slot': 'comida',
          'recipe_code': recipe['code'],
          'recipe_snapshot': recipe,
          'version': 1,
          'compatibility': 'compatible',
          'cancelled': false,
          'can_swap': true,
          'can_feedback': false,
        };
        data = {
          'start': dateKey(start),
          'end': dateKey(start.add(const Duration(days: 6))),
          'pending_generation_ids': [],
          'pending_initial_review': pendingReview,
          'can_view_delivery': false,
          'cycle_segments': [
            {'month': '2026-10', 'status': 'approved', 'cycle_id': 'cycle1'},
          ],
          'days': List.generate(
            7,
            (i) => {
              'date': dateKey(start.add(Duration(days: i))),
              'scheduled_slots': ['comida'],
              'items': i == 6 ? [meal] : [],
            },
          ),
        };
      } else if (path.endsWith('/ensure')) {
        data = {'id': 'cycle1', 'status': 'approved'};
      } else if (path.endsWith('/operator/reviews')) {
        data = [];
      }
      return http.Response(
        jsonEncode({
          'data': data,
          'meta': {
            'server_today': '2026-10-10',
            'total': data is List ? data.length : 0,
          },
        }),
        200,
      );
    }),
  );
  api.baseUrl = 'http://localhost:8000';
  api.serverToday = '2026-10-10';
  return AppRepository(api);
}

SessionController session(AppRepository repo, {bool signedIn = true}) {
  final s = SessionController(repo)..restoring = false;
  if (signedIn) {
    s.session = {
      'user': {'id': 'client1', 'alias': 'demo', 'role': 'client'},
      'onboarding_completed': true,
    };
  }
  return s;
}

void main() {
  testWidgets(
    'Semana y operario pausan consultas en segundo plano y refrescan al volver',
    (tester) async {
      final requests = <http.Request>[];
      final repo = repository(requests: requests, pendingReview: true);
      for (final screen in [
        WeekScreen(repository: repo),
        OperatorScreen(repository: repo),
      ]) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: screen),
          ),
        );
        await tester.pumpAndSettle();
        final initial = requests.length;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(requests.length, greaterThan(initial));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        final paused = requests.length;
        await tester.pump(const Duration(seconds: 3));
        expect(requests.length, paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(requests.length, greaterThan(paused));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('Texto al 200% conserva navegación y tarjetas a 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final repo = repository(), s = session(repository());
    await tester.pumpWidget(
      EasyEatsApp(repository: repo, session: s, restoreSession: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mi semana'), findsOneWidget);
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Ideas para tu mesa.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Acceso y validación se adaptan a 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = repository(), s = session(repository(), signedIn: false);
    await tester.pumpWidget(
      EasyEatsApp(repository: repo, session: s, restoreSession: false),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Usa 3–30 letras, números o guion bajo.'), findsOneWidget);
    expect(find.text('Entre 8 y 128 caracteres.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Semana, catálogo y perfil usan navegación móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = repository(), s = session(repository());
    await tester.pumpWidget(
      EasyEatsApp(repository: repo, session: s, restoreSession: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tu semana, resuelta.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Ideas para tu mesa.'), findsOneWidget);
    expect(find.text('Arroz de temporada'), findsOneWidget);
    await tester.tap(find.text('Arroz de temporada'));
    await tester.pumpAndSettle();
    expect(find.text('Ingredientes'), findsOneWidget);
    expect(find.text('Alérgenos modelados'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Hecho a tu medida.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Escritorio muestra sidebar y tema oscuro', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    final repo = repository(), s = session(repository());
    await tester.pumpWidget(
      EasyEatsApp(repository: repo, session: s, restoreSession: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Mi semana'), findsOneWidget);
    final context = tester.element(find.text('Tu semana, resuelta.'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).colorScheme.surface, AppColors.darkPaper);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
