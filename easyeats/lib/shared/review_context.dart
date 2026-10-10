import 'package:flutter/material.dart';
import '../core/models.dart';

class ReviewContext extends StatelessWidget {
  const ReviewContext({super.key, required this.cycle});
  final Json cycle;

  @override
  Widget build(BuildContext context) {
    final profile = cycle['profile'] as Json;
    final labels = (cycle['profile_labels'] as Json?) ?? {};
    String names(String field, String fallback, String empty) {
      final choices = (labels[field] as List?) ?? [];
      return selectionText(profile[fallback] as List, choices, empty: empty);
    }

    Widget fact(String title, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(value),
      ],
    );
    final facts = [
      fact(
        'Alérgenos a excluir',
        names('allergens', 'allergen_codes', 'Ninguno declarado'),
      ),
      fact(
        'Ingredientes a excluir',
        names('excluded_ingredients', 'excluded_ingredient_codes', 'Ninguno'),
      ),
      fact(
        'Le gusta',
        names('liked_ingredients', 'liked_ingredient_codes', 'Sin favoritos'),
      ),
      fact(
        'Prefiere menos',
        names(
          'disliked_ingredients',
          'disliked_ingredient_codes',
          'Sin preferencias',
        ),
      ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.tune_outlined),
        title: const Text('Restricciones y preferencias'),
        subtitle: Text(
          'Dieta ${dietLabels[profile['diet']]!.toLowerCase()} · ${weeklyMealCount(profile)} comidas por semana',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 20) / columns;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (final item in facts) SizedBox(width: width, child: item),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(repetitionLabels[profile['repetition_tolerance']]!),
          ),
          if ((profile['preferred_categories'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Categorías: ${(profile['preferred_categories'] as List).join(', ')}',
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Calendario elegido',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8),
          for (final raw in profile['weekly_slots'] as List)
            if (((raw as Json)['meal_slots'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${weekdays[(raw['weekday'] as int) - 1]} · ${(raw['meal_slots'] as List).map((slot) => mealLabels[slot]).join(', ')}',
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
