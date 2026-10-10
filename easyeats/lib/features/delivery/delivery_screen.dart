import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/controllers.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../shared/widgets.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _controller = LoadController<ApiResult>();
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _controller.load(
    () => widget.repository.api.request(
      'GET',
      '/deliveries?limit=25&offset=$_offset',
    ),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoadView(
    controller: _controller,
    retry: _load,
    builder: (result, stale) {
      final rows = (result.data as List).cast<Json>();
      const states = {
        'scheduled': 'Programada',
        'preparing': 'En preparación',
        'in_delivery': 'En reparto',
        'delivered': 'Entregada',
        'cancelled': 'Cancelada',
      };
      return PageFrame(
        title: 'Un paso menos.',
        subtitle: 'Tu entrega semanal · plan Pro',
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.place_outlined),
            label: const Text('Dirección'),
          ),
          IconButton(
            onPressed: _load,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
        children: [
          const Notice(
            'Entregas simuladas para esta demostración. No hay pedidos, pagos ni repartidores reales.',
            icon: Icons.local_shipping_outlined,
          ),
          if (rows.isEmpty)
            const EmptyCard(
              title: 'Tu entrega aparecerá con el menú',
              text:
                  'Necesitas comidas aprobadas y compatibles durante tu plan Pro.',
              icon: Icons.local_shipping_outlined,
            ),
          ...rows.map(
            (d) => Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 32),
                        Text(
                          'Semana del ${shortDate(d['week_start'] as String)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Tag(
                          states[d['status']]!,
                          icon: d['status'] == 'delivered'
                              ? Icons.check_circle_outline
                              : Icons.schedule,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Fecha simulada: ${shortDate(d['scheduled_date'] as String)} · ${d['meal_count']} comidas',
                    ),
                    if (d['address_snapshot'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${(d['address_snapshot'] as Json)['line1']}\n${(d['address_snapshot'] as Json)['city']}',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Dirección guardada al entrar en preparación.',
                      ),
                    ],
                    if (d['cancelled_reason'] != null)
                      Text(
                        d['cancelled_reason'] == 'PLAN_FREE'
                            ? 'Cambio efectivo a Free.'
                            : 'Sin comidas válidas.',
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              if (_offset > 0)
                OutlinedButton(
                  onPressed: () {
                    _offset -= 25;
                    _load();
                  },
                  child: const Text('Anterior'),
                ),
              if (_offset + 25 < (result.meta['total'] as int))
                OutlinedButton(
                  onPressed: () {
                    _offset += 25;
                    _load();
                  },
                  child: const Text('Siguiente'),
                ),
            ],
          ),
        ],
      );
    },
  );
}
