import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';

Json defaultConfiguration() => {
  'plan': 'free',
  'diet': 'omnivore',
  'allergen_codes': <String>[],
  'excluded_ingredient_codes': <String>[],
  'liked_ingredient_codes': <String>[],
  'disliked_ingredient_codes': <String>[],
  'preferred_categories': <String>[],
  'repetition_tolerance': 'normal',
  'weekly_slots': List.generate(
    7,
    (i) => {
      'weekday': i + 1,
      'meal_slots': ['comida', 'cena'],
    },
  ),
};

class ConfigurationFields extends StatelessWidget {
  const ConfigurationFields({
    super.key,
    required this.step,
    required this.fields,
    required this.options,
    required this.onChanged,
    required this.today,
    this.enabled = true,
  });
  final String step, today;
  final Json fields, options;
  final VoidCallback onChanged;
  final bool enabled;

  void set(String key, dynamic value) {
    fields[key] = value;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 'plan':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Notice(
              'Puedes cambiar de plan después. Los cambios se hacen efectivos el próximo lunes.',
            ),
            ...['free', 'pro'].map(
              (plan) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: enabled ? () => set('plan', plan) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          fields['plan'] == plan
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan == 'free'
                                    ? 'Free · a tu manera'
                                    : 'Pro · un paso menos',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                plan == 'free'
                                    ? 'Menú personal, catálogo, cambios y opiniones.'
                                    : 'Todo Free, más dirección y entregas simuladas. Sin pagos.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'calendar':
        return _calendar(context);
      case 'restrictions':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: fields['diet'] as String? ?? 'omnivore',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tu dieta'),
              items: const [
                DropdownMenuItem(value: 'omnivore', child: Text('Omnívora')),
                DropdownMenuItem(
                  value: 'vegetarian',
                  child: Text('Vegetariana'),
                ),
                DropdownMenuItem(value: 'vegan', child: Text('Vegana')),
              ],
              onChanged: enabled ? (v) => set('diet', v) : null,
            ),
            const SizedBox(height: 20),
            _selection(
              context,
              'allergen_codes',
              'Alérgenos que evitas',
              options['allergens'] as List,
            ),
            _selection(
              context,
              'excluded_ingredient_codes',
              'Ingredientes excluidos',
              options['ingredients'] as List,
            ),
            const Notice(
              'Estas restricciones se contrastan con un catálogo de demostración no verificado.',
            ),
          ],
        );
      case 'preferences':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _selection(
              context,
              'liked_ingredient_codes',
              'Ingredientes que te gustan',
              options['ingredients'] as List,
            ),
            _selection(
              context,
              'disliked_ingredient_codes',
              'Ingredientes que prefieres menos',
              options['ingredients'] as List,
            ),
            _selection(
              context,
              'preferred_categories',
              'Categorías preferidas',
              (options['categories'] as List)
                  .map(
                    (x) => {
                      'code': x,
                      'name': (x as String).replaceAll('_', ' '),
                    },
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue:
                  fields['repetition_tolerance'] as String? ?? 'normal',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Repetición de un plato en siete días',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'low',
                  child: Text('Poca · objetivo 1 vez'),
                ),
                DropdownMenuItem(
                  value: 'normal',
                  child: Text('Normal · objetivo 2 veces'),
                ),
                DropdownMenuItem(
                  value: 'high',
                  child: Text('Flexible · objetivo 3 veces'),
                ),
              ],
              onChanged: enabled ? (v) => set('repetition_tolerance', v) : null,
            ),
            const SizedBox(height: 20),
            const Notice(
              'Los gustos orientan próximos menús. Tus restricciones siempre tienen prioridad.',
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu punto de partida',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Plan ${(fields['plan'] as String? ?? 'free').toUpperCase()} · ${_count()} comidas por semana',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu primer menú se publicará después de la revisión del operario.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: enabled
                  ? () async {
                      final now = DateTime.parse(today);
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(
                          fields['service_start_date'] as String? ??
                              dateKey(now.add(const Duration(days: 1))),
                        ),
                        firstDate: now.add(const Duration(days: 1)),
                        lastDate: DateTime(now.year, now.month + 2, 0),
                      );
                      if (date != null) {
                        set('service_start_date', dateKey(date));
                      }
                    }
                  : null,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                'Inicio: ${fields['service_start_date'] == null ? 'Elegir fecha' : shortDate(fields['service_start_date'] as String)}',
              ),
            ),
            const SizedBox(height: 16),
            if (fields['plan'] == 'pro') ...[
              Text(
                'Dirección ficticia',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              AddressFields(
                fields: (fields['address'] ??= <String, dynamic>{}) as Json,
                onChanged: onChanged,
                enabled: enabled,
              ),
            ],
          ],
        );
    }
  }

  int _count() => (fields['weekly_slots'] as List).fold(
    0,
    (n, x) => n + ((x as Json)['meal_slots'] as List).length,
  );

  Widget _calendar(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Notice(
        'Elige las comidas que quieres planificar. Necesitas al menos una por semana.',
      ),
      ...(fields['weekly_slots'] as List).map((entry) {
        final row = entry as Json;
        final meals = row['meal_slots'] as List;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekdays[(row['weekday'] as int) - 1],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: mealLabels.entries
                      .map(
                        (m) => FilterChip(
                          label: Text(m.value),
                          selected: meals.contains(m.key),
                          onSelected: enabled
                              ? (selected) {
                                  selected
                                      ? meals.add(m.key)
                                      : meals.remove(m.key);
                                  onChanged();
                                }
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
      Text(
        '${_count()} comidas por semana',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );

  Widget _selection(
    BuildContext context,
    String key,
    String label,
    List choices,
  ) {
    final selected = (fields[key] as List? ?? []).cast<String>();
    final known = choices.map((x) => (x as Json)['code']).toSet();
    choices = [
      ...selected
          .where((code) => !known.contains(code))
          .map(
            (code) => {
              'code': code,
              'name': '$code (fuera del catálogo; revisar)',
            },
          ),
      ...choices,
    ];
    final names = choices
        .where((x) => selected.contains((x as Json)['code']))
        .map((x) => (x as Json)['name'])
        .join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton(
        onPressed: enabled
            ? () async {
                final result = await showDetail<List<String>>(
                  context,
                  MultiSelect(
                    title: label,
                    choices: choices,
                    selected: selected,
                  ),
                );
                if (result != null) {
                  fields[key] = result;
                  if (key == 'liked_ingredient_codes' ||
                      key == 'disliked_ingredient_codes') {
                    final other = key == 'liked_ingredient_codes'
                        ? 'disliked_ingredient_codes'
                        : 'liked_ingredient_codes';
                    fields[other] = (fields[other] as List)
                        .where((x) => !result.contains(x))
                        .toList();
                  }
                  onChanged();
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(names.isEmpty ? 'Ninguno seleccionado · elegir' : names),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddressFields extends StatelessWidget {
  const AddressFields({
    super.key,
    required this.fields,
    required this.onChanged,
    this.enabled = true,
  });
  final Json fields;
  final VoidCallback onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ...{
        'line1': 'Calle y número',
        'city': 'Ciudad',
        'postal_code': 'Código postal',
        'notes': 'Observaciones (opcional)',
      }.entries.map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            initialValue: fields[e.key] as String? ?? '',
            enabled: enabled,
            maxLength: {
              'line1': 150,
              'city': 80,
              'postal_code': 12,
              'notes': 250,
            }[e.key],
            decoration: InputDecoration(labelText: e.value, counterText: ''),
            onChanged: (value) {
              fields[e.key] = value;
              onChanged();
            },
          ),
        ),
      ),
    ],
  );
}

class MultiSelect extends StatefulWidget {
  const MultiSelect({
    super.key,
    required this.title,
    required this.choices,
    required this.selected,
  });
  final String title;
  final List choices;
  final List<String> selected;
  @override
  State<MultiSelect> createState() => _MultiSelectState();
}

class _MultiSelectState extends State<MultiSelect> {
  late final Set<String> _selected = widget.selected.toSet();
  String _query = '';
  bool _dirty = false;
  @override
  Widget build(BuildContext context) {
    final choices = widget.choices
        .where(
          (x) => foldSearch(
            (x as Json)['name'] as String,
          ).contains(foldSearch(_query)),
        )
        .toList();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop &&
            await confirm(
              context,
              'Descartar selección',
              'Los cambios de esta selección no se han aplicado.',
              label: 'Descartar',
            )) {
          if (context.mounted) {
            setState(() => _dirty = false);
            Navigator.pop(context);
          }
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: choices.length,
              itemBuilder: (context, index) {
                final item = choices[index] as Json,
                    code = item['code'] as String;
                return CheckboxListTile(
                  title: Text(item['name'] as String),
                  value: _selected.contains(code),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setState(() {
                    v! ? _selected.add(code) : _selected.remove(code);
                    _dirty = true;
                  }),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${_selected.length} seleccionados'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _selected.toList()..sort()),
                    child: const Text('Aplicar selección'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
