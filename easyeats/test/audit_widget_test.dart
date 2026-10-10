import 'dart:async';
import 'dart:convert';
import 'package:easyeats/app/app.dart';
import 'package:easyeats/app/theme/app_theme.dart';
import 'package:easyeats/core/api_client.dart';
import 'package:easyeats/core/controllers.dart';
import 'package:easyeats/core/models.dart';
import 'package:easyeats/core/repository.dart';
import 'package:easyeats/features/onboarding/configuration_fields.dart';
import 'package:easyeats/features/profile/profile_screen.dart';
import 'package:easyeats/shared/meal_detail.dart';
import 'package:easyeats/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'widget_test.dart' as fixtures;

http.Response envelope(dynamic data) => http.Response(
  jsonEncode({
    'data': data,
    'meta': {
      'server_today': '2026-10-10',
      if (data is List) 'total': data.length,
    },
  }),
  200,
);
AppRepository fromHandler(
  Future<http.Response> Function(http.Request) handler,
) => AppRepository(
  ApiClient(client: MockClient(handler))
    ..baseUrl = 'http://localhost:8000'
    ..serverToday = '2026-10-10',
);
Meal meal({int version = 1}) => Meal.fromJson({
  'id': 'meal1',
  'cycle_id': 'cycle1',
  'date': '2026-10-11',
  'meal_slot': 'comida',
  'recipe_code': fixtures.recipe['code'],
  'recipe_snapshot': fixtures.recipe,
  'version': version,
  'compatibility': 'compatible',
  'cancelled': false,
  'can_swap': true,
  'can_feedback': true,
});
Widget opener(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDetail(context, child),
        child: const Text('Abrir'),
      ),
    ),
  ),
);

void main() {
  testWidgets('Las etiquetas informativas se leen sin casillas desmarcadas', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Tag('14 comidas publicadas'))),
    );
    expect(
      tester.getSemantics(find.byType(Tag)),
      matchesSemantics(label: '14 comidas publicadas'),
    );
    semantics.dispose();
  });
  testWidgets('Buscar atun encuentra Atún en el selector de ingredientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      opener(
        const MultiSelect(
          title: 'Ingredientes',
          choices: [
            {'code': 'atun', 'name': 'Atún'},
            {'code': 'arroz', 'name': 'Arroz'},
          ],
          selected: [],
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'atun');
    await tester.pumpAndSettle();
    expect(find.text('Atún'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);
  });
  testWidgets('Un error de red con texto grande no desborda una vista baja', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = LoadController<String>()
      ..data = 'Datos guardados'
      ..error = const ApiException(
        'OFFLINE',
        'No se puede conectar con el servidor. Comprueba la red y su dirección.',
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: LoadView(
              controller: controller,
              retry: () {},
              builder: (data, _) => Text(data),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
    'Cerrar una opinión mientras se carga no usa un controlador destruido',
    (tester) async {
      final pending = Completer<http.Response>();
      final repo = fromHandler((_) => pending.future);
      await tester.pumpWidget(
        opener(OpinionEditor(meal: meal(), repository: repo)),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      pending.complete(
        envelope([
          {
            'item_id': 'meal1',
            'version': 1,
            'rating': 1,
            'comment': 'Guardado',
          },
        ]),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('¿Qué te ha parecido?'), findsNothing);
    },
  );

  testWidgets(
    'Arrastrar una selección móvil no descarta cambios y Cerrar pide confirmación',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        opener(
          const MultiSelect(
            title: 'Escoge ingredientes',
            choices: [
              {'code': 'arroz', 'name': 'Arroz'},
            ],
            selected: [],
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arroz'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Escoge ingredientes'), const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.text('Escoge ingredientes'), findsOneWidget);
      expect(find.text('1 seleccionados'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar selección'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionados'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Un conflicto de sustitución recarga la comida y usa la versión actual',
    (tester) async {
      final alternative = {
        ...fixtures.recipe,
        'code': 'com002',
        'name': 'Plato alternativo',
      };
      final writes = <Json>[];
      final repo = fromHandler((request) async {
        if (request.method == 'PUT') {
          writes.add(jsonDecode(request.body) as Json);
          if (writes.length == 1) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'VERSION_CONFLICT',
                  'message': 'El plato cambió',
                  'details': {'current_version': 2},
                },
                'meta': {},
              }),
              409,
            );
          }
          return envelope({'item': meal(version: 3).data, 'swap_id': 'swap1'});
        }
        if (request.url.path.endsWith('/candidates')) {
          return envelope([alternative]);
        }
        return envelope(meal(version: 2).data);
      });
      await tester.pumpWidget(
        opener(CandidatePicker(meal: meal(), repository: repo)),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('Plato alternativo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cambiar plato'));
        await tester.pumpAndSettle();
      }
      expect(writes.map((x) => x['expected_version']).toList(), [1, 2]);
      expect(find.text('Platos compatibles'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Opinión conserva el formulario tras un conflicto y permite confirmar con la nueva versión',
    (tester) async {
      final writes = <Json>[];
      final repo = fromHandler((request) async {
        if (request.method == 'PUT') {
          writes.add(jsonDecode(request.body) as Json);
          if (writes.length == 1) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'VERSION_CONFLICT',
                  'message': 'Hay otra opinión',
                  'details': {'current_version': 2},
                },
                'meta': {},
              }),
              409,
            );
          }
          return envelope({'version': 3});
        }
        return envelope([
          {
            'item_id': 'meal1',
            'version': 2,
            'rating': -1,
            'comment': 'Otra pestaña',
          },
        ]);
      });
      await tester.pumpWidget(
        opener(
          OpinionEditor(
            meal: meal(),
            repository: repo,
            existing: {'version': 1, 'rating': 1, 'comment': 'Inicial'},
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mi comentario');
      await tester.tap(find.text('Guardar opinión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comprobar guardado y versión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conservar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Mi comentario'), findsOneWidget);
      await tester.ensureVisible(find.text('Guardar opinión'));
      await tester.tap(find.text('Guardar opinión'));
      await tester.pumpAndSettle();
      expect(writes.map((x) => x['expected_version']).toList(), [1, 2]);
      expect(writes.last['comment'], 'Mi comentario');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Los editores se adaptan a 320px con texto al 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final repo = fixtures.repository();
    final data = {
      'profile': fixtures.profile,
      'plan': {'version': 1, 'current_plan': 'free', 'pending_plan': null},
      'address': null,
      'options': {
        'ingredients': fixtures.recipe['ingredients'],
        'allergens': [],
        'categories': ['arroz'],
      },
    };
    for (final section in [
      'plan',
      'calendar',
      'restrictions',
      'preferences',
      'address',
    ]) {
      await tester.pumpWidget(
        opener(ProfileEditor(repository: repo, data: data, section: section)),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: section);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'El acceso de operario se adapta a móvil, tablet y escritorio con texto grande',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      for (final width in [320.0, 768.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        final repo = fixtures.repository();
        final s = fixtures.session(repo)
          ..session = {
            'user': {'id': 'op', 'alias': 'operario', 'role': 'operator'},
            'onboarding_completed': false,
          };
        await tester.pumpWidget(
          EasyEatsApp(repository: repo, session: s, restoreSession: false),
        );
        await tester.pumpAndSettle();
        expect(find.text('Todo al día'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$width');
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
