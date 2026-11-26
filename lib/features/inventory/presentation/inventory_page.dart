import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/equipment_qr.dart';
import '../data/inventory_store.dart';
import 'equipment_form.dart';

enum _InventoryFilter { all, available, onLoan, maintenance }

enum _InventorySort {
  name('Nombre A-Z'),
  code('Código'),
  status('Estado');

  const _InventorySort(this.label);
  final String label;
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    this.canEdit = true,
    this.onQuickLend,
  });

  final bool canEdit;

  /// Callback opcional para abrir el formulario de préstamo con el equipo preseleccionado.
  final void Function(Equipment equipment)? onQuickLend;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _store = const InventoryStore();
  final _searchCtrl = TextEditingController();
  late Future<List<Equipment>> _equipment = _store.list();

  String _query = '';
  bool _showRetired = false;
  bool _scanning = false;
  _InventoryFilter _filter = _InventoryFilter.all;
  _InventorySort _sort = _InventorySort.name;

  // Paleta alineada con PIUTTEC LabControl
  static const _bgCanvas = Color(0xFFF5F7F6);
  static const _cardBorder = Color(0xFFDFE6E2);
  static const _accentGreen = Color(0xFF1B6B4A);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = _store.list();
    setState(() => _equipment = future);
    await future;
  }

  Future<void> _scanQr() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final payload = await const EquipmentQr().scan();
      if (!mounted || payload == null) return;
      final code = EquipmentQr.readCode(payload);
      if (code == null) {
        _notify('El QR no corresponde a un equipo de PIUTTEC LabControl.');
        return;
      }

      final equipment = await _store.findByCode(code);
      if (!mounted) return;
      if (equipment == null) {
        _notify('El equipo $code no está registrado en este dispositivo.');
        return;
      }
      await _openForm(equipment);
    } on PlatformException catch (error) {
      if (!mounted) return;
      _notify(
        error.code == 'camera_unavailable'
            ? 'La cámara no está disponible en este dispositivo.'
            : 'No se pudo completar la consulta por QR.',
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm([Equipment? equipment]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EquipmentForm(
          store: _store,
          equipment: equipment,
          readOnly: !widget.canEdit,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    await _reload();
    _notify(equipment == null ? 'Equipo registrado.' : 'Ficha actualizada.');
  }

  List<Equipment> _applySort(List<Equipment> items) {
    final list = List<Equipment>.of(items);
    switch (_sort) {
      case _InventorySort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _InventorySort.code:
        list.sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));
      case _InventorySort.status:
        int rank(Equipment e) {
          if (e.isAvailableForLoan) return 0;
          if (e.onLoan) return 1;
          if (e.isMaintenance) return 2;
          return 3;
        }
        list.sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          return r != 0
              ? r
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
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
          'Inventario',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<_InventorySort>(
            tooltip: 'Ordenar inventario',
            icon: const Icon(Icons.sort_rounded, color: Color(0xFF2D3A34)),
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final option in _InventorySort.values)
                PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        _sort == option
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: _sort == option
                            ? _accentGreen
                            : const Color(0xFF7B8A83),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        option.label,
                        style: TextStyle(
                          fontWeight: _sort == option
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentGreen,
                side: const BorderSide(color: _cardBorder),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _scanning ? null : _scanQr,
              icon: _scanning
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accentGreen,
                ),
              )
                  : const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text(
                'Escanear QR',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !widget.canEdit
          ? null
          : FloatingActionButton.extended(
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Registrar equipo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: FutureBuilder<List<Equipment>>(
              future: _equipment,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accentGreen),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 36,
                            color: Color(0xFF6E7D76),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No se pudo cargar el inventario.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111815),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _accentGreen,
                            ),
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final all = snapshot.requireData;
                final activePool = all
                    .where((e) => _showRetired || !e.isRetired)
                    .toList(growable: false);

                final availableCount =
                    activePool.where((e) => e.isAvailableForLoan).length;
                final onLoanCount = activePool.where((e) => e.onLoan).length;
                final maintenanceCount =
                    activePool.where((e) => e.isMaintenance).length;

                final filtered = activePool.where((item) {
                  if (!item.matchesQuery(_query)) return false;
                  return switch (_filter) {
                    _InventoryFilter.all => true,
                    _InventoryFilter.available => item.isAvailableForLoan,
                    _InventoryFilter.onLoan => item.onLoan,
                    _InventoryFilter.maintenance => item.isMaintenance,
                  };
                }).toList(growable: false);

                final visible = _applySort(filtered);

                return Column(
                  children: [
                    // ── CABECERA DE MÉTRICAS, BÚSQUEDA Y FILTROS ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: _cardBorder)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _kpiPill(
                                label: 'Disponibles',
                                value: availableCount,
                                color: _accentGreen,
                                bg: const Color(0xFFE8F5E9),
                              ),
                              const SizedBox(width: 8),
                              _kpiPill(
                                label: 'Prestados',
                                value: onLoanCount,
                                color: const Color(0xFFB45309),
                                bg: const Color(0xFFFFF4E5),
                              ),
                              const SizedBox(width: 8),
                              _kpiPill(
                                label: 'Mantenimiento',
                                value: maintenanceCount,
                                color: const Color(0xFF475569),
                                bg: const Color(0xFFF1F5F9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: Color(0xFF5C6B64),
                              ),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                tooltip: 'Limpiar búsqueda',
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
                              hintText:
                              'Buscar por código, nombre, serie, marca o modelo…',
                              hintStyle: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF7B8A83),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7FAF8),
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
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip(
                                  label: 'Todos (${activePool.length})',
                                  selected: _filter == _InventoryFilter.all,
                                  onTap: () => setState(
                                        () => _filter = _InventoryFilter.all,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _filterChip(
                                  label: 'Disponibles ($availableCount)',
                                  selected:
                                  _filter == _InventoryFilter.available,
                                  onTap: () => setState(
                                        () => _filter = _InventoryFilter.available,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _filterChip(
                                  label: 'En préstamo ($onLoanCount)',
                                  selected: _filter == _InventoryFilter.onLoan,
                                  onTap: () => setState(
                                        () => _filter = _InventoryFilter.onLoan,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _filterChip(
                                  label: 'Mantenimiento ($maintenanceCount)',
                                  selected:
                                  _filter == _InventoryFilter.maintenance,
                                  onTap: () => setState(
                                        () =>
                                    _filter = _InventoryFilter.maintenance,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                setState(() => _showRetired = !_showRetired),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.archive_outlined,
                                    size: 17,
                                    color: Color(0xFF5C6B64),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Incluir equipos dados de baja',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2D3A34),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 28,
                                    child: Switch(
                                      value: _showRetired,
                                      activeThumbColor: _accentGreen,
                                      onChanged: (value) =>
                                          setState(() => _showRetired = value),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── LISTA DE EQUIPOS CON PULL-TO-REFRESH ──
                    Expanded(
                      child: RefreshIndicator(
                        color: _accentGreen,
                        onRefresh: _reload,
                        child: visible.isEmpty
                            ? ListView(
                          physics:
                          const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border:
                                  Border.all(color: _cardBorder),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 30,
                                  color: Color(0xFF7B8A83),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              all.isEmpty
                                  ? 'Registra el primer equipo del laboratorio.'
                                  : _query.isEmpty
                                  ? 'No hay equipos en esta vista.'
                                  : 'No hay equipos que coincidan con la búsqueda.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A5952),
                              ),
                            ),
                          ],
                        )
                            : ListView.separated(
                          physics:
                          const AlwaysScrollableScrollPhysics(),
                          padding:
                          const EdgeInsets.fromLTRB(16, 14, 16, 96),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildEquipmentCard(visible[index]);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiPill({
    required String label,
    required int value,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.white : const Color(0xFF2D3A34),
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: _accentGreen,
      backgroundColor: const Color(0xFFF5F7F6),
      side: BorderSide(
        color: selected ? _accentGreen : _cardBorder,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildEquipmentCard(Equipment item) {
    final (badgeBg, badgeFg, iconData) = switch (true) {
      _ when item.onLoan => (
      const Color(0xFFFFF4E5),
      const Color(0xFFB45309),
      Icons.swap_horiz_rounded,
      ),
      _ when item.status == EquipmentStatus.maintenance => (
      const Color(0xFFFEF3C7),
      const Color(0xFF92400E),
      Icons.build_circle_outlined,
      ),
      _ when item.status == EquipmentStatus.retired => (
      const Color(0xFFF1F5F9),
      const Color(0xFF475569),
      Icons.archive_outlined,
      ),
      _ => (
      const Color(0xFFE8F5E9),
      _accentGreen,
      Icons.inventory_2_outlined,
      ),
    };

    final meta = <String>[
      if (item.brandModelLabel.isNotEmpty) item.brandModelLabel,
      if (item.category.isNotEmpty) item.category,
      if (item.serial.isNotEmpty) 'Serie: ${item.serial}',
    ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openForm(item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, size: 21, color: badgeFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111815),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.code,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D3A34),
                            ),
                          ),
                        ),
                        if (meta.isNotEmpty)
                          Text(
                            meta.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF5C6B64),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (item.isAvailableForLoan && widget.onQuickLend != null)
                IconButton(
                  tooltip: 'Prestar este equipo',
                  onPressed: () => widget.onQuickLend!(item),
                  icon: const Icon(
                    Icons.arrow_outward_rounded,
                    size: 20,
                    color: _accentGreen,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8C9B94),
                ),
            ],
          ),
        ),
      ),
    );
  }
}