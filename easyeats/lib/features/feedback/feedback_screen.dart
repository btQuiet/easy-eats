import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../shared/meal_detail.dart';
import '../../shared/widgets.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = LoadController<Json>();
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _controller.load(() async {
    final result = await widget.repository.api.request(
      'GET',
      '/feedback?limit=25&offset=$_offset',
    );
    final today = DateTime.parse(widget.repository.api.serverToday!);
    final monday = mondayOf(today);
    final weeks = [
      await widget.repository.get('/menus/week?start=${dateKey(monday)}'),
      await widget.repository.get(
        '/menus/week?start=${dateKey(addCalendarDays(monday, -7))}',
      ),
    ];
    final meals = <Meal>[];
    for (final week in weeks) {
      for (final day in week['days'] as List) {
        for (final item in (day as Json)['items'] as List) {
          final meal = Meal.fromJson(item as Json);
          if (meal.canFeedback) meals.add(meal);
        }
      }
    }
    return {
      'feedback': result.data,
      'total': result.meta['total'],
      'meals': meals,
    };
  });
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit(Meal meal, {Json? existing}) async {
    await showDetail(
      context,
      OpinionEditor(
        meal: meal,
        repository: widget.repository,
        existing: existing,
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => LoadView(
    controller: _controller,
    retry: _load,
    builder: (data, stale) {
      final feedback = (data['feedback'] as List).cast<Json>();
      final meals = (data['meals'] as List).cast<Meal>();
      return PageFrame(
        title: 'Tu opinión cuenta.',
        subtitle: 'Lo que te gusta ayuda a preparar próximos menús.',
        children: [
          if (meals.isEmpty)
            const EmptyCard(
              title: 'Tus primeras opiniones llegarán después',
              text:
                  'Podrás valorar las comidas aprobadas cuando llegue su fecha.',
            ),
          if (meals.isNotEmpty) ...[
            Text(
              'Comidas recientes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...meals.map(
              (meal) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.restaurant_outlined),
                  title: Text(meal.recipe.name),
                  subtitle: Text(
                    '${shortDate(meal.date)} · ${mealLabels[meal.slot]}',
                  ),
                  trailing: const Icon(Icons.rate_review_outlined),
                  onTap: stale ? null : () => _edit(meal),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Opiniones guardadas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (feedback.isEmpty)
            const EmptyCard(
              title: 'Todavía sin valoraciones',
              text:
                  'Puedes dejar una valoración positiva o negativa y un comentario opcional.',
            ),
          ...feedback.map(
            (f) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  f['rating'] == 1
                      ? Icons.thumb_up_outlined
                      : Icons.thumb_down_outlined,
                ),
                title: Text(
                  f['recipe_name'] as String? ?? f['recipe_code'] as String,
                ),
                subtitle: Text(
                  (f['comment'] as String).isEmpty
                      ? 'Sin comentario'
                      : f['comment'] as String,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: stale
                    ? null
                    : () async {
                        try {
                          final item = await widget.repository.get(
                            '/menus/items/${f['item_id']}',
                          );
                          if (mounted) {
                            await _edit(Meal.fromJson(item), existing: f);
                          }
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_offset > 0)
                OutlinedButton(
                  onPressed: () {
                    _offset -= 25;
                    _load();
                  },
                  child: const Text('Anterior'),
                ),
              if (_offset + 25 < (data['total'] as int))
                OutlinedButton(
                  onPressed: () {
                    _offset += 25;
                    _load();
                  },
                  child: const Text('Siguiente'),
                ),
              TextButton(
                onPressed: () => context.go('/week'),
                child: const Text('Buscar otra semana'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
