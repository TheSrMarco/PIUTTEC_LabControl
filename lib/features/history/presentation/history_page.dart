import 'package:flutter/material.dart';

import '../../loans/data/loan_store.dart';
import '../data/history_movement.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Loan>> _loans = const LoanStore().list();
  String _search = '';
  MovementFilter _filter = MovementFilter.all;

  void _reload() {
    final updated = const LoanStore().list();
    setState(() {
      _loans = updated;
    });
  }

  String _formatDate(BuildContext context, DateTime time) {
    final locale = MaterialLocalizations.of(context);
    final date = locale.formatCompactDate(time);
    final hour = locale.formatTimeOfDay(TimeOfDay.fromDateTime(time));
    return '$date · $hour';
  }

  void _showDetails(HistoryMovement movement) {
    final loan = movement.loan;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(movement.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('Folio', loan.folio.toString()),
              _detail('ID de movimiento del equipo', loan.id.toString()),
              _detail('Equipo', loan.equipment),
              _detail('Código', loan.code),
              _detail('Solicitante', loan.borrower),
              if (loan.destination.isNotEmpty)
                _detail('Destino', loan.destination),
              _detail('Préstamo', _formatDate(context, loan.lentAt)),
              if (loan.returnedAt case final returnedAt?)
                _detail('Devolución', _formatDate(context, returnedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SelectableText(value),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Actualizar historial',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      labelText: 'Buscar movimiento',
                      hintText: 'Folio, equipo, código, solicitante o destino',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _chip(MovementFilter.all, 'Todos'),
                      _chip(MovementFilter.loans, 'Préstamos'),
                      _chip(MovementFilter.returns, 'Devoluciones'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<List<Loan>>(
                      future: _loans,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: TextButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text(
                                'No se pudo cargar el historial. Reintentar',
                              ),
                            ),
                          );
                        }

                        final all = buildHistoryMovements(snapshot.data ?? []);
                        final visible = filterHistoryMovements(
                          all,
                          filter: _filter,
                          query: _search,
                        );
                        if (visible.isEmpty) {
                          return Center(
                            child: Text(
                              all.isEmpty
                                  ? 'Aún no hay préstamos ni devoluciones registrados.'
                                  : 'No se encontraron movimientos con esos filtros.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: visible.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  '${visible.length} movimientos · Datos de este dispositivo',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            }
                            final movement = visible[index - 1];
                            final loan = movement.loan;
                            final isReturn =
                                movement.type == MovementType.returnLoan;
                            return Card.outlined(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                onTap: () => _showDetails(movement),
                                leading: Icon(
                                  isReturn
                                      ? Icons.assignment_turned_in_outlined
                                      : Icons.output_outlined,
                                ),
                                title: Text(movement.title),
                                subtitle: Text(
                                  'Folio ${loan.folio} · ${loan.equipment}\n'
                                  '${loan.code} · ${loan.borrower}\n'
                                  '${_formatDate(context, movement.occurredAt)}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(MovementFilter value, String label) => FilterChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );
}
