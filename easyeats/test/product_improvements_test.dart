import 'package:easyeats/app/theme/app_theme.dart';
import 'package:easyeats/core/models.dart';
import 'package:easyeats/features/menu/week_screen.dart';
import 'package:easyeats/features/operator/operator_screen.dart';
import 'package:easyeats/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'audit_widget_test.dart' as audit;
import 'widget_test.dart' as fixtures;

Widget shell(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'Perfil muestra favoritos guardados y organiza tarjetas sin desbordar con texto grande',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final repo = audit.fromHandler((request) async {
        dynamic data;
        if (request.url.path.endsWith('/profile')) {
          data = {
            ...fixtures.profile,
            'liked_ingredient_codes': ['arroz'],
          };
        } else if (request.url.path.endsWith('/plan')) {
          data = {
            'current_plan': 'free',
            'pending_plan': null,
            'can_view_delivery': false,
          };
        } else if (request.url.path.endsWith('/options')) {
          data = {
            'ingredients': fixtures.recipe['ingredients'],
            'allergens': [],
            'categories': [],
          };
        }
        return audit.envelope(data);
      });
      for (final width in [320.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(shell(ProfileScreen(repository: repo)));
        await tester.pumpAndSettle();
        final plan = find.byKey(const ValueKey('profile-plan'));
        final calendar = find.byKey(const ValueKey('profile-calendar'));
        if (width == 1440) {
          expect(tester.getTopLeft(plan).dy, tester.getTopLeft(calendar).dy);
          expect(
            tester.getTopLeft(calendar).dx,
            greaterThan(tester.getTopLeft(plan).dx),
          );
        } else {
          expect(
            tester.getTopLeft(calendar).dy,
            greaterThan(tester.getTopLeft(plan).dy),
          );
        }
        await tester.ensureVisible(find.text('Editar preferencias'));
        expect(find.textContaining('Te gusta: Arroz.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'La comida destacada incompatible invita a revisarla y no se presenta como recomendación vigente',
    (tester) async {
      final first = {...audit.meal().data, 'compatibility': 'needs_attention'};
      final second = {...audit.meal().data, 'id': 'meal2', 'meal_slot': 'cena'};
      final repo = audit.fromHandler((request) async {
        if (request.url.path.endsWith('/profile')) {
          return audit.envelope(fixtures.profile);
        }
        if (request.url.path.endsWith('/ensure')) {
          return audit.envelope({'id': 'cycle1', 'status': 'approved'});
        }
        return audit.envelope({
          'start': '2026-10-05',
          'end': '2026-10-11',
          'pending_generation_ids': [],
          'pending_initial_review': false,
          'can_view_delivery': false,
          'summary': {'published_item_count': 2, 'next_item_id': 'meal1'},
          'cycle_segments': [
            {'month': '2026-10', 'status': 'approved'},
          ],
          'days': List.generate(
            7,
            (index) => {
              'date': dateKey(DateTime(2026, 10, 5 + index)),
              'scheduled_slots': [],
              'items': index == 6 ? [first, second] : [],
            },
          ),
        });
      });
      await tester.pumpWidget(shell(WeekScreen(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('Una comida para revisar'), findsOneWidget);
      expect(find.text('Ver comida pendiente'), findsOneWidget);
      expect(find.text('Próxima comida de esta semana'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Operario muestra las restricciones por nombre y respeta el bloqueo de aprobación del servidor',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cycle = {
        'id': 'cycle1',
        'month': '2026-10',
        'status': 'pending_review',
        'version': 1,
        'user': {'alias': 'cliente_prueba'},
        'generation_origin': 'test',
        'profile': {
          ...fixtures.profile,
          'allergen_codes': ['sesamo'],
          'excluded_ingredient_codes': ['arroz'],
        },
        'profile_labels': {
          'allergens': [
            {'code': 'sesamo', 'name': 'Sésamo', 'known': true},
          ],
          'excluded_ingredients': fixtures.recipe['ingredients'],
          'liked_ingredients': [],
          'disliked_ingredients': [],
        },
        'items': [audit.meal().data],
        'warnings': [],
        'requires_refresh': false,
        'latest_generation': null,
        'review_summary': {
          'can_approve': false,
          'blocking_reasons': [
            {'message': 'Hay platos incompatibles en la propuesta.'},
          ],
        },
      };
      var writes = 0;
      final repo = audit.fromHandler((request) async {
        if (request.method != 'GET') writes++;
        return audit.envelope(
          request.url.path.endsWith('/reviews') ? [cycle] : cycle,
        );
      });
      await tester.pumpWidget(shell(OperatorScreen(repository: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cliente_prueba'));
      await tester.pumpAndSettle();
      expect(find.text('Sésamo'), findsOneWidget);
      expect(find.text('Arroz'), findsOneWidget);
      final approve = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprobar menú'),
      );
      expect(approve.onPressed, isNull);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
