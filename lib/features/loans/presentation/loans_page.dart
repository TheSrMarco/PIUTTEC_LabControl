import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../inventory/data/inventory_store.dart';
import '../data/loan_group.dart';
import '../data/loan_store.dart';
import 'loan_form.dart';
import 'loan_management_page.dart';

class LoansPage extends StatefulWidget {
  const LoansPage({super.key, this.canOperate = true});

  final bool canOperate;

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  static const _store = LoanStore();
  late Future<List<Loan>> _loans = _store.list();
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'todos'; // 'todos' | 'activos' | 'vencidos' | 'completados'
  bool _busy = false;

  // Paleta alineada con LabControl y LoanForm
  static const _bgCanvas = Color(0xFFF5F7F6);
  static const _cardBorder = Color(0xFFDFE6E2);
  static const _accentGreen = Color(0xFF1B6B4A);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    final updated = _store.list();
    setState(() {
      _loans = updated;
    });
  }

  void _notify(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _newLoan() async {
    if (!widget.canOperate) return;
    setState(() => _busy = true);
    try {
      final inventory = await const InventoryStore().list();
      if (!mounted) return;
      final available = inventory
          .where(
            (item) => item.status == EquipmentStatus.available && !item.onLoan,
      )
          .toList();
      if (available.isEmpty) {
        _notify('No hay equipos disponibles para préstamo.');
        return;
      }
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => LoanForm(store: _store, equipment: available),
        ),
      );
      if (!mounted || saved != true) return;
      _reload();
      _notify('Préstamo registrado.');
    } on PlatformException {
      if (mounted) _notify('No se pudo consultar el inventario.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _return(Loan loan) async {
    if (!widget.canOperate) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Registrar devolución'),
          content: Text(
            '¿Confirmas que recibiste ${loan.equipment} (${loan.code})?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accentGreen),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      await _store.returnLoan(loan.id);
      if (!mounted) return;
      _reload();
      _notify('Devolución registrada.');
    } on PlatformException catch (error) {
      if (!mounted) return;
      _reload();
      _notify(
        error.code == 'loan_not_active'
            ? 'Este préstamo ya no está activo.'
            : 'No se pudo registrar la devolución.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manage(Loan loan) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoanManagementPage(
          loan: loan,
          canOperate: widget.canOperate,
        ),
      ),
    );
    if (mounted && changed == true) _reload();
  }

  Widget _statusBadge({
    required String label,
    required Color bg,
    required Color fg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = MaterialLocalizations.of(context);
    final now = DateTime.now();

    String dateTime(DateTime time) =>
        '${locale.formatCompactDate(time)} · ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';

    return Scaffold(
      backgroundColor: _bgCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _cardBorder),
        ),
        title: const Text(
          'Préstamos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar lista',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: !widget.canOperate
          ? null
          : FloatingActionButton.extended(
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
        onPressed: _busy ? null : _newLoan,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text(
          'Nuevo préstamo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: FutureBuilder<List<Loan>>(
              future: _loans,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accentGreen),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 44,
                            color: colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No se pudieron cargar los préstamos.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allGroups = groupLoansByFolio(snapshot.requireData);
                if (allGroups.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _accentGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.swap_horizontal_circle_outlined,
                              size: 44,
                              color: _accentGreen,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Aún no hay préstamos registrados',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111815),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Toca "Nuevo préstamo" para escanear un QR o capturar una entrega.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5C6B64),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Contadores rápidos
                final activosCount =
                    allGroups.where((g) => !g.isComplete).length;
                final vencidosCount = allGroups
                    .where((g) => g.loans.any((l) => l.isOverdue(now)))
                    .length;
                final completadosCount =
                    allGroups.where((g) => g.isComplete).length;

                // Filtrado por estado y búsqueda
                final filteredGroups = allGroups.where((g) {
                  final hasOverdue = g.loans.any((l) => l.isOverdue(now));
                  if (_filter == 'activos' && g.isComplete) return false;
                  if (_filter == 'vencidos' && !hasOverdue) return false;
                  if (_filter == 'completados' && !g.isComplete) return false;

                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  final matchFolio = g.folio.toString().toLowerCase().contains(q);                  final matchBorrower = g.borrower.toLowerCase().contains(q);
                  final matchDest = g.destination.toLowerCase().contains(q);
                  final matchEquip = g.loans.any(
                        (l) =>
                    l.equipment.toLowerCase().contains(q) ||
                        l.code.toLowerCase().contains(q),
                  );
                  return matchFolio ||
                      matchBorrower ||
                      matchDest ||
                      matchEquip;
                }).toList();

                return RefreshIndicator(
                  color: _accentGreen,
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      // ── BARRA DE BÚSQUEDA Y FILTROS ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              onChanged: (v) =>
                                  setState(() => _query = v.trim()),
                              decoration: InputDecoration(
                                hintText:
                                'Buscar por folio, solicitante, matrícula o equipo…',
                                hintStyle: const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                                suffixIcon: _query.isNotEmpty
                                    ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF9FBFA),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                  const BorderSide(color: _cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                  const BorderSide(color: _cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _accentGreen,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChipPill(
                                    label: 'Todos (${allGroups.length})',
                                    selected: _filter == 'todos',
                                    onTap: () =>
                                        setState(() => _filter = 'todos'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChipPill(
                                    label: 'Activos ($activosCount)',
                                    selected: _filter == 'activos',
                                    onTap: () =>
                                        setState(() => _filter = 'activos'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChipPill(
                                    label: 'Vencidos ($vencidosCount)',
                                    selected: _filter == 'vencidos',
                                    danger: true,
                                    onTap: () =>
                                        setState(() => _filter = 'vencidos'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChipPill(
                                    label: 'Completados ($completadosCount)',
                                    selected: _filter == 'completados',
                                    onTap: () => setState(
                                          () => _filter = 'completados',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      if (filteredGroups.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: const Center(
                            child: Text(
                              'No hay préstamos que coincidan con tu búsqueda.',
                              style: TextStyle(
                                color: Color(0xFF5C6B64),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final group in filteredGroups) ...[
                          _buildFolioCard(
                            context,
                            group: group,
                            now: now,
                            dateTime: dateTime,
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFolioCard(
      BuildContext context, {
        required dynamic group,
        required DateTime now,
        required String Function(DateTime) dateTime,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasOverdue =
    (group.loans as List<Loan>).any((l) => l.isOverdue(now));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasOverdue
              ? colorScheme.error.withValues(alpha: 0.5)
              : _cardBorder,
          width: hasOverdue ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del Folio
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: hasOverdue
                        ? colorScheme.errorContainer
                        : _accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 20,
                    color: hasOverdue ? colorScheme.error : _accentGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Folio ${group.folio}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111815),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.isComplete
                            ? '${group.loans.length} equipo(s) · Todos devueltos'
                            : '${group.activeCount} pendiente(s) · ${group.returnedCount} devuelto(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5C6B64),
                        ),
                      ),
                    ],
                  ),
                ),
                if (group.isComplete)
                  _statusBadge(
                    label: 'Completado',
                    bg: const Color(0xFFE8F5E9),
                    fg: _accentGreen,
                    icon: Icons.check_circle_rounded,
                  )
                else if (hasOverdue)
                  _statusBadge(
                    label: 'Vencido',
                    bg: colorScheme.errorContainer,
                    fg: colorScheme.onErrorContainer,
                    icon: Icons.warning_amber_rounded,
                  )
                else
                  _statusBadge(
                    label: 'Activo',
                    bg: const Color(0xFFFFF4E5),
                    fg: const Color(0xFFB45309),
                    icon: Icons.schedule_rounded,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Bloque con información del solicitante, destino y fecha
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8EFEA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: Color(0xFF5C6B64),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          group.borrower,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2420),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((group.destination as String).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: Color(0xFF5C6B64),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            group.destination,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF3E4C46),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Color(0xFF5C6B64),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Entregado: ${dateTime(group.lentAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5C6B64),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Lista de equipos dentro del folio
            for (final loan in group.loans as List<Loan>) ...[
              _buildEquipmentTile(
                context,
                loan: loan,
                now: now,
                dateTime: dateTime,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentTile(
      BuildContext context, {
        required Loan loan,
        required DateTime now,
        required String Function(DateTime) dateTime,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReturned = loan.returnedAt != null;
    final isOverdue = loan.isOverdue(now);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReturned
            ? const Color(0xFFF9FBFA)
            : isOverdue
            ? colorScheme.errorContainer.withValues(alpha: 0.25)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? colorScheme.error.withValues(alpha: 0.45)
              : _cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReturned
                    ? Icons.check_circle_rounded
                    : Icons.devices_other_rounded,
                size: 18,
                color: isReturned
                    ? _accentGreen
                    : isOverdue
                    ? colorScheme.error
                    : const Color(0xFF3E4C46),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loan.equipment,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111815),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  loan.code,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3A34),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (loan.dueAt != null)
            Text(
              isOverdue
                  ? 'VENCIDO · Fecha límite: ${dateTime(loan.dueAt!)}'
                  : 'Fecha límite: ${dateTime(loan.dueAt!)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                color: isOverdue
                    ? colorScheme.error
                    : const Color(0xFF5C6B64),
              ),
            )
          else if (!isReturned)
            const Text(
              'Sin fecha límite establecida',
              style: TextStyle(fontSize: 12, color: Color(0xFF6E7D76)),
            ),
          if (loan.returnedAt case final returnedAt?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Devuelto: ${dateTime(returnedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _accentGreen,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (!isReturned && widget.canOperate)
                SizedBox(
                  height: 36,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _busy ? null : () => _return(loan),
                    icon: const Icon(Icons.assignment_return_outlined, size: 16),
                    label: const Text(
                      'Devolver equipo',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D3A34),
                    side: const BorderSide(color: _cardBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _busy ? null : () => _manage(loan),
                  icon: const Icon(Icons.event_note_outlined, size: 16),
                  label: const Text(
                    'Plazos e incidencias',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final activeColor =
    danger ? Theme.of(context).colorScheme.error : const Color(0xFF1B6B4A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : const Color(0xFFF3F6F4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFFDFE6E2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF3E4C46),
          ),
        ),
      ),
    );
  }
}