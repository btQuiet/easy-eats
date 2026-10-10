import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../shared/meal_detail.dart';
import '../../shared/review_context.dart';
import '../../shared/widgets.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen>
    with WidgetsBindingObserver {
  final _queue = LoadController<ApiResult>(), _detail = LoadController<Json>();
  String? _selected;
  int _offset = 0;
  bool _busy = false;
  Timer? _timer;
  Timer? _searchTimer;
  final _search = TextEditingController();
  String _query = '';
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final latest = _detail.data?['latest_generation'] as Json?;
      if (_foreground &&
          !_busy &&
          !_queue.loading &&
          !_detail.loading &&
          (_selected == null ||
              ['queued', 'running'].contains(latest?['state']))) {
        _load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground &&
        !wasForeground &&
        !_busy &&
        !_queue.loading &&
        !_detail.loading) {
      _load();
    }
  }

  Future<void> _load() async {
    await _queue.load(
      () => widget.repository.api.request(
        'GET',
        '/operator/reviews?limit=25&offset=$_offset&q=${Uri.encodeQueryComponent(_query)}',
      ),
    );
    if (!mounted) return;
    if (_queue.error == null &&
        _selected != null &&
        !(_queue.data!.data as List).any(
          (x) => (x as Json)['id'] == _selected,
        )) {
      setState(() {
        _selected = null;
        _detail.data = null;
      });
    }
    if (_selected != null) await _loadDetail();
  }

  Future<void> _loadDetail() =>
      _detail.load(() => widget.repository.get('/operator/cycles/$_selected'));
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _searchTimer?.cancel();
    _search.dispose();
    _queue.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _action(Json cycle, bool regenerate) async {
    final confirmed = await confirm(
      context,
      regenerate ? 'Regenerar propuesta' : 'Aprobar primer menú',
      regenerate
          ? 'La nueva propuesta reemplazará las correcciones actuales cuando sea válida.'
          : 'Se publicarán las comidas futuras compatibles. Las fechas de hoy y anteriores quedarán canceladas.',
      label: regenerate ? 'Regenerar' : 'Aprobar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.operation(
        'POST',
        '/operator/cycles/${cycle['id']}/${regenerate ? 'regenerate' : 'approve'}',
        {'expected_version': cycle['version']},
      );
      if (!regenerate && mounted) setState(() => _selected = null);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
      if (mounted &&
          e is ApiException &&
          [
            'VERSION_CONFLICT',
            'INPUT_CHANGED',
            'ITEM_NOT_EDITABLE',
            'CYCLE_EXPIRED',
          ].contains(e.code)) {
        await _load();
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _queueView() => LoadView(
    controller: _queue,
    retry: _load,
    builder: (result, stale) {
      final rows = (result.data as List).cast<Json>();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Primeras revisiones',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${result.meta['total']} ${result.meta['total'] == 1 ? 'propuesta' : 'propuestas'}',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            enabled: !_busy,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Buscar cliente',
              prefixIcon: Icon(Icons.search),
              counterText: '',
            ),
            onChanged: (value) {
              _searchTimer?.cancel();
              _searchTimer = Timer(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                _query = value.trim();
                _offset = 0;
                _load();
              });
            },
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            EmptyCard(
              title: _query.isEmpty ? 'Todo al día' : 'Sin coincidencias',
              text: _query.isEmpty
                  ? 'Las nuevas propuestas aparecerán aquí después de generarse.'
                  : 'Prueba con otro alias o borra la búsqueda.',
              icon: Icons.task_alt,
            ),
          ...rows.map(
            (c) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: _selected == c['id']
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text((c['user'] as Json)['alias'] as String),
                subtitle: Text(
                  '${monthLabel(c['month'] as String)}\n${c['status'] == 'draft' ? 'Preparando propuesta' : 'Pendiente de revisión'}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: stale
                    ? null
                    : () {
                        setState(() {
                          _selected = c['id'] as String;
                          _detail.data = null;
                        });
                        _loadDetail();
                      },
              ),
            ),
          ),
          if (_offset > 0)
            OutlinedButton(
              onPressed: () {
                _offset -= 25;
                _load();
              },
              child: const Text('Anterior'),
            ),
          if (_offset + 25 < (result.meta['total'] as int))
            OutlinedButton(
              onPressed: () {
                _offset += 25;
                _load();
              },
              child: const Text('Siguiente'),
            ),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ],
      );
    },
  );
  Widget _detailView(bool compact) {
    if (_selected == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: EmptyCard(
            title: 'Una buena semana empieza aquí.',
            text:
                'Selecciona una primera propuesta para revisar calendario, restricciones y platos.',
            icon: Icons.verified_outlined,
          ),
        ),
      );
    }
    return LoadView(
      controller: _detail,
      retry: _loadDetail,
      builder: (cycle, stale) {
        final p = cycle['profile'] as Json;
        final latest = cycle['latest_generation'] as Json?;
        final active = ['queued', 'running'].contains(latest?['state']);
        final summary = cycle['review_summary'] as Json?;
        final allergenCount = (p['allergen_codes'] as List).length;
        final excludedCount = (p['excluded_ingredient_codes'] as List).length;
        final groups = <String, List<Meal>>{};
        for (final raw in cycle['items'] as List) {
          final item = Meal.fromJson(raw as Json);
          if (item.data['cancelled'] == true) continue;
          groups.putIfAbsent(item.date, () => []).add(item);
        }
        return PageFrame(
          title: (cycle['user'] as Json)['alias'] as String,
          subtitle:
              'Primera propuesta · ${monthLabel(cycle['month'] as String)}',
          actions: [
            if (compact)
              OutlinedButton.icon(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Cola'),
              ),
            OutlinedButton.icon(
              onPressed: _busy || stale || active
                  ? null
                  : () => _action(cycle, true),
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerar'),
            ),
            BusyButton(
              label: 'Aprobar menú',
              icon: Icons.check,
              busy: _busy,
              onPressed:
                  stale ||
                      active ||
                      cycle['status'] != 'pending_review' ||
                      cycle['requires_refresh'] == true ||
                      (summary != null && summary['can_approve'] != true)
                  ? null
                  : () => _action(cycle, false),
            ),
          ],
          children: [
            if (summary?['can_approve'] == true)
              Notice(
                '${summary!['future_item_count']} comidas futuras listas para publicar. Primera fecha: ${shortDate(summary['first_future_date'] as String)}.${summary['elapsed_item_count'] == 0 ? '' : ' ${summary['elapsed_item_count']} comidas de hoy o anteriores quedarán canceladas.'}',
                icon: Icons.fact_check_outlined,
              ),
            if (summary != null &&
                summary['can_approve'] != true &&
                !active &&
                cycle['requires_refresh'] != true &&
                (summary['blocking_reasons'] as List).isNotEmpty)
              Notice(
                ((summary['blocking_reasons'] as List).first as Json)['message']
                    as String,
                error: true,
              ),
            if (active)
              const Notice(
                'Generación en curso. Conservamos la propuesta anterior hasta validar la nueva.',
                icon: Icons.hourglass_top,
              ),
            if (latest?['error'] != null)
              Notice(
                (latest!['error'] as Json)['message'] as String,
                error: true,
              ),
            if (cycle['requires_refresh'] == true)
              const Notice(
                'El perfil cambió desde esta generación. Regenera antes de aprobar.',
                error: true,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(
                  'Dieta: ${{'omnivore': 'omnívora', 'vegetarian': 'vegetariana', 'vegan': 'vegana'}[p['diet']]}',
                ),
                Tag(
                  '$allergenCount ${allergenCount == 1 ? 'alérgeno excluido' : 'alérgenos excluidos'}',
                ),
                Tag(
                  '$excludedCount ${excludedCount == 1 ? 'ingrediente excluido' : 'ingredientes excluidos'}',
                ),
                Tag('Origen: ${cycle['generation_origin'] ?? 'pendiente'}'),
              ],
            ),
            if ((cycle['warnings'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Notice(
                  'Variedad ajustada en ${(cycle['warnings'] as List).length} comidas por las opciones disponibles.',
                ),
              ),
            const SizedBox(height: 24),
            ReviewContext(cycle: cycle),
            const SizedBox(height: 24),
            if (groups.isEmpty)
              const EmptyCard(
                title: 'Esperando una propuesta válida',
                text: 'Una generación fallida no publica platos incompletos.',
              ),
            ...groups.entries.map(
              (entry) => Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weekdays[DateTime.parse(entry.key).weekday - 1]} · ${shortDate(entry.key)}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ...entry.value.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            item.needsAttention
                                ? Icons.warning_amber_outlined
                                : Icons.restaurant_outlined,
                          ),
                          title: Text(item.recipe.name),
                          subtitle: Text(mealLabels[item.slot]!),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: stale || active || _busy
                              ? null
                              : () async {
                                  await openMeal(
                                    context,
                                    item,
                                    widget.repository,
                                    operator: true,
                                  );
                                  if (mounted) _loadDetail();
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (MediaQuery.sizeOf(context).width >= 1024) {
        return Row(
          children: [
            SizedBox(width: 320, child: _queueView()),
            const VerticalDivider(width: 1),
            Expanded(child: _detailView(false)),
          ],
        );
      }
      return _selected == null ? _queueView() : _detailView(true);
    },
  );
}
