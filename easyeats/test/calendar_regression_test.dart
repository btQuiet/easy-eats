import 'dart:convert';
import 'package:easyeats/app/theme/app_theme.dart';
import 'package:easyeats/core/api_client.dart';
import 'package:easyeats/core/controllers.dart';
import 'package:easyeats/core/models.dart';
import 'package:easyeats/core/repository.dart';
import 'package:easyeats/features/feedback/feedback_screen.dart';
import 'package:easyeats/features/menu/week_screen.dart';
import 'package:easyeats/features/onboarding/configuration_fields.dart';
import 'package:easyeats/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// The mock enforces the real API's Monday requirement. Response dates use civil
// UTC components so the fixture itself never introduces a local DST shift.
AppRepository calendarRepository(String today, List<String> weeks) {
  http.Response response(dynamic data) => http.Response(
    jsonEncode({
      'data': data,
      'meta': {'server_today': today, 'total': 0},
    }),
    200,
  );
  return AppRepository(
    ApiClient(
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/week')) {
            final key = request.url.queryParameters['start']!;
            weeks.add(key);
            final start = DateTime.parse('${key}T00:00:00Z');
            if (start.weekday != DateTime.monday) {
              return http.Response(
                jsonEncode({
                  'error': {
                    'code': 'INVALID_INPUT',
                    'message': 'La semana debe comenzar un lunes.',
                    'details': {},
                  },
                  'meta': {'server_today': today},
                }),
                422,
              );
            }
            final days = List.generate(
              7,
              (i) => {
                'date': dateKey(
                  DateTime.utc(start.year, start.month, start.day + i),
                ),
                'scheduled_slots': [],
                'items': [],
              },
            );
            return response({
              'start': key,
              'end': days.last['date'],
              'days': days,
              'pending_generation_ids': [],
              'pending_initial_review': false,
              'can_view_delivery': false,
              'cycle_segments': [
                for (final month
                    in days
                        .map((d) => (d['date'] as String).substring(0, 7))
                        .toSet())
                  {'month': month, 'status': 'approved'},
              ],
            });
          }
          if (path.endsWith('/profile')) {
            return response({
              ...defaultConfiguration(),
              'version': 1,
              'service_start_date': '${today.substring(0, 7)}-01',
              'initial_review_completed': true,
            });
          }
          if (path.endsWith('/ensure')) {
            return response({'id': 'cycle', 'status': 'approved'});
          }
          if (path.endsWith('/feedback')) return response([]);
          if (path.endsWith('/options')) {
            return response({
              'ingredients': [],
              'allergens': [],
              'categories': [],
            });
          }
          if (path.endsWith('/draft')) return response({'version': 2});
          throw StateError('Unexpected request: ${request.method} $path');
        }),
      )
      ..baseUrl = 'http://localhost:8000'
      ..serverToday = today,
  );
}

Widget shell(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  test(
    'Las fechas civiles conservan sus componentes y los límites de mes y año',
    () {
      final local = DateTime(2026, 10, 25, 23, 30);
      expect(calendarDate(local), DateTime.utc(2026, 10, 25));
      expect(addCalendarDays(local, 1), DateTime.utc(2026, 10, 26));
      expect(mondayOf(local), DateTime.utc(2026, 10, 19));
      expect(
        addCalendarDays(DateTime.utc(2026, 12, 31), 1),
        DateTime.utc(2027),
      );
      expect(
        addCalendarDays(DateTime.utc(2028, 2, 28), 1),
        DateTime.utc(2028, 2, 29),
      );
      expect(
        addCalendarDays(DateTime.utc(2028, 3), -1),
        DateTime.utc(2028, 2, 29),
      );
    },
  );
  for (final dates in [
    ['2026-10-19', '2026-10-26', '2026-11-02'],
    ['2026-03-23', '2026-03-30', '2026-04-06'],
  ]) {
    testWidgets('Navegar semanas mantiene lunes al cruzar ${dates[1]}', (
      tester,
    ) async {
      final weeks = <String>[];
      final repo = calendarRepository(dates.first, weeks);
      await tester.pumpWidget(shell(WeekScreen(repository: repo)));
      await tester.pumpAndSettle();
      for (final entry in [
        ('Próxima semana', dates[1]),
        ('Próxima semana', dates[2]),
        ('Semana anterior', dates[1]),
        ('Semana anterior', dates[0]),
      ]) {
        await tester.tap(find.byTooltip(entry.$1));
        await tester.pumpAndSettle();
        expect(weeks.last, entry.$2);
        expect(find.textContaining('La semana debe comenzar'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Opiniones consulta dos lunes tras el cambio de hora de marzo', (
    tester,
  ) async {
    final weeks = <String>[];
    await tester.pumpWidget(
      shell(
        FeedbackScreen(repository: calendarRepository('2026-03-30', weeks)),
      ),
    );
    await tester.pumpAndSettle();
    expect(weeks, ['2026-03-30', '2026-03-23']);
    expect(find.text('Tu opinión cuenta.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'El selector de inicio comienza mañana al cambiar la hora de octubre',
    (tester) async {
      await tester.pumpWidget(
        shell(
          ConfigurationFields(
            step: 'summary',
            fields: defaultConfiguration(),
            options: const {},
            onChanged: () {},
            today: '2026-10-25',
          ),
        ),
      );
      await tester.tap(find.text('Inicio: Elegir fecha'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dateKey(picker.firstDate), '2026-10-26');
      expect(dateKey(picker.initialDate!), '2026-10-26');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'El asistente propone un inicio futuro durante el cambio de hora',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = calendarRepository('2026-10-25', []);
      final session = SessionController(repo);
      addTearDown(session.dispose);
      await tester.pumpWidget(shell(OnboardingScreen(session: session)));
      await tester.pumpAndSettle();
      for (var step = 0; step < 4; step++) {
        await tester.scrollUntilVisible(find.text('Guardar y continuar'), 300);
        await tester.ensureVisible(find.text('Guardar y continuar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar y continuar'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Todo listo para empezar'), findsOneWidget);
      expect(
        tester
            .widget<ConfigurationFields>(find.byType(ConfigurationFields))
            .fields['service_start_date'],
        '2026-10-26',
      );
      expect(find.text('Inicio: 26/10'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
