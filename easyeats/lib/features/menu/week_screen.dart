import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../shared/meal_detail.dart';
import '../../shared/widgets.dart';

class WeekController extends LoadController<Json> {
  WeekController(this.repository, DateTime start) : start = mondayOf(start);
  final AppRepository repository;
  DateTime start;
  final Set<String> attempts = {};
  ApiException? generationError;
  bool ensureBusy = false;
  Future<void> refresh({bool ensure = false}) => load(() async {
    if (ensure) {
      ensureBusy = true;
      generationError = null;
      try {
        final p = await repository.get('/profile');
        final today = calendarDate(DateTime.parse(repository.api.serverToday!));
        final current = dateKey(today).substring(0, 7);
        final next = dateKey(
          DateTime.utc(today.year, today.month + 1),
        ).substring(0, 7);
        final first = (p['service_start_date'] as String).substring(0, 7);
        final months = {
          dateKey(start).substring(0, 7),
          dateKey(addCalendarDays(start, 6)).substring(0, 7),
        };
        if (p['initial_review_completed'] != true) months.add(first);
        if (DateTime.utc(
              today.year,
              today.month + 1,
              0,
            ).difference(today).inDays <
            7) {
          months.add(next);
        }
        for (final month in months.toList()..sort()) {
          if ((month != current && month != next) ||
              month.compareTo(first) < 0) {
            continue;
          }
          try {
            final result = await repository.operation('POST', '/menus/ensure', {
              'month': month,
            });
            if (result.status == 202) {
              attempts.add((result.data as Json)['id'] as String);
            }
          } on ApiException catch (e) {
            if (e.code == 'CYCLE_EXPIRED' &&
                e.details['suggested_month'] == next) {
              try {
                final result = await repository.operation(
                  'POST',
                  '/menus/ensure',
                  {'month': next},
                );
                if (result.status == 202) {
                  attempts.add((result.data as Json)['id'] as String);
                }
              } on ApiException catch (replacement) {
                generationError = replacement;
              }
            }
            if (!['INITIAL_REVIEW_PENDING', 'CYCLE_EXPIRED'].contains(e.code)) {
              generationError = e;
            }
          }
        }
      } finally {
        ensureBusy = false;
      }
    }
    final week = await repository.get('/menus/week?start=${dateKey(start)}');
    attempts.addAll((week['pending_generation_ids'] as List).cast<String>());
    for (final id in attempts.toList()) {
      final a = await repository.get('/menus/generations/$id');
      if (!['queued', 'running'].contains(a['state'])) {
        attempts.remove(id);
        if (a['error'] != null) {
          final error = a['error'] as Json;
          generationError = ApiException(
            error['code'] as String,
            error['message'] as String,
            details: error['details'] as Json,
          );
        }
      }
    }
    return week;
  });
}

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> with WidgetsBindingObserver {
  late final WeekController _controller;
  Timer? _timer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    final today = DateTime.parse(widget.repository.api.serverToday!);
    _controller = WeekController(widget.repository, today);
    _controller.refresh(ensure: true);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_foreground &&
          !_controller.loading &&
          (_controller.attempts.isNotEmpty ||
              _controller.data?['pending_initial_review'] == true)) {
        _controller.refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && !wasForeground && !_controller.loading) {
      _controller.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _move(int days) {
    _controller.start = addCalendarDays(_controller.start, days);
    _controller.refresh(ensure: true);
  }

  Future<void> _open(Meal meal, bool stale) async {
    await openMeal(context, meal, widget.repository, readOnly: stale);
    if (mounted) _controller.refresh();
  }

  @override
  Widget build(BuildContext context) => LoadView(
    controller: _controller,
    retry: () => _controller.refresh(ensure: true),
    builder: (week, stale) {
      final days = (week['days'] as List).cast<Json>();
      final summary = week['summary'] as Json?;
      final count =
          summary?['published_item_count'] as int? ??
          days.fold<int>(0, (n, d) => n + (d['items'] as List).length);
      final today = widget.repository.api.serverToday!;
      final upcoming = days
          .expand((day) => day['items'] as List)
          .map((raw) => Meal.fromJson(raw as Json))
          .where((meal) => meal.date.compareTo(today) >= 0)
          .toList();
      final attention = upcoming.where((meal) => meal.needsAttention).toList();
      final next = upcoming.isEmpty
          ? null
          : upcoming.firstWhere(
              (meal) => meal.id == summary?['next_item_id'],
              orElse: () => upcoming.first,
            );
      return PageFrame(
        title: 'Tu semana, resuelta.',
        subtitle:
            '${shortDate(week['start'] as String)} — ${shortDate(week['end'] as String)}',
        actions: [
          IconButton(
            onPressed: _controller.loading ? null : () => _move(-7),
            tooltip: 'Semana anterior',
            icon: const Icon(Icons.chevron_left),
          ),
          OutlinedButton(
            onPressed: _controller.loading
                ? null
                : () {
                    final today = DateTime.parse(
                      widget.repository.api.serverToday!,
                    );
                    _controller.start = mondayOf(today);
                    _controller.refresh(ensure: true);
                  },
            child: const Text('Esta semana'),
          ),
          IconButton(
            onPressed: _controller.loading ? null : () => _move(7),
            tooltip: 'Próxima semana',
            icon: const Icon(Icons.chevron_right),
          ),
        ],
        children: [
          if (_controller.generationError != null)
            Notice(
              _controller.generationError!.message,
              error: true,
              action: TextButton(
                onPressed: stale
                    ? null
                    : () => _controller.refresh(ensure: true),
                child: const Text('Volver a generar'),
              ),
            ),
          if (_controller.attempts.isNotEmpty)
            const Notice(
              'Estamos preparando tu menú. Puedes salir de esta pantalla; la generación continuará.',
              icon: Icons.hourglass_top,
            ),
          if (week['pending_initial_review'] == true)
            const Notice(
              'Tu primer menú necesita la revisión del operario. Los platos aparecerán aquí cuando se apruebe.',
              icon: Icons.verified_outlined,
            ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Tag(
                '$count ${count == 1 ? 'comida publicada' : 'comidas publicadas'}',
                icon: Icons.restaurant_outlined,
              ),
              const Tag(
                'Puedes cambiar comidas futuras',
                icon: Icons.swap_horiz,
              ),
              Tag(
                widget.repository.api.generationMode == 'ai'
                    ? 'Generación IA'
                    : 'Generación de pruebas',
                icon: Icons.auto_awesome_outlined,
              ),
              if (week['can_view_delivery'] == true)
                ActionChip(
                  label: const Text('Ver entrega simulada'),
                  avatar: const Icon(Icons.local_shipping_outlined),
                  onPressed: () => context.go('/deliveries'),
                ),
            ],
          ),
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 16),
            Notice(
              '${attention.length} ${attention.length == 1 ? 'comida necesita' : 'comidas necesitan'} revisar las restricciones. Consulta el detalle antes de elegir otro plato.',
              error: true,
              action: TextButton(
                onPressed: () => _open(attention.first, stale),
                child: const Text('Ver comida pendiente'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (next != null) ...[
            _spotlight(next, stale),
            const SizedBox(height: 24),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 880
                  ? 3
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: days
                    .map(
                      (day) =>
                          SizedBox(width: width, child: _day(day, week, stale)),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const Notice(
            'Menús basados en un catálogo de demostración. Las etiquetas no certifican seguridad alimentaria.',
          ),
        ],
      );
    },
  );

  Widget _spotlight(Meal meal, bool stale) {
    final colors = Theme.of(context).colorScheme;
    final today = meal.date == widget.repository.api.serverToday;
    return Card(
      key: const ValueKey('week-spotlight'),
      color: meal.needsAttention
          ? colors.errorContainer
          : colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  meal.needsAttention
                      ? Icons.warning_amber_outlined
                      : Icons.restaurant_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meal.needsAttention
                        ? 'Una comida para revisar'
                        : today
                        ? 'Hoy en tu menú'
                        : 'Próxima comida de esta semana',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              meal.recipe.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${weekdays[DateTime.parse(meal.date).weekday - 1]} ${shortDate(meal.date)} · ${mealLabels[meal.slot]}',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _open(meal, stale),
              icon: Icon(meal.canSwap ? Icons.swap_horiz : Icons.arrow_forward),
              label: Text(
                meal.canSwap && !stale ? 'Ver y cambiar plato' : 'Ver plato',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _day(Json day, Json week, bool stale) {
    final date = DateTime.parse(day['date'] as String);
    final meals = (day['items'] as List)
        .map((x) => Meal.fromJson(x as Json))
        .toList();
    final scheduled = day['scheduled_slots'] as List;
    final segment = (week['cycle_segments'] as List).cast<Json>().firstWhere(
      (x) => x['month'] == dateKey(date).substring(0, 7),
    );
    final isToday = day['date'] == widget.repository.api.serverToday;
    return Card(
      shape: isToday
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    weekdays[date.weekday - 1],
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  shortDate(dateKey(date)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isToday) ...[
              const Tag('Hoy', icon: Icons.today_outlined),
              const SizedBox(height: 12),
            ],
            if (meals.isEmpty)
              Text(
                scheduled.isEmpty
                    ? 'Un día a tu manera. Sin comidas elegidas.'
                    : segment['status'] == 'pending_review'
                    ? 'Pendiente de revisión.'
                    : segment['status'] == 'expired'
                    ? 'La propuesta de este mes ha vencido.'
                    : segment['status'] == 'approved'
                    ? 'Sin comidas disponibles en esta fecha.'
                    : 'Este tramo todavía no tiene menú publicado.',
              ),
            ...meals.map(
              (meal) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _open(meal, stale),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              meal.needsAttention
                                  ? Icons.warning_amber_outlined
                                  : Icons.restaurant_outlined,
                              size: 18,
                              color: meal.needsAttention
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mealLabels[meal.slot]!,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            if (meal.canSwap)
                              const Icon(Icons.swap_horiz, size: 18),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          meal.recipe.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (meal.needsAttention)
                          Text(
                            'Revisar restricciones',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
