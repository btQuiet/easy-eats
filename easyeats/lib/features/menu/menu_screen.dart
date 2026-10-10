import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../catalog/catalog_screen.dart';

class MenuScreen extends StatefulWidget {
  final AppController controller;
  const MenuScreen({super.key, required this.controller});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  static const dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  late DateTime monday = _monday(DateTime.now());
  Map<String, dynamic>? week;
  Map<String, dynamic>? monthStatus;
  bool loading = true;
  bool generating = false;
  String? error;

  static DateTime _monday(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
  ).subtract(Duration(days: value.weekday - 1));

  String dayString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String get monthString {
    final focus = monday.add(const Duration(days: 3));
    return '${focus.year.toString().padLeft(4, '0')}-${focus.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = widget.controller.api;
      final responses = await Future.wait([
        api.get('/menus/week', query: {'day': dayString(monday)}),
        api.get('/menus/status', query: {'month': monthString}),
      ]);
      if (mounted) {
        setState(() {
          week = Map<String, dynamic>.from(responses[0]);
          monthStatus = Map<String, dynamic>.from(responses[1]);
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> generate() async {
    setState(() => generating = true);
    try {
      final result = await widget.controller.api.post('/menus/generate', {
        'month': monthString,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['status'] == 'pending_review'
                  ? 'Menú creado. El operario revisará esta primera propuesta.'
                  : 'Nuevo mes listo.',
            ),
          ),
        );
      }
      await load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> swap(Map<String, dynamic> item) async {
    try {
      final chosen = await pickRecipe(
        context,
        widget.controller.api,
        item['slot'].toString(),
        profile: widget.controller.profile,
      );
      if (chosen == null) return;
      await widget.controller.api.post('/menus/items/${item['id']}/swap', {
        'recipe_code': chosen['code'],
        'expected_version': item['version'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plato cambiado. No requiere revisión del operario.'),
          ),
        );
      }
      await load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    }
  }

  Future<void> feedback(Map<String, dynamic> item) async {
    int rating = 1;
    final comment = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('¿Qué te pareció ${item['recipe']['name']}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.thumb_up_alt_outlined),
                    label: Text('Me gusta'),
                  ),
                  ButtonSegment(
                    value: -1,
                    icon: Icon(Icons.thumb_down_alt_outlined),
                    label: Text('Menos de esto'),
                  ),
                ],
                selected: {rating},
                onSelectionChanged: (values) =>
                    update(() => rating = values.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comentario opcional',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'rating': rating,
                'comment': comment.text,
              }),
              child: const Text('Guardar opinión'),
            ),
          ],
        ),
      ),
    );
    comment.dispose();
    if (result == null) return;
    try {
      await widget.controller.api.post('/feedback', {
        'item_id': item['id'],
        ...result,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opinión guardada para futuras propuestas.'),
          ),
        );
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    }
  }

  Widget itemCard(Map<String, dynamic> item) {
    final recipe = Map<String, dynamic>.from(item['recipe'] ?? {});
    final attention = item['needs_user_attention'] == true;
    final today = dayString(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['slot'].toString().toUpperCase(),
              style: const TextStyle(
                color: EatsColors.forest,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              recipe['name']?.toString() ?? item['recipe_code'].toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              (recipe['ingredients'] as List? ?? [])
                  .map((value) => value['name'])
                  .join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (attention) ...[
              const SizedBox(height: 8),
              Text(
                'Revisa este plato: cambiaste una restricción de tu perfil.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showRecipeDetails(context, recipe),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Detalle'),
                ),
                if (item['can_swap'] == true)
                  OutlinedButton.icon(
                    onPressed: () => swap(item),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Cambiar'),
                  ),
                if (item['day'].toString().compareTo(today) <= 0)
                  TextButton.icon(
                    onPressed: () => feedback(item),
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('Opinar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(
      (week?['items'] as List? ?? []).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );
    final current = _monday(DateTime.now());
    final canGenerate = widget.controller.capabilities?['can_generate'] == true;
    final hasCycle =
        monthStatus?['status'] != null &&
        monthStatus!['status'] != 'not_generated';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Mi semana',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                monday == current
                    ? 'Esta semana'
                    : monday.isAfter(current)
                    ? 'Próxima semana o futuro'
                    : 'Semana anterior',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Semana anterior',
                    onPressed: () {
                      setState(
                        () => monday = monday.subtract(const Duration(days: 7)),
                      );
                      load();
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${dayString(monday)}  —  ${dayString(monday.add(const Duration(days: 6)))}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Semana siguiente',
                    onPressed: () {
                      setState(
                        () => monday = monday.add(const Duration(days: 7)),
                      );
                      load();
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                color: EatsColors.sage,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    week?['origin'] == 'ai'
                        ? 'Planificación generada con IA · platos del catálogo de prueba.'
                        : 'Planificación de pruebas · generada sin IA.',
                  ),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(error!),
                  ),
                )
              else if (week?['status'] == 'pending_review')
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Tu primera propuesta mensual está pendiente de revisión del operario.',
                    ),
                  ),
                )
              else if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aún no hay platos para esta semana. Puedes generar el mes correspondiente.',
                    ),
                  ),
                ),
              if (!loading &&
                  !hasCycle &&
                  monday
                      .add(const Duration(days: 6))
                      .isAfter(
                        DateTime.now().subtract(const Duration(days: 1)),
                      ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: ElevatedButton.icon(
                    onPressed: canGenerate && !generating ? generate : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      generating
                          ? 'Preparando el mes...'
                          : canGenerate
                          ? 'Generar menú de $monthString'
                          : 'Modo IA sin clave configurada',
                    ),
                  ),
                ),
              for (var index = 0; index < 7; index++) ...[
                if (items.any(
                  (item) =>
                      item['day'] ==
                      dayString(monday.add(Duration(days: index))),
                )) ...[
                  const SizedBox(height: 18),
                  Text(
                    '${dayNames[index]} · ${dayString(monday.add(Duration(days: index)))}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  for (final item in items.where(
                    (item) =>
                        item['day'] ==
                        dayString(monday.add(Duration(days: index))),
                  ))
                    itemCard(item),
                ],
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
