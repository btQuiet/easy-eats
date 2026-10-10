import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';

class ProfileEditor extends StatefulWidget {
  final AppController controller;
  final bool onboarding;
  const ProfileEditor({
    super.key,
    required this.controller,
    required this.onboarding,
  });

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  static const days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const meals = ['desayuno', 'comida', 'cena', 'merienda'];

  String plan = 'free';
  String diet = 'omnivore';
  final address = TextEditingController();
  final schedule = <String>{};
  final allergens = <String>{};
  final excluded = <String>{};
  final liked = <String>{};
  final disliked = <String>{};
  List<Map<String, dynamic>> allAllergens = [];
  List<Map<String, dynamic>> ingredients = [];
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    if (profile != null) {
      plan = profile['plan'] ?? 'free';
      diet = profile['diet'] ?? 'omnivore';
      address.text = profile['address'] ?? '';
      for (final item in profile['schedule'] ?? []) {
        schedule.add('${item['weekday']}:${item['slot']}');
      }
      allergens.addAll(List<String>.from(profile['allergens'] ?? []));
      excluded.addAll(List<String>.from(profile['excluded_ingredients'] ?? []));
      liked.addAll(List<String>.from(profile['liked_ingredients'] ?? []));
      disliked.addAll(List<String>.from(profile['disliked_ingredients'] ?? []));
    }
    loadCatalog();
  }

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  Future<void> loadCatalog() async {
    try {
      final meta = Map<String, dynamic>.from(
        await widget.controller.api.get('/catalog/meta'),
      );
      if (mounted) {
        setState(() {
          allAllergens = List<Map<String, dynamic>>.from(
            (meta['allergens'] as List).map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
          ingredients = List<Map<String, dynamic>>.from(
            (meta['ingredients'] as List).map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final slotList = schedule.map((value) {
        final parts = value.split(':');
        return {'weekday': int.parse(parts[0]), 'slot': parts[1]};
      }).toList();
      await widget.controller.saveProfile({
        'plan': plan,
        'diet': diet,
        'address': address.text,
        'schedule': slotList,
        'allergens': allergens.toList(),
        'excluded_ingredients': excluded.toList(),
        'liked_ingredients': liked.toList(),
        'disliked_ingredients': disliked.toList(),
      });
      if (mounted && !widget.onboarding) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Perfil guardado. Revisa los platos futuros si cambiaste restricciones.',
            ),
          ),
        );
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String ingredientName(String code) =>
      ingredients
          .where((item) => item['code'] == code)
          .map((item) => item['name'].toString())
          .firstOrNull ??
      code;

  Widget ingredientSelector(String title, Set<String> values, {String? note}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (note != null) ...[const SizedBox(height: 4), Text(note)],
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: null,
              hint: const Text('Añadir ingrediente'),
              isExpanded: true,
              items: [
                for (final item in ingredients)
                  if (!values.contains(item['code']))
                    DropdownMenuItem(
                      value: item['code'].toString(),
                      child: Text(item['name'].toString()),
                    ),
              ],
              onChanged: (code) {
                if (code == null) return;
                setState(() {
                  values.add(code);
                  if (identical(values, liked)) disliked.remove(code);
                  if (identical(values, disliked)) liked.remove(code);
                });
              },
            ),
            if (values.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final code in values)
                    InputChip(
                      label: Text(ingredientName(code)),
                      onDeleted: () => setState(() => values.remove(code)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 950),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.onboarding ? 'Haz tu menú tuyo' : 'Tu perfil',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Elige solo los días y las comidas que quieres. Podrás cambiar tus gustos después.',
            ),
            const SizedBox(height: 24),
            Text('1 · Tu plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: const Text('Free · solo menús'),
                  selected: plan == 'free',
                  onSelected: (_) => setState(() => plan = 'free'),
                ),
                ChoiceChip(
                  label: const Text('Pro · menús + entrega simulada'),
                  selected: plan == 'pro',
                  onSelected: (_) => setState(() => plan = 'pro'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '2 · Días y comidas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Deja en blanco los días que no quieras. Selecciona al menos una comida semanal.',
            ),
            const SizedBox(height: 10),
            for (var day = 0; day < 7; day++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        days[day],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final meal in meals)
                            FilterChip(
                              label: Text(
                                meal[0].toUpperCase() + meal.substring(1),
                              ),
                              selected: schedule.contains('$day:$meal'),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  schedule.add('$day:$meal');
                                } else {
                                  schedule.remove('$day:$meal');
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              '3 · Restricciones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in const {
                  'omnivore': 'Sin dieta específica',
                  'vegetarian': 'Vegetariana',
                  'vegan': 'Vegana',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: diet == entry.key,
                    onSelected: (_) => setState(() => diet = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: ExpansionTile(
                title: const Text('Alérgenos declarados'),
                subtitle: const Text(
                  'Grupos de la UE; datos de platos no verificados',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final item in allAllergens)
                          FilterChip(
                            label: Text(item['name'].toString()),
                            selected: allergens.contains(item['code']),
                            onSelected: (selected) => setState(() {
                              final code = item['code'].toString();
                              if (selected) {
                                allergens.add(code);
                              } else {
                                allergens.remove(code);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ingredientSelector(
              'Ingredientes excluidos',
              excluded,
              note: 'Se quitarán de los candidatos para los nuevos menús.',
            ),
            const SizedBox(height: 20),
            Text(
              '4 · Tus gustos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ingredientSelector('Me gustan', liked),
            ingredientSelector(
              'Prefiero menos',
              disliked,
              note: 'Son preferencias, no restricciones obligatorias.',
            ),
            if (plan == 'pro') ...[
              const SizedBox(height: 20),
              Text(
                '5 · Entrega de prueba',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: address,
                decoration: const InputDecoration(
                  labelText: 'Dirección ficticia',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'El prototipo no organiza ni realiza entregas reales.',
              ),
            ],
            const SizedBox(height: 20),
            const Card(
              color: EatsColors.sage,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Catálogo demostrativo: la ausencia de un alérgeno registrado no garantiza que un plato real sea seguro.',
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: busy ? null : save,
              child: Text(
                busy
                    ? 'Guardando...'
                    : widget.onboarding
                    ? 'Guardar y continuar'
                    : 'Guardar cambios',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
    if (!widget.onboarding) return content;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Easy Eats · Primeros pasos'),
        actions: [
          TextButton(
            onPressed: widget.controller.logout,
            child: const Text('Salir'),
          ),
        ],
      ),
      body: content,
    );
  }
}
