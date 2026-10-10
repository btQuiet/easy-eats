import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../shared/widgets.dart';
import '../onboarding/configuration_fields.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _controller = LoadController<Json>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _controller.load(() async {
    final values = await Future.wait<dynamic>([
      widget.repository.get('/profile'),
      widget.repository.get('/plan'),
      widget.repository.get('/catalog/options'),
      widget.repository.api
          .request('GET', '/delivery/address')
          .then((r) => r.data),
    ]);
    return {
      'profile': values[0],
      'plan': values[1],
      'options': values[2],
      'address': values[3],
    };
  });
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit(Json data, String section) async {
    await showDetail(
      context,
      ProfileEditor(
        repository: widget.repository,
        data: data,
        section: section,
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => LoadView(
    controller: _controller,
    retry: _load,
    builder: (data, stale) {
      final p = data['profile'] as Json, plan = data['plan'] as Json;
      final address = data['address'] as Json?;
      final options = data['options'] as Json;
      final knownAllergens = (options['allergens'] as List)
          .map((x) => (x as Json)['code'])
          .toSet();
      final knownIngredients = (options['ingredients'] as List)
          .map((x) => (x as Json)['code'])
          .toSet();
      final unknown =
          (p['allergen_codes'] as List).any(
            (x) => !knownAllergens.contains(x),
          ) ||
          (p['excluded_ingredient_codes'] as List).any(
            (x) => !knownIngredients.contains(x),
          );
      Widget card(String title, String text, IconData icon, String section) =>
          Card(
            key: ValueKey('profile-$section'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(text),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: stale ? null : () => _edit(data, section),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      {
                        'plan': 'Cambiar plan',
                        'calendar': 'Editar calendario',
                        'restrictions': 'Editar restricciones',
                        'preferences': 'Editar preferencias',
                        'address': 'Editar dirección',
                      }[section]!,
                    ),
                  ),
                ],
              ),
            ),
          );
      final cards = [
        card(
          'Plan ${(plan['current_plan'] as String).toUpperCase()}',
          plan['can_view_delivery'] == true
              ? 'Menú personal y entregas simuladas. Sin pagos.'
              : 'Menú personal, cambios y opiniones.',
          Icons.workspace_premium_outlined,
          'plan',
        ),
        card(
          'Tu calendario',
          '${weeklyMealCount(p)} comidas cada semana.\nLos cambios empiezan en ${monthLabel(p['next_calendar_effective_month'] as String)}.',
          Icons.calendar_today_outlined,
          'calendar',
        ),
        card(
          'Restricciones',
          'Dieta ${dietLabels[p['diet']]!.toLowerCase()}.\nAlérgenos: ${selectionText(p['allergen_codes'] as List, options['allergens'] as List, empty: 'ninguno declarado', limit: 4)}.\nIngredientes excluidos: ${selectionText(p['excluded_ingredient_codes'] as List, options['ingredients'] as List, empty: 'ninguno', limit: 4)}.',
          Icons.shield_outlined,
          'restrictions',
        ),
        card(
          'Tus preferencias',
          'Te gusta: ${selectionText(p['liked_ingredient_codes'] as List, options['ingredients'] as List, empty: 'aún sin favoritos', limit: 4)}.\nPrefieres menos: ${selectionText(p['disliked_ingredient_codes'] as List, options['ingredients'] as List, empty: 'sin preferencias', limit: 4)}.\n${repetitionLabels[p['repetition_tolerance']]}.',
          Icons.favorite_border,
          'preferences',
        ),
        if (plan['can_view_delivery'] == true || plan['pending_plan'] == 'pro')
          card(
            'Dirección ficticia',
            address == null
                ? 'Añade una dirección para tu simulación.'
                : '${address['line1']}\n${address['postal_code']} · ${address['city']}',
            Icons.place_outlined,
            'address',
          ),
      ];
      return PageFrame(
        title: 'Hecho a tu medida.',
        subtitle: 'Tus ajustes, siempre a mano.',
        children: [
          if (unknown)
            const Notice(
              'El catálogo ha cambiado y alguna restricción ya no aparece en él. Revisa los códigos señalados en Restricciones; se conservan hasta que los corrijas.',
              error: true,
            ),
          if (plan['pending_plan'] != null)
            Notice(
              'Cambio a ${(plan['pending_plan'] as String).toUpperCase()} el ${shortDate(plan['effective_date'] as String)}. Hasta entonces se mantiene el plan actual.',
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final setting in cards)
                    SizedBox(width: width, child: setting),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Notice(
            'Inicio del servicio: ${shortDate(p['service_start_date'] as String)}. Los cambios de gustos no reescriben menús publicados.',
          ),
        ],
      );
    },
  );
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.repository,
    required this.data,
    required this.section,
  });
  final AppRepository repository;
  final Json data;
  final String section;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final Json _fields =
      jsonDecode(jsonEncode(widget.data['profile'])) as Json;
  late Json _plan = Map.of(widget.data['plan'] as Json);
  late Json? _address = widget.data['address'] == null
      ? null
      : jsonDecode(jsonEncode(widget.data['address'])) as Json;
  bool _busy = false, _dirty = false;
  ApiException? _error;
  @override
  void initState() {
    super.initState();
    _fields['plan'] = _plan['pending_plan'] ?? _plan['current_plan'];
    _fields['address'] = _address == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.of(_address!);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final section = widget.section, repo = widget.repository;
    try {
      if (section == 'plan') {
        final body = <String, dynamic>{
          'expected_version': _plan['version'],
          'plan': _fields['plan'],
        };
        if (_fields['plan'] == 'pro') {
          body['address'] = {
            for (final key in ['line1', 'city', 'postal_code', 'notes'])
              key: (_fields['address'] as Json)[key] ?? '',
          };
          body['expected_address_version'] = _address?['version'] ?? 0;
        }
        await repo.write('PUT', '/plan', body);
      } else if (section == 'address') {
        await repo.write('PUT', '/delivery/address', {
          'expected_version': _address?['version'] ?? 0,
          for (final key in ['line1', 'city', 'postal_code', 'notes'])
            key: (_fields['address'] as Json)[key] ?? '',
        });
      } else if (section == 'calendar') {
        await repo.write('PUT', '/profile/calendar', {
          'expected_version': _fields['version'],
          'weekly_slots': _fields['weekly_slots'],
        });
      } else {
        final keys = section == 'restrictions'
            ? ['diet', 'allergen_codes', 'excluded_ingredient_codes']
            : [
                'liked_ingredient_codes',
                'disliked_ingredient_codes',
                'preferred_categories',
                'repetition_tolerance',
              ];
        await repo.write('PATCH', '/profile', {
          'expected_version': _fields['version'],
          for (final key in keys) key: _fields[key],
        });
      }
      if (mounted) {
        setState(() => _dirty = false);
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _checkState() async {
    try {
      final p = await widget.repository.get('/profile');
      final plan = await widget.repository.get('/plan');
      final address =
          (await widget.repository.api.request('GET', '/delivery/address')).data
              as Json?;
      if (!mounted) return;
      if (await confirm(
        context,
        'Revisar estado',
        'Se consultó el estado actual del servidor. Conserva tus cambios y revisa las nuevas versiones antes de guardar otra vez.',
        label: 'Conservar cambios',
      )) {
        if (mounted) {
          setState(() {
            _fields['version'] = p['version'];
            _plan = plan;
            _address = address;
            _error = null;
          });
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop &&
            !_busy &&
            await confirm(
              context,
              'Descartar cambios',
              'Hay ajustes sin guardar.',
              label: 'Descartar',
            )) {
          if (context.mounted) {
            setState(() => _dirty = false);
            Navigator.pop(context);
          }
        }
      },
      child: DetailLayout(
        title: {
          'plan': 'Tu plan',
          'calendar': 'Tu calendario',
          'restrictions': 'Restricciones',
          'preferences': 'Preferencias',
          'address': 'Dirección ficticia',
        }[section]!,
        children: [
          if (_error != null)
            Notice(
              _error!.message,
              error: true,
              action: TextButton(
                onPressed: _checkState,
                child: const Text('Comprobar guardado y versiones'),
              ),
            ),
          if (section == 'calendar')
            Notice(
              'Se aplicará desde ${monthLabel(_fields['next_calendar_effective_month'] as String)}. Se conservan los meses aprobados.',
            ),
          if (section == 'restrictions')
            const Notice(
              'Se revisarán las comidas de hoy y futuras. Las incompatibles quedarán marcadas para tu atención.',
            ),
          if (section == 'address')
            AddressFields(
              fields: _fields['address'] as Json,
              enabled: !_busy,
              onChanged: () => setState(() => _dirty = true),
            )
          else
            ConfigurationFields(
              step: section,
              fields: _fields,
              options: widget.data['options'] as Json,
              today: widget.repository.api.serverToday!,
              enabled: !_busy,
              onChanged: () => setState(() => _dirty = true),
            ),
          if (section == 'plan' && _fields['plan'] == 'pro') ...[
            const SizedBox(height: 16),
            AddressFields(
              fields: _fields['address'] as Json,
              enabled: !_busy,
              onChanged: () => setState(() => _dirty = true),
            ),
          ],
          const SizedBox(height: 24),
          BusyButton(
            label: 'Guardar cambios',
            busy: _busy,
            onPressed: _save,
            icon: Icons.check,
          ),
        ],
      ),
    );
  }
}
