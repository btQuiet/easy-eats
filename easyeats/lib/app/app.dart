import 'package:flutter/material.dart';

import '../core/api.dart';
import '../features/auth/auth_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/delivery/delivery_screen.dart';
import '../features/menu/menu_screen.dart';
import '../features/onboarding/profile_editor.dart';
import '../features/operator/operator_screen.dart';
import 'theme.dart';

class AppController extends ChangeNotifier {
  final ApiClient api = ApiClient();
  Map<String, dynamic>? user;
  Map<String, dynamic>? profile;
  Map<String, dynamic>? capabilities;
  bool loading = true;
  String? startupError;

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      capabilities = Map<String, dynamic>.from(
        await api.get('/system/capabilities'),
      );
      startupError = null;
    } catch (error) {
      capabilities = null;
      startupError = error.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setServer(String value) async {
    api.baseUrl = value.trim();
    await initialize();
  }

  Future<void> signIn(
    String username,
    String password, {
    bool register = false,
  }) async {
    final result = Map<String, dynamic>.from(
      await api.post(register ? '/auth/register' : '/auth/login', {
        'username': username.trim(),
        'password': password,
      }),
    );
    api.token = result['token'] as String;
    user = Map<String, dynamic>.from(result['user']);
    if (user!['role'] == 'client') {
      final stored = await api.get('/profile');
      profile = stored == null ? null : Map<String, dynamic>.from(stored);
    } else {
      profile = null;
    }
    notifyListeners();
  }

  Future<void> saveProfile(Map<String, dynamic> value) async {
    profile = Map<String, dynamic>.from(await api.put('/profile', value));
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final stored = await api.get('/profile');
    profile = stored == null ? null : Map<String, dynamic>.from(stored);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    api.token = null;
    user = null;
    profile = null;
    notifyListeners();
  }
}

class EasyEatsApp extends StatefulWidget {
  const EasyEatsApp({super.key});

  @override
  State<EasyEatsApp> createState() => _EasyEatsAppState();
}

class _EasyEatsAppState extends State<EasyEatsApp> {
  final controller = AppController();

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Easy Eats',
    debugShowCheckedModeBanner: false,
    theme: easyEatsTheme(),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.user == null) return AuthScreen(controller: controller);
        if (controller.user!['role'] == 'operator') {
          return OperatorScreen(controller: controller);
        }
        if (controller.profile == null) {
          return ProfileEditor(controller: controller, onboarding: true);
        }
        return ClientShell(controller: controller);
      },
    ),
  );
}

class ClientShell extends StatefulWidget {
  final AppController controller;
  const ClientShell({super.key, required this.controller});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final pro = widget.controller.profile?['plan'] == 'pro';
    final labels = ['Semana', 'Catálogo', 'Perfil', if (pro) 'Entregas'];
    final icons = [
      Icons.calendar_month_outlined,
      Icons.restaurant_menu_outlined,
      Icons.person_outline,
      if (pro) Icons.local_shipping_outlined,
    ];
    if (selected >= labels.length) selected = 0;
    final pages = <Widget>[
      MenuScreen(controller: widget.controller),
      CatalogScreen(controller: widget.controller),
      ProfileEditor(controller: widget.controller, onboarding: false),
      if (pro) DeliveryScreen(controller: widget.controller),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Easy Eats',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              label: Text(
                widget.controller.capabilities?['label']?.toString() ??
                    'Sin conexión',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.controller.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1100,
              selectedIndex: selected,
              onDestinationSelected: (index) =>
                  setState(() => selected = index),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationRailDestination(
                    icon: Icon(icons[i]),
                    label: Text(labels[i]),
                  ),
              ],
            ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(selected),
              child: pages[selected],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (index) =>
                  setState(() => selected = index),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
    );
  }
}
