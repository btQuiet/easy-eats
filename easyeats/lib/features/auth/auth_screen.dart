import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';

class AuthScreen extends StatefulWidget {
  final AppController controller;
  const AuthScreen({super.key, required this.controller});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  late final TextEditingController server = TextEditingController(
    text: widget.controller.api.baseUrl,
  );
  bool register = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    server.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (server.text.trim() != widget.controller.api.baseUrl) {
        await widget.controller.setServer(server.text);
      }
      await widget.controller.signIn(
        username.text,
        password.text,
        register: register,
      );
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Expanded(
                child: Container(
                  color: EatsColors.forest,
                  padding: const EdgeInsets.all(64),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.ramen_dining,
                        size: 76,
                        color: EatsColors.sage,
                      ),
                      SizedBox(height: 28),
                      Text(
                        'Tu semana,\na tu manera.',
                        style: TextStyle(
                          fontSize: 48,
                          height: 1.1,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Elige tus días y comidas. Nosotros ordenamos el menú; tú decides los cambios.',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!wide) ...[
                          const Icon(
                            Icons.ramen_dining,
                            color: EatsColors.forest,
                            size: 56,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Easy Eats',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          register
                              ? 'Crea una cuenta de prueba'
                              : 'Entra en tu cuenta de prueba',
                        ),
                        const SizedBox(height: 26),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Entrar')),
                            ButtonSegment(
                              value: true,
                              label: Text('Crear cuenta'),
                            ),
                          ],
                          selected: {register},
                          onSelectionChanged: (values) =>
                              setState(() => register = values.first),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: username,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          onSubmitted: (_) => submit(),
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          title: const Text('Servidor LAN'),
                          subtitle: Text(
                            server.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          children: [
                            TextField(
                              controller: server,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Dirección de FastAPI',
                                hintText: 'http://192.168.1.10:8000',
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'En Android usa la IP del ordenador servidor, no localhost.',
                            ),
                          ],
                        ),
                        if (widget.controller.startupError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.controller.startupError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(register ? 'Crear cuenta' : 'Entrar'),
                        ),
                        const SizedBox(height: 24),
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Operario de demostración: usuario operario. La contraseña se configura en el servidor. Los menús y entregas son de prueba.',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
