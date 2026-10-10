import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../core/api.dart';

typedef Recipe = Map<String, dynamic>;

String recipeWarnings(Recipe recipe, Map<String, dynamic>? profile) {
  if (profile == null) return '';
  final warnings = <String>[];
  final restrictedAllergens = Set<String>.from(profile['allergens'] ?? []);
  final excluded = Set<String>.from(profile['excluded_ingredients'] ?? []);
  final recipeAllergens = <String>{
    for (final item in recipe['allergens'] ?? []) item['code'].toString(),
  };
  final recipeIngredients = <String>{
    for (final item in recipe['ingredients'] ?? []) item['code'].toString(),
  };
  if (restrictedAllergens.intersection(recipeAllergens).isNotEmpty) {
    warnings.add('contiene un alérgeno registrado');
  }
  if (excluded.intersection(recipeIngredients).isNotEmpty) {
    warnings.add('contiene un ingrediente excluido');
  }
  if (profile['diet'] == 'vegan' && recipe['is_vegan'] != true) {
    warnings.add('no es vegano según el catálogo');
  }
  if (profile['diet'] == 'vegetarian' && recipe['is_vegetarian'] != true) {
    warnings.add('no es vegetariano según el catálogo');
  }
  return warnings.join(' · ');
}

Future<void> showRecipeDetails(
  BuildContext context,
  Recipe recipe,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(recipe['name'].toString()),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 470),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${recipe['category']} · ${recipe['cuisine']}'),
            const SizedBox(height: 14),
            const Text(
              'Ingredientes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              (recipe['ingredients'] as List)
                  .map((item) => item['name'])
                  .join(', '),
            ),
            const SizedBox(height: 14),
            const Text(
              'Alérgenos modelados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              (recipe['allergens'] as List).isEmpty
                  ? 'No se han registrado en este concepto de plato.'
                  : (recipe['allergens'] as List)
                        .map((item) => item['name'])
                        .join(', '),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ficha demostrativa: ingredientes, trazas y elaboración reales no verificados.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  ),
);

Future<Recipe?> pickRecipe(
  BuildContext context,
  ApiClient api,
  String slot, {
  Map<String, dynamic>? profile,
}) async {
  final list = List<Recipe>.from(
    (await api.get(
      '/catalog/recipes',
      query: {'slot': slot},
    )).map((item) => Recipe.from(item)),
  );
  if (!context.mounted) return null;
  String query = '';
  return showDialog<Recipe>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, update) {
        final filtered = list
            .where(
              (recipe) => recipe['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Elige otro plato · $slot',
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tú decides la sustitución. Revisa sus ingredientes antes de confirmar.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar plato',
                    ),
                    onChanged: (value) => update(() => query = value),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final recipe = filtered[index];
                        final warning = recipeWarnings(recipe, profile);
                        return Card(
                          child: ListTile(
                            title: Text(recipe['name'].toString()),
                            subtitle: Text(
                              warning.isEmpty
                                  ? '${recipe['category']} · ${(recipe['allergens'] as List).length} alérgenos modelados'
                                  : warning,
                              maxLines: 2,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: dialogContext,
                                builder: (context) => AlertDialog(
                                  title: Text(recipe['name'].toString()),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Ingredientes: ${(recipe['ingredients'] as List).map((i) => i['name']).join(', ')}',
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Alérgenos modelados: ${(recipe['allergens'] as List).isEmpty ? 'ninguno registrado' : (recipe['allergens'] as List).map((i) => i['name']).join(', ')}',
                                        ),
                                        if (warning.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Atención: $warning',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Datos no verificados. Confirma solo tras revisar si el plato te conviene.',
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Elegir plato'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && dialogContext.mounted) {
                                Navigator.pop(dialogContext, recipe);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class CatalogScreen extends StatefulWidget {
  final AppController controller;
  const CatalogScreen({super.key, required this.controller});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Recipe> recipes = [];
  bool loading = true;
  String? error;
  String search = '';
  String slot = 'Todos';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await widget.controller.api.get('/catalog/recipes');
      if (mounted) {
        setState(() {
          recipes = List<Recipe>.from(
            response.map((item) => Recipe.from(item)),
          );
          loading = false;
          error = null;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.toString();
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = recipes
        .where(
          (recipe) =>
              (slot == 'Todos' || (recipe['slots'] as List).contains(slot)) &&
              recipe['name'].toString().toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explora los platos',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '125 ideas de plato. Sus ingredientes y alérgenos son datos de demostración.',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nombre',
                ),
                onChanged: (value) => setState(() => search = value),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final choice in const [
                      'Todos',
                      'desayuno',
                      'comida',
                      'cena',
                      'merienda',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(choice),
                          selected: slot == choice,
                          onSelected: (_) => setState(() => slot = choice),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                Expanded(child: Center(child: Text(error!)))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final recipe = filtered[index];
                      return Card(
                        child: ListTile(
                          title: Text(recipe['name'].toString()),
                          subtitle: Text(
                            '${recipe['category']} · ${recipe['cuisine']}',
                          ),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => showRecipeDetails(context, recipe),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
