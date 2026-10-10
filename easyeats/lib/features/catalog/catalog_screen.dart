import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../shared/widgets.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _controller = LoadController<ApiResult>();
  Timer? _debounce;
  String _query = '', _meal = '', _diet = '';
  bool _compatible = false;
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _controller.load(
    () => widget.repository.api.request(
      'GET',
      '/catalog/recipes?limit=24&offset=$_offset&q=${Uri.encodeQueryComponent(_query)}&meal_slot=$_meal&diet=$_diet&compatible_only=$_compatible',
    ),
  );
  void _filter() {
    _offset = 0;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoadView(
    controller: _controller,
    retry: _load,
    builder: (result, stale) {
      final recipes = (result.data as List)
          .map((x) => Recipe.fromJson(x as Json))
          .toList();
      final total = result.meta['total'] as int;
      return PageFrame(
        title: 'Ideas para tu mesa.',
        subtitle: 'Explora el catálogo · $total platos con estos filtros',
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar plato o ingrediente',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _query = value;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _filter);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _meal,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Momento'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todos')),
                    ...mealLabels.entries.map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) {
                    _meal = v!;
                    _filter();
                  },
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _diet,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Dieta'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Todas')),
                    DropdownMenuItem(
                      value: 'vegetarian',
                      child: Text('Vegetariana'),
                    ),
                    DropdownMenuItem(value: 'vegan', child: Text('Vegana')),
                  ],
                  onChanged: (v) {
                    _diet = v!;
                    _filter();
                  },
                ),
              ),
              FilterChip(
                label: const Text('Solo compatibles'),
                selected: _compatible,
                onSelected: (v) {
                  _compatible = v;
                  _filter();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (recipes.isEmpty)
            const EmptyCard(
              title: 'No encontramos platos',
              text: 'Prueba otra búsqueda o cambia los filtros.',
            ),
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
                children: recipes
                    .map(
                      (r) => SizedBox(
                        width: width,
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => showDetail(
                              context,
                              DetailLayout(
                                title: r.name,
                                children: recipeFields(context, r),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.restaurant_outlined,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    r.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    r.ingredients
                                        .map((i) => (i as Json)['name'])
                                        .take(4)
                                        .join(' · '),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Tag(r.category),
                                      if (r.compatible != null)
                                        Tag(
                                          r.compatible!
                                              ? 'Compatible'
                                              : 'Revisar',
                                          icon: r.compatible!
                                              ? Icons.check_circle_outline
                                              : Icons.warning_amber_outlined,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _offset == 0 || _controller.loading
                    ? null
                    : () {
                        _offset -= 24;
                        _load();
                      },
                child: const Text('Anterior'),
              ),
              Text('Página ${_offset ~/ 24 + 1}'),
              OutlinedButton(
                onPressed: _offset + 24 >= total || _controller.loading
                    ? null
                    : () {
                        _offset += 24;
                        _load();
                      },
                child: const Text('Siguiente'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Notice('Datos de demostración sin verificación alimentaria.'),
        ],
      );
    },
  );
}
