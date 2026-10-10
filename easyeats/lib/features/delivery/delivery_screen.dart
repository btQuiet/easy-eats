import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';

class DeliveryScreen extends StatefulWidget {
  final AppController controller;
  const DeliveryScreen({super.key, required this.controller});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  Map<String, dynamic>? delivery;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.controller.api.get('/delivery/week');
      if (mounted) {
        setState(() => delivery = Map<String, dynamic>.from(response));
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tus entregas',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text('Resumen del plan Pro para esta semana.'),
            const SizedBox(height: 20),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(error!),
                ),
              )
            else ...[
              Card(
                color: EatsColors.sage,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        delivery!['status'] == 'sin_menu'
                            ? 'Aún no hay menú para esta semana'
                            : 'Entrega de prueba planificada',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text('Semana del ${delivery!['week_start']}'),
                      Text('${delivery!['items_count']} platos'),
                      Text('Dirección: ${delivery!['address']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Esta es una simulación académica. No se realiza ningún pedido, pago ni reparto real.',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
