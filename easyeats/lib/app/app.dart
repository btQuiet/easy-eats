import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/controllers.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../features/auth/auth_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/delivery/delivery_screen.dart';
import '../features/feedback/feedback_screen.dart';
import '../features/menu/week_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/operator/operator_screen.dart';
import '../features/profile/profile_screen.dart';
import 'theme/app_theme.dart';

class EasyEatsApp extends StatefulWidget {
  const EasyEatsApp({
    super.key,
    this.repository,
    this.session,
    this.restoreSession = true,
  });
  final AppRepository? repository;
  final SessionController? session;
  final bool restoreSession;
  @override
  State<EasyEatsApp> createState() => _EasyEatsAppState();
}

class _EasyEatsAppState extends State<EasyEatsApp> {
  late final AppRepository _repository =
      widget.repository ?? AppRepository(ApiClient());
  late final SessionController _session =
      widget.session ?? SessionController(_repository);
  late final GoRouter _router = GoRouter(
    initialLocation: '/login',
    refreshListenable: _session,
    redirect: (context, state) {
      final path = state.uri.path;
      if (_session.restoring || !_session.signedIn) {
        return path == '/login' ? null : '/login';
      }
      if (_session.role == 'client' && !_session.completed) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if (_session.role == 'operator' &&
          !['/operator', '/catalog'].contains(path)) {
        return '/operator';
      }
      if (_session.role == 'client' &&
          ['/login', '/onboarding', '/operator'].contains(path)) {
        return '/week';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => AuthScreen(session: _session),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(session: _session),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(session: _session, path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/week',
            builder: (context, state) => WeekScreen(repository: _repository),
          ),
          GoRoute(
            path: '/catalog',
            builder: (context, state) => CatalogScreen(repository: _repository),
          ),
          GoRoute(
            path: '/feedback',
            builder: (context, state) =>
                FeedbackScreen(repository: _repository),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => ProfileScreen(repository: _repository),
          ),
          GoRoute(
            path: '/deliveries',
            builder: (context, state) =>
                DeliveryScreen(repository: _repository),
          ),
          GoRoute(
            path: '/operator',
            builder: (context, state) =>
                OperatorScreen(repository: _repository),
          ),
        ],
      ),
    ],
  );
  @override
  void initState() {
    super.initState();
    if (widget.restoreSession) _session.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    if (widget.session == null) _session.dispose();
    if (widget.repository == null) _repository.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Easy Eats',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    themeAnimationDuration:
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180),
    routerConfig: _router,
    locale: const Locale('es', 'ES'),
    supportedLocales: const [Locale('es', 'ES')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.path,
    required this.child,
  });
  final SessionController session;
  final String path;
  final Widget child;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _pro = false;
  @override
  void initState() {
    super.initState();
    _plan();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _plan();
  }

  Future<void> _plan() async {
    if (widget.session.role != 'client') return;
    try {
      final plan = await widget.session.repository.get('/plan');
      if (mounted) setState(() => _pro = plan['can_view_delivery'] == true);
      if (plan['can_view_delivery'] != true &&
          widget.path == '/deliveries' &&
          mounted) {
        context.go('/profile');
      }
    } on ApiException {
      /* Content screens surface connection errors. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final operator = widget.session.role == 'operator';
    final destinations = operator
        ? [
            ('Primeras revisiones', Icons.verified_outlined, '/operator'),
            ('Catálogo', Icons.restaurant_outlined, '/catalog'),
          ]
        : [
            ('Mi semana', Icons.calendar_today_outlined, '/week'),
            ('Catálogo', Icons.restaurant_outlined, '/catalog'),
            ('Opiniones', Icons.chat_bubble_outline, '/feedback'),
            ('Perfil', Icons.person_outline, '/profile'),
          ];
    final desktopDestinations = [
      ...destinations,
      if (!operator && _pro)
        ('Entregas', Icons.local_shipping_outlined, '/deliveries'),
    ];
    final width = MediaQuery.sizeOf(context).width;
    final selected = destinations.indexWhere((x) => x.$3 == widget.path);
    final alias = (widget.session.session!['user'] as Json)['alias'] as String;
    return Scaffold(
      appBar: width < 1024
          ? AppBar(
              title: const Text('easy eats.'),
              actions: [
                IconButton(
                  onPressed: widget.session.logout,
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout),
                ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (width >= 1024)
            SizedBox(
              width: 240,
              child: Material(
                color: Theme.of(context).extension<AppThemeColors>()!.sidebar,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
                        child: Text(
                          'easy eats.',
                          style: Theme.of(context).textTheme.headlineSmall!
                              .copyWith(color: AppColors.sidebarText),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            ...desktopDestinations.map(
                              (d) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  selected: widget.path == d.$3,
                                  selectedTileColor: Theme.of(context)
                                      .extension<AppThemeColors>()!
                                      .sidebarSelected,
                                  textColor: AppColors.sidebarText,
                                  iconColor: AppColors.sidebarMuted,
                                  selectedColor: AppColors.sidebarText,
                                  leading: Icon(d.$2),
                                  title: Text(d.$1),
                                  onTap: () => context.go(d.$3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alias,
                              style: const TextStyle(
                                color: AppColors.sidebarText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              operator
                                  ? 'Operario'
                                  : _pro
                                  ? 'Plan Pro'
                                  : 'Plan Free',
                              style: const TextStyle(
                                color: AppColors.sidebarMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.session.capabilities?['generation_mode'] == 'ai' ? 'Generación IA' : 'Modo de pruebas'} · demo',
                              style: const TextStyle(
                                color: AppColors.sidebarMuted,
                                fontSize: 12,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: widget.session.logout,
                              icon: const Icon(Icons.logout),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.sidebarText,
                              ),
                              label: const Text('Cerrar sesión'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (width >= 600)
            NavigationRail(
              selectedIndex: selected < 0 ? 0 : selected,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) =>
                  context.go(destinations[index].$3),
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.$2),
                      label: Text(d.$1),
                    ),
                  )
                  .toList(),
            ),
          Expanded(child: SafeArea(child: widget.child)),
        ],
      ),
      bottomNavigationBar: width < 600
          ? NavigationBar(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (index) =>
                  context.go(destinations[index].$3),
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(icon: Icon(d.$2), label: d.$1),
                  )
                  .toList(),
            )
          : null,
    );
  }
}
