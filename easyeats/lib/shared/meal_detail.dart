import 'dart:async';
import 'package:flutter/material.dart';
import '../core/controllers.dart';
import '../core/models.dart';
import '../core/repository.dart';
import 'widgets.dart';

Future<void> openMeal(
  BuildContext context,
  Meal meal,
  AppRepository repository, {
  bool operator = false,
  bool readOnly = false,
}) => showDetail<void>(
  context,
  MealDetail(
    meal: meal,
    repository: repository,
    operator: operator,
    readOnly: readOnly,
  ),
);

class MealDetail extends StatelessWidget {
  const MealDetail({
    super.key,
    required this.meal,
    required this.repository,
    this.operator = false,
    this.readOnly = false,
  });
  final Meal meal;
  final AppRepository repository;
  final bool operator, readOnly;
  @override
  Widget build(BuildContext context) => DetailLayout(
    title: meal.recipe.name,
    children: [
      Text(
        '${mealLabels[meal.slot]} · ${shortDate(meal.date)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      if (meal.needsAttention)
        const Notice(
          'Este plato necesita revisión por tus restricciones actuales. No se recomienda como comida compatible.',
          error: true,
          icon: Icons.warning_amber_outlined,
        ),
      ...recipeFields(context, meal.recipe),
      if (!readOnly && (operator || meal.canSwap))
        BusyButton(
          label: operator ? 'Corregir plato' : 'Elegir otro plato',
          icon: Icons.swap_horiz,
          onPressed: () async {
            final changed = await showDetail<bool>(
              context,
              CandidatePicker(
                meal: meal,
                repository: repository,
                operator: operator,
              ),
            );
            if (changed == true && context.mounted) Navigator.pop(context);
          },
        ),
      if (!readOnly && !operator && meal.canFeedback) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final saved = await showDetail<bool>(
              context,
              OpinionEditor(meal: meal, repository: repository),
            );
            if (saved == true && context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Valorar esta comida'),
        ),
      ],
      if (!operator && !meal.canSwap && !meal.canFeedback)
        const Text('Esta asignación todavía no admite cambios ni opiniones.'),
    ],
  );
}

class CandidatePicker extends StatefulWidget {
  const CandidatePicker({
    super.key,
    required this.meal,
    required this.repository,
    this.operator = false,
  });
  final Meal meal;
  final AppRepository repository;
  final bool operator;
  @override
  State<CandidatePicker> createState() => _CandidatePickerState();
}

class _CandidatePickerState extends State<CandidatePicker> {
  final _loader = LoadController<List<dynamic>>();
  late Meal _meal = widget.meal;
  String? _notice;
  Timer? _debounce;
  String _query = '';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _loader.load(
    () => widget.repository.list(
      '${widget.operator ? '/operator' : '/menus'}/items/${_meal.id}/candidates?limit=100&q=${Uri.encodeQueryComponent(_query)}',
    ),
  );
  @override
  void dispose() {
    _debounce?.cancel();
    _loader.dispose();
    super.dispose();
  }

