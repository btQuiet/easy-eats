import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../catalog/catalog_screen.dart';

class OperatorScreen extends StatefulWidget {
  final AppController controller;
  const OperatorScreen({super.key, required this.controller});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  List<Map<String, dynamic>> pending = [];
  Map<String, dynamic>? detail;
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadQueue();
  }

  Future<void> loadQueue() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await widget.controller.api.get('/operator/pending') as List;
      if (mounted) {
        setState(() {
          pending = rows.map((row) => Map<String, dynamic>.from(row)).toList();
          detail = null;
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openCycle(int id) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.controller.api.get('/operator/cycles/$id');
      if (mounted) setState(() => detail = Map<String, dynamic>.from(response));
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> action(String suffix, String success) async {
    final cycle = Map<String, dynamic>.from(detail!['cycle']);
    setState(() => busy = true);
    try {
      final result = await widget.controller.api.post(
        '/operator/cycles/${cycle['id']}/$suffix',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
      if (suffix == 'approve') {
        await loadQueue();
      } else {
        await openCycle(result['id'] as int);
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> replace(Map<String, dynamic> item) async {
    try {
      final chosen = await pickRecipe(
        context,
        widget.controller.api,
        item['slot'].toString(),
        profile: Map<String, dynamic>.from(detail!['profile']),
      );
      if (chosen == null) return;
      await widget.controller.api.post(
        '/operator/items/${item['id']}/replace',
        {'recipe_code': chosen['code'], 'expected_version': item['version']},
      );
      final cycle = Map<String, dynamic>.from(detail!['cycle']);
      await openCycle(cycle['id'] as int);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    }
  }

  Widget queueView() => RefreshIndicator(
    onRefresh: loadQueue,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Revisión inicial',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Revisa solo el primer menú mensual de cada usuario. Los siguientes se publican automáticamente.',
        ),
        const SizedBox(height: 18),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (pending.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay propuestas pendientes.'),
            ),
          ),
        for (final row in pending)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(row['username'].toString()),
              subtitle: Text(
                '${row['month']} · ${row['plan']} · ${row['origin']}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openCycle(row['id'] as int),
            ),
          ),
      ],
    ),
  );

  Widget detailView() {
    final cycle = Map<String, dynamic>.from(detail!['cycle']);
    final profile = Map<String, dynamic>.from(detail!['profile']);
    final items = (detail!['items'] as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final allergens = (profile['allergens'] as List? ?? []).join(', ');
    final excluded = (profile['excluded_ingredients'] as List? ?? []).join(
      ', ',
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: loadQueue,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Pendientes'),
          ),
        ),
        Text(
          '${cycle['username']} · ${cycle['month']}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          '${items.length} comidas · ${cycle['origin'] == 'ai' ? 'Generado con IA' : 'Modo de pruebas'}',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perfil registrado',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Plan: ${profile['plan']} · dieta: ${profile['diet']}'),
                Text('Alérgenos: ${allergens.isEmpty ? 'ninguno' : allergens}'),
                Text(
                  'Ingredientes excluidos: ${excluded.isEmpty ? 'ninguno' : excluded}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => action('approve', 'Primera propuesta aprobada.'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Aprobar primer menú'),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => action('regenerate', 'Nueva propuesta generada.'),
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerar mes'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Puedes sustituir platos antes de aprobar. La app comprueba el perfil registrado, pero el catálogo es demostrativo.',
        ),
        const SizedBox(height: 20),
        for (final day
            in items.map((item) => item['day'].toString()).toSet()) ...[
          Text(day, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          for (final item in items.where((item) => item['day'] == day))
            Card(
              child: ListTile(
                title: Text('${item['slot']} · ${item['recipe']?['name']}'),
                subtitle: Text(
                  (item['recipe']?['ingredients'] as List? ?? [])
                      .map((ingredient) => ingredient['name'])
                      .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Ver plato',
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => showRecipeDetails(
                        context,
                        Map<String, dynamic>.from(item['recipe']),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sustituir',
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: busy ? null : () => replace(item),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Easy Eats · Operario'),
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
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!),
                    TextButton(
                      onPressed: loadQueue,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : detail == null
            ? queueView()
            : detailView(),
      ),
    ),
  );
}
