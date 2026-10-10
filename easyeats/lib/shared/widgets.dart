import 'package:flutter/material.dart';
import '../core/controllers.dart';
import '../core/models.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: ListView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
        ),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
          const SizedBox(height: 28),
          ...children,
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.error = false,
    this.icon = Icons.info_outline,
    this.action,
  });
  final String text;
  final bool error;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: error ? colors.errorContainer : colors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: error
                  ? colors.onErrorContainer
                  : colors.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: error
                          ? colors.onErrorContainer
                          : colors.onPrimaryContainer,
                    ),
                  ),
                  if (action != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: action!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadView<T> extends StatelessWidget {
  const LoadView({
    super.key,
    required this.controller,
    required this.retry,
    required this.builder,
  });
  final LoadController<T> controller;
  final VoidCallback retry;
  final Widget Function(T data, bool stale) builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final data = controller.data;
      if (data == null) {
        if (controller.error != null) {
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Notice(
                    controller.error!.message,
                    error: true,
                    action: OutlinedButton.icon(
                      onPressed: retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      }
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            if (controller.loading) const LinearProgressIndicator(),
            if (controller.error != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (constraints.maxHeight * .45)
                      .clamp(0.0, 240.0)
                      .toDouble(),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Notice(
                      '${controller.error!.message} Los datos guardados se muestran en lectura.',
                      error: true,
                      action: TextButton(
                        onPressed: retry,
                        child: const Text('Volver a conectar'),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(child: builder(data, controller.error != null)),
          ],
        ),
      );
    },
  );
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.title,
    required this.text,
    this.icon = Icons.spa_outlined,
    this.action,
  });
  final String title, text;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(text),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 20), child: action),
        ],
      ),
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    excludeSemantics: true,
    child: Chip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(text),
      visualDensity: VisualDensity.compact,
    ),
  );
}

class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon = Icons.arrow_forward,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon),
    label: Text(label),
  );
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error is ApiException
            ? error.message
            : 'No se pudo completar la operación.',
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String text, {
  String label = 'Confirmar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(label),
          ),
        ],
      ),
    ) ??
    false;

Future<T?> showDetail<T>(BuildContext context, Widget child) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      // Drag dismissal uses Navigator.pop and bypasses dirty-form PopScope.
      enableDrag: false,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: child,
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height - 32,
        ),
        child: child,
      ),
    ),
  );
}

class DetailLayout extends StatelessWidget {
  const DetailLayout({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

List<Widget> recipeFields(BuildContext context, Recipe recipe) => [
  Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      Tag(recipe.category, icon: Icons.restaurant_outlined),
      if (recipe.data['is_vegan'] == true)
        const Tag('Vegano', icon: Icons.spa_outlined)
      else if (recipe.data['is_vegetarian'] == true)
        const Tag('Vegetariano', icon: Icons.eco_outlined),
      if (recipe.compatible != null)
        Tag(
          recipe.compatible! ? 'Compatible' : 'Revisar restricciones',
          icon: recipe.compatible!
              ? Icons.check_circle_outline
              : Icons.warning_amber_outlined,
        ),
    ],
  ),
  const SizedBox(height: 20),
  Text('Ingredientes', style: Theme.of(context).textTheme.titleMedium),
  const SizedBox(height: 8),
  Text(recipe.ingredients.map((i) => (i as Json)['name']).join(', ')),
  const SizedBox(height: 20),
  Text('Alérgenos modelados', style: Theme.of(context).textTheme.titleMedium),
  const SizedBox(height: 8),
  Text(
    recipe.allergens.isEmpty
        ? 'Ninguno identificado en estos datos.'
        : recipe.allergens.map((a) => (a as Json)['name']).join(', '),
  ),
  const SizedBox(height: 20),
  const Notice(
    'Catálogo de demostración. Los ingredientes y alérgenos no están verificados; no se contempla contaminación cruzada.',
  ),
];