  Future<void> _choose(Recipe recipe) async {
    if (!await confirm(
      context,
      'Confirmar cambio',
      '${_meal.recipe.name}\n↓\n${recipe.name}',
      label: 'Cambiar plato',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final body = {
        'expected_version': _meal.version,
        'recipe_code': recipe.code,
      };
      if (widget.operator) {
        await widget.repository.write(
          'PUT',
          '/operator/items/${_meal.id}',
          body,
        );
      } else {
        await widget.repository.operation(
          'PUT',
          '/menus/items/${_meal.id}/substitution',
          body,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (e is ApiException && (e.code == 'VERSION_CONFLICT' || e.uncertain)) {
        try {
          Json current;
          if (widget.operator) {
            final cycle = await widget.repository.get(
              '/operator/cycles/${_meal.data['cycle_id']}',
            );
            current = (cycle['items'] as List).cast<Json>().firstWhere(
              (x) => x['id'] == _meal.id,
            );
          } else {
            current = await widget.repository.get('/menus/items/${_meal.id}');
          }
          if (!mounted) return;
          setState(() {
            _meal = Meal.fromJson(current);
            _notice =
                'Se ha consultado la comida actual. Revisa las alternativas y confirma de nuevo el cambio.';
          });
          await _load();
        } catch (_) {
          if (mounted) {
            setState(
              () => _notice =
                  'No se pudo comprobar el cambio. Cierra el panel y actualiza la semana antes de repetir.',
            );
          }
        }
      }
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Platos compatibles',
                  style: TextStyle(fontSize: 22),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: TextField(
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Buscar una alternativa',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _query = value;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _load);
            },
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Notice(_notice!),
          ),
        Expanded(
          child: LoadView(
            controller: _loader,
            retry: _load,
            builder: (data, stale) {
              final choices = data
                  .map((x) => Recipe.fromJson(x as Json))
                  .where((r) => r.code != _meal.recipe.code)
                  .toList();
              if (choices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyCard(
                    title: 'Sin alternativas',
                    text:
                        'No hay otros platos compatibles con estos filtros. Tus restricciones se mantienen.',
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: choices.length,
                itemBuilder: (context, index) {
                  final r = choices[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const Icon(Icons.restaurant_outlined),
                      title: Text(r.name),
                      subtitle: Text(r.category),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: _busy || stale ? null : () => _choose(r),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class OpinionEditor extends StatefulWidget {
  const OpinionEditor({
    super.key,
    required this.meal,
    required this.repository,
    this.existing,
  });
  final Meal meal;
  final AppRepository repository;
  final Json? existing;
  @override
  State<OpinionEditor> createState() => _OpinionEditorState();
}

class _OpinionEditorState extends State<OpinionEditor> {
  final _comment = TextEditingController();
  int _version = 0, _rating = 1;
  bool _busy = true, _dirty = false, _failed = false, _saving = false;
  ApiException? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      Json? existing = widget.existing;
      for (var offset = 0; existing == null; offset += 100) {
        final rows = await widget.repository.list(
          '/feedback?limit=100&offset=$offset',
        );
        if (!mounted) return;
        for (final x in rows) {
          if ((x as Json)['item_id'] == widget.meal.id) existing = x;
        }
        if (rows.length < 100) break;
      }
      if (existing != null) {
        if (!mounted) return;
        _version = existing['version'] as int;
        _rating = existing['rating'] as int;
        _comment.text = existing['comment'] as String;
      }
    } catch (e) {
      _failed = true;
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.write(
        'PUT',
        '/menus/items/${widget.meal.id}/feedback',
        {
          'expected_version': _version,
          'rating': _rating,
          'comment': _comment.text,
        },
      );
      if (mounted) {
        setState(() => _dirty = false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted && e is ApiException) setState(() => _error = e);
      if (mounted) showError(context, e);
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _saving = false;
      });
    }
  }

  Future<void> _checkSaved() async {
    try {
      Json? saved;
      for (var offset = 0; saved == null; offset += 100) {
        final rows = await widget.repository.list(
          '/feedback?limit=100&offset=$offset',
        );
        if (!mounted) return;
        for (final row in rows.cast<Json>()) {
          if (row['item_id'] == widget.meal.id) saved = row;
        }
        if (rows.length < 100) break;
      }
      if (!mounted) return;
      final currentVersion = saved?['version'] as int? ?? 0;
      if (await confirm(
            context,
            'Comprobar opinión',
            'La opinión guardada tiene versión $currentVersion. Tus cambios se conservarán para que los revises antes de volver a guardar.',
            label: 'Conservar cambios',
          ) &&
          mounted) {
        setState(() {
          _version = currentVersion;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop &&
          !_saving &&
          await confirm(
            context,
            'Descartar opinión',
            'Hay cambios sin guardar.',
            label: 'Descartar',
          )) {
        if (context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      }
    },
    child: DetailLayout(
      title: '¿Qué te ha parecido?',
      children: [
        if (_error != null)
          Notice(
            _error!.message,
            error: true,
            action: TextButton(
              onPressed: _busy ? null : _checkSaved,
              child: const Text('Comprobar guardado y versión'),
            ),
          ),
        Text(
          widget.meal.recipe.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ChoiceChip(
              showCheckmark: false,
              label: const Text('Me ha gustado'),
              avatar: const Icon(Icons.thumb_up_outlined),
              selected: _rating == 1,
              onSelected: _busy || _failed
                  ? null
                  : (_) => setState(() {
                      _rating = 1;
                      _dirty = true;
                    }),
            ),
            ChoiceChip(
              showCheckmark: false,
              label: const Text('Prefiero otro'),
              avatar: const Icon(Icons.thumb_down_outlined),
              selected: _rating == -1,
              onSelected: _busy || _failed
                  ? null
                  : (_) => setState(() {
                      _rating = -1;
                      _dirty = true;
                    }),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _comment,
          enabled: !_busy && !_failed,
          maxLength: 500,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
          onChanged: (_) => setState(() => _dirty = true),
        ),
        const SizedBox(height: 16),
        const Notice(
          'Tu valoración orientará nuevas generaciones. El menú actual se conserva.',
        ),
        BusyButton(
          label: 'Guardar opinión',
          busy: _busy,
          onPressed: _failed ? null : _save,
          icon: Icons.check,
        ),
      ],
    ),
  );
}
