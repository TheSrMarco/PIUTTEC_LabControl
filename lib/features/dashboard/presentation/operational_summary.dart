import 'package:flutter/material.dart';

import '../../inventory/data/inventory_store.dart';
import '../../loans/data/loan_store.dart';
import '../data/operational_stats.dart';

/// Panel de cifras reales. Se puede actualizar al volver de otro módulo.
class OperationalSummary extends StatefulWidget {
  const OperationalSummary({super.key});

  @override
  OperationalSummaryState createState() => OperationalSummaryState();
}

class OperationalSummaryState extends State<OperationalSummary> {
  late Future<OperationalStats> _summary = _load();

  Future<OperationalStats> _load() async {
    // Future.wait observa ambos errores y evita excepciones no controladas
    // cuando inventario y préstamos fallan en la misma actualización.
    final records = await Future.wait<Object>([
      const InventoryStore().list(),
      const LoanStore().list(),
    ]);
    return OperationalStats.fromRecords(
      records[0] as List<Equipment>,
      records[1] as List<Loan>,
    );
  }

  void refresh() {
    final nextSummary = _load();
    setState(() {
      _summary = nextSummary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Resumen operativo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar indicadores',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Indicadores de este dispositivo',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FutureBuilder<OperationalStats>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 104,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Card.outlined(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('No se pudieron cargar los indicadores'),
                  subtitle: const Text(
                    'Comprueba la base de datos local e inténtalo otra vez.',
                  ),
                  trailing: TextButton(
                    onPressed: refresh,
                    child: const Text('Reintentar'),
                  ),
                ),
              );
            }
            final stats = snapshot.data!;
            if (stats.isEmpty) {
              return Card.outlined(
                child: const ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Sin registros todavía'),
                  subtitle: Text(
                    'Registra tu primer equipo en Inventario para ver '
                    'las cifras del laboratorio.',
                  ),
                ),
              );
            }

            final values = [
              (
                'Equipos registrados',
                stats.totalEquipment,
                Icons.devices_outlined,
                'total',
              ),
              (
                'Disponibles',
                stats.available,
                Icons.check_circle_outline,
                'available',
              ),
              (
                'En préstamo',
                stats.onLoan,
                Icons.output_outlined,
                'loaned',
              ),
              (
                'En mantenimiento',
                stats.maintenance,
                Icons.build_outlined,
                'maintenance',
              ),
              (
                'Dados de baja',
                stats.retired,
                Icons.block_outlined,
                'retired',
              ),
              (
                'Préstamos activos',
                stats.activeLoans,
                Icons.assignment_outlined,
                'active-loans',
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 12.0;
                    final columns = constraints.maxWidth >= 660
                        ? 3
                        : constraints.maxWidth >= 340
                            ? 2
                            : 1;
                    final tileWidth =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final (label, value, symbol, id) in values)
                          SizedBox(
                            width: tileWidth,
                            child: Card.outlined(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      symbol,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            value.toString(),
                                            key: ValueKey('summary-$id'),
                                            style: Theme.of(context)
                                                .textTheme.headlineSmall,
                                          ),
                                          Text(
                                            label,
                                            style: Theme.of(context)
                                                .textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Préstamos devueltos: ${stats.completedLoans}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
