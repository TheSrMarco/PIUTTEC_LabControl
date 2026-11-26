import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/loan_store.dart';

class LoanManagementPage extends StatefulWidget {
  const LoanManagementPage({
    super.key,
    required this.loan,
    this.store = const LoanStore(),
    this.canOperate = true,
  });

  final bool canOperate;

  final Loan loan;
  final LoanStore store;

  @override
  State<LoanManagementPage> createState() => _LoanManagementPageState();
}

class _LoanManagementPageState extends State<LoanManagementPage> {
  final _reason = TextEditingController();
  final _detail = TextEditingController();
  late Future<List<LoanEvent>> _events = widget.store.listEvents(widget.loan.id);
  DateTime? _newDate;
  bool _busy = false;
  String? _error;

  void _reloadEvents() {
    final updated = widget.store.listEvents(widget.loan.id);
    setState(() {
      _events = updated;
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    _detail.dispose();
    super.dispose();
  }

  DateTime _minimumDate() {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = widget.loan.dueAt;
    if (current == null) return today;
    final after = DateTime(current.year, current.month, current.day + 1);
    return after.isAfter(today) ? after : today;
  }

  Future<void> _pickDate() async {
    final first = _minimumDate();
    final date = await showDatePicker(
      context: context,
      firstDate: first,
      initialDate: first,
      lastDate: DateTime(first.year + 10, 12, 31),
      helpText: 'Nueva fecha límite',
    );
    if (mounted && date != null) setState(() => _newDate = date);
  }

  String _format(DateTime date) {
    final local = MaterialLocalizations.of(context);
    return local.formatCompactDate(date) + ' ' +
        local.formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }

  void _notify(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _extend() async {
    if (!widget.canOperate || _busy) return;
    final reason = _reason.text.trim();
    final chosen = _newDate;
    if (chosen == null || reason.isEmpty) {
      setState(() => _error = 'Elige una fecha posterior y escribe el motivo.');
      return;
    }
    final deadline = DateTime(chosen.year, chosen.month, chosen.day, 23, 59, 59, 999);
    if (!deadline.isAfter(DateTime.now()) ||
        (widget.loan.dueAt != null && !deadline.isAfter(widget.loan.dueAt!))) {
      setState(() => _error = 'La nueva fecha debe ser posterior a la actual.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.extend(widget.loan.id, deadline, reason);
      if (mounted) Navigator.of(context).pop(true);
    } on PlatformException catch (error) {
      if (mounted) _notify(error.code == 'loan_not_active'
          ? 'El préstamo ya fue devuelto.'
          : 'No se pudo guardar la prórroga. Revisa los datos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveIncident() async {
    if (!widget.canOperate || _busy) return;
    final detail = _detail.text.trim();
    if (detail.isEmpty) {
      setState(() => _error = 'Describe la incidencia.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.addIncident(widget.loan.id, detail);
      if (!mounted) return;
      _detail.clear();
      _reloadEvents();
      _notify('Incidencia registrada en el folio.');
    } on PlatformException {
      if (mounted) _notify('No se pudo registrar la incidencia.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text('Folio ${loan.folio} · Equipo ${loan.id}')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(loan.equipment, style: Theme.of(context).textTheme.titleLarge),
                  Text('${loan.code} · ${loan.borrower}'),
                  Text('ID de préstamo del equipo: ${loan.id}'),
                  Text(loan.dueAt == null
                      ? 'Sin fecha límite establecida'
                      : 'Fecha límite actual: ' + _format(loan.dueAt!)),
                  const SizedBox(height: 18),
                  if (loan.returnedAt == null && widget.canOperate) ...[
                    Text(loan.dueAt == null ? 'Establecer fecha límite' : 'Registrar prórroga',
                        style: Theme.of(context).textTheme.titleMedium),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(_newDate == null
                          ? 'Elegir nueva fecha'
                          : MaterialLocalizations.of(context).formatCompactDate(_newDate!)),
                    ),
                    TextField(
                      controller: _reason,
                      enabled: !_busy,
                      maxLength: 500,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Motivo de la prórroga',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _extend,
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Guardar nueva fecha'),
                    ),
                    const Divider(height: 36),
                  ],
                  if (widget.canOperate) Text('Registrar incidencia', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (widget.canOperate) TextField(
                    controller: _detail,
                    enabled: !_busy,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción de la incidencia',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (widget.canOperate) FilledButton.tonalIcon(
                    onPressed: _busy ? null : _saveIncident,
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Guardar incidencia'),
                  ),
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const Divider(height: 36),
                  Row(children: [
                    Expanded(child: Text('Bitácora del folio',
                        style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(
                      onPressed: _reloadEvents,
                      tooltip: 'Actualizar bitácora',
                      icon: const Icon(Icons.refresh),
                    ),
                  ]),
                  FutureBuilder<List<LoanEvent>>(
                    future: _events,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) return const Text('No se pudo cargar la bitácora.');
                      final events = snapshot.data ?? [];
                      if (events.isEmpty) {
                        return const Text('Todavía no hay incidencias ni prórrogas registradas.');
                      }
                      return Column(children: [
                        for (final entry in events)
                          ListTile(
                            leading: Icon(entry.type == 'incident'
                                ? Icons.report_problem_outlined
                                : Icons.event_repeat_outlined),
                            title: Text(entry.type == 'incident' ? 'Incidencia' : 'Prórroga'),
                            subtitle: Text(entry.detail + '\n' + _format(entry.createdAt) +
                                (entry.newDueAt == null
                                    ? ''
                                    : '\nNuevo vencimiento: ' + _format(entry.newDueAt!))),
                            isThreeLine: true,
                          ),
                      ]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
