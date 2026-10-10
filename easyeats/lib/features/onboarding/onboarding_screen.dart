import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import 'configuration_fields.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _loader = LoadController<Json>();
  Json? _fields;
  int _step = 0, _version = 1;
  bool _busy = false, _dirty = false;
  bool _explicitStart = false;
  ApiException? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _loader.load(() async {
    final repo = widget.session.repository;
    final profile = await repo.get('/profile'),
        options = await repo.get('/catalog/options');
    _version = profile['version'] as int;
    _fields ??= {
      ...defaultConfiguration(),
      ...jsonDecode(jsonEncode(profile)) as Json,
    };
    _explicitStart = profile['service_start_date'] != null;
    final completed = profile['last_completed_step'] as String?;
    if (!_dirty && completed != null) {
      _step = (steps.indexOf(completed) + 1).clamp(0, 4);
    }
    final today = DateTime.parse(repo.api.serverToday!);
    if (_fields!['service_start_date'] == null ||
        (_fields!['service_start_date'] as String).compareTo(
              repo.api.serverToday!,
            ) <=
            0) {
      _explicitStart = false;
      for (var offset = 1; offset <= 7; offset++) {
        final d = today.add(Duration(days: offset));
        final slots = (_fields!['weekly_slots'] as List)[d.weekday - 1] as Json;
        if ((slots['meal_slots'] as List).isNotEmpty) {
          _fields!['service_start_date'] = dateKey(d);
          break;
        }
      }
    }
    return {'options': options};
  });
  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    const keys = [
      ['plan'],
      ['weekly_slots'],
      ['diet', 'allergen_codes', 'excluded_ingredient_codes'],
      [
        'liked_ingredient_codes',
        'disliked_ingredient_codes',
        'preferred_categories',
        'repetition_tolerance',
      ],
      ['service_start_date', 'address'],
    ];
    final fields = <String, dynamic>{
      for (final k in keys[_step])
        if (_fields!.containsKey(k)) k: _fields![k],
    };
    if (_fields!['plan'] == 'free') fields.remove('address');
    try {
      final saved = await widget.session.repository.write(
        'PUT',
        '/onboarding/draft',
        {'expected_version': _version, 'step': steps[_step], 'fields': fields},
      );
      _version = saved['version'] as int;
      _dirty = false;
      if (_step == 4) {
        await widget.session.repository.write('POST', '/onboarding/complete', {
          'expected_version': _version,
        });
        await widget.session.refresh();
      } else if (mounted) {
        if (_step == 1 && !_explicitStart) {
          final today = DateTime.parse(
            widget.session.repository.api.serverToday!,
          );
          for (var offset = 1; offset <= 7; offset++) {
            final date = today.add(Duration(days: offset));
            final day = (_fields!['weekly_slots'] as List)
                .cast<Json>()
                .firstWhere((x) => x['weekday'] == date.weekday);
            if ((day['meal_slots'] as List).isNotEmpty) {
              _fields!['service_start_date'] = dateKey(date);
              break;
            }
          }
        }
        setState(() => _step++);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _checkSaved() async {
    try {
      final p = await widget.session.repository.get('/profile');
      if (p['completed'] == true) {
        await widget.session.refresh();
        return;
      }
      if (!mounted) return;
      final adopt = await confirm(
        context,
        'Comprobar guardado',
        'La versión del servidor es ${p['version']}. Puedes conservar este formulario y usar esa versión al guardar. Revisa primero cualquier cambio en otra pestaña.',
        label: 'Conservar formulario',
      );
      if (adopt && mounted) {
        setState(() {
          _version = p['version'] as int;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('easy eats.'),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  if (!_dirty ||
                      await confirm(
                        context,
                        'Salir de la configuración',
                        'Los cambios sin guardar de este paso se perderán.',
                        label: 'Salir',
                      )) {
                    await widget.session.logout();
                  }
                },
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
    body: LoadView(
      controller: _loader,
      retry: _load,
      builder: (data, stale) {
        const titles = [
          'Tu plan',
          'Tu semana, tu ritmo',
          'Lo que necesitas evitar',
          'Lo que te apetece',
          'Todo listo para empezar',
        ];
        return PageFrame(
          title: titles[_step],
          subtitle: 'Configuración · paso ${_step + 1} de 5',
          children: [
            LinearProgressIndicator(value: (_step + 1) / 5),
            const SizedBox(height: 24),
            if (_error != null)
              Notice(
                _error!.message,
                error: true,
                action: TextButton(
                  onPressed: _checkSaved,
                  child: const Text('Comprobar estado del guardado'),
                ),
              ),
            ConfigurationFields(
              key: ValueKey(_step),
              step: steps[_step],
              fields: _fields!,
              options: data['options'] as Json,
              enabled: !stale && !_busy,
              today: widget.session.repository.api.serverToday!,
              onChanged: () => setState(() {
                _dirty = true;
                if (_step == 4) _explicitStart = true;
              }),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!_dirty ||
                                await confirm(
                                  context,
                                  'Volver al paso anterior',
                                  'Conservaremos estos cambios en memoria hasta que los guardes.',
                                  label: 'Volver',
                                )) {
                              if (mounted) setState(() => _step--);
                            }
                          },
                    child: const Text('Anterior'),
                  ),
                BusyButton(
                  label: _step == 4
                      ? 'Terminar configuración'
                      : 'Guardar y continuar',
                  busy: _busy,
                  onPressed: stale ? null : _next,
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
