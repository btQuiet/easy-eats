import 'package:flutter/material.dart';
import '../../core/controllers.dart';
import '../../shared/widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session});
  final SessionController session;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _alias = TextEditingController(), _password = TextEditingController();
  bool _register = false, _obscure = true;
  @override
  void dispose() {
    _alias.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _server() async {
    final controller = TextEditingController(
      text: widget.session.repository.api.baseUrl,
    );
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Servidor LAN'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Dirección del backend',
            hintText: 'http://192.168.1.20:8000',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url != null) {
      try {
        await widget.session.changeServer(url);
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final intro = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'easy eats.',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'Comer bien.\nSin darle tantas vueltas.',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Una semana pensada para ti.\nTus gustos, tu ritmo y un menú que puedes cambiar.',
                          style: TextStyle(fontSize: 18, height: 1.6),
                        ),
                        const SizedBox(height: 28),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Tag(
                              'Menú personal',
                              icon: Icons.calendar_today_outlined,
                            ),
                            Tag(
                              'Primera revisión',
                              icon: Icons.verified_outlined,
                            ),
                            Tag('A tu ritmo', icon: Icons.spa_outlined),
                          ],
                        ),
                      ],
                    );
                    final form = Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _register
                                    ? 'Empecemos contigo'
                                    : 'Qué bueno verte',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _register
                                    ? 'Crea tu cuenta para preparar tu primera semana.'
                                    : 'Accede a tu semana o al panel de revisión.',
                              ),
                              const SizedBox(height: 24),
                              if (s.error != null)
                                Notice(s.error!.message, error: true),
                              if (s.restoring)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else ...[
                                TextFormField(
                                  controller: _alias,
                                  enabled: !s.busy,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: const InputDecoration(
                                    labelText: 'Alias',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) =>
                                      RegExp(
                                        r'^[a-z0-9_]{3,30}$',
                                      ).hasMatch((v ?? '').trim().toLowerCase())
                                      ? null
                                      : 'Usa 3–30 letras, números o guion bajo.',
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  enabled: !s.busy,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Mostrar contraseña'
                                          : 'Ocultar contraseña',
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v?.length ?? 0) >= 8 &&
                                          (v?.length ?? 0) <= 128
                                      ? null
                                      : 'Entre 8 y 128 caracteres.',
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 24),
                                BusyButton(
                                  label: _register
                                      ? 'Crear mi cuenta'
                                      : 'Entrar',
                                  busy: s.busy,
                                  onPressed: _submit,
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: s.busy
                                      ? null
                                      : () => setState(
                                          () => _register = !_register,
                                        ),
                                  child: Text(
                                    _register
                                        ? 'Ya tengo una cuenta'
                                        : 'Crear una cuenta',
                                  ),
                                ),
                              ],
                              const Divider(height: 32),
                              OutlinedButton.icon(
                                onPressed: s.busy ? null : _server,
                                icon: const Icon(Icons.dns_outlined),
                                label: const Text('Servidor LAN'),
                              ),
                              if (s.error != null)
                                TextButton(
                                  onPressed: s.restore,
                                  child: const Text('Reintentar conexión'),
                                ),
                              const SizedBox(height: 16),
                              const Text(
                                'Proyecto de demostración · utiliza datos ficticios.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    return constraints.maxWidth >= 850
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: intro),
                              const SizedBox(width: 64),
                              Expanded(child: form),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [intro, const SizedBox(height: 32), form],
                          );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  void _submit() {
    if (_form.currentState!.validate()) {
      widget.session.authenticate(_alias.text, _password.text, _register);
    }
  }
}
