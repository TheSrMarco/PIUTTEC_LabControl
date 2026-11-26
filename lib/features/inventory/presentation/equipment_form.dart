import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/equipment_qr.dart';
import '../data/inventory_store.dart';

class EquipmentForm extends StatefulWidget {
  const EquipmentForm({
    super.key,
    required this.store,
    this.equipment,
    this.readOnly = false,
  });

  final bool readOnly;
  final InventoryStore store;
  final Equipment? equipment;

  @override
  State<EquipmentForm> createState() => _EquipmentFormState();
}

class _EquipmentFormState extends State<EquipmentForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.equipment?.code);
  late final _name = TextEditingController(text: widget.equipment?.name);
  late final _serial = TextEditingController(text: widget.equipment?.serial);
  late final _category = TextEditingController(
    text: widget.equipment?.category,
  );
  late final _brand = TextEditingController(text: widget.equipment?.brand);
  late final _model = TextEditingController(text: widget.equipment?.model);
  late EquipmentStatus _status =
      widget.equipment?.status ?? EquipmentStatus.available;
  bool _saving = false;
  String? _error;

  // Paleta alineada con PIUTTEC LabControl
  static const _bgCanvas = Color(0xFFF5F7F6);
  static const _cardBorder = Color(0xFFDFE6E2);
  static const _accentGreen = Color(0xFF1B6B4A);

  bool get _isEditing => widget.equipment != null;

  void _showQr(Equipment equipment) {
    final image = const EquipmentQr().render(equipment.code);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: _accentGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'QR de ${equipment.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                ),
                child: FutureBuilder<Uint8List>(
                  future: image,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No se pudo generar el código QR.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(color: _accentGreen),
                      );
                    }
                    return Image.memory(
                      snapshot.requireData,
                      width: 220,
                      semanticLabel: 'Código QR de ${equipment.code}',
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  equipment.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.8,
                    color: Color(0xFF111815),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _serial.dispose();
    _category.dispose();
    _brand.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.readOnly || _saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final equipment = Equipment(
        code: _code.text.trim(),
        name: _name.text.trim(),
        serial: _serial.text.trim(),
        category: _category.text.trim(),
        brand: _brand.text.trim(),
        model: _model.text.trim(),
        status: _status,
      );
      if (!_isEditing) {
        await widget.store.add(equipment);
      } else {
        await widget.store.update(equipment);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error.code) {
          'duplicate_code' => 'Ese código ya está registrado.',
          'equipment_not_found' => 'El equipo ya no existe en el inventario.',
          'equipment_unavailable' =>
          'Registra la devolución antes de cambiar el estado.',
          'invalid_equipment' =>
          'Revisa el código, el nombre y el número de serie.',
          _ => 'No se pudo guardar el equipo. Intenta de nuevo.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.readOnly
        ? 'Consultar equipo'
        : !_isEditing
        ? 'Registrar equipo'
        : 'Editar equipo';

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: _bgCanvas,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _cardBorder),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            if (widget.equipment case final equipment?)
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
                  onPressed: _saving ? null : () => _showQr(equipment),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text(
                    'Ver QR',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // ── TARJETA 1: IDENTIFICACIÓN PRINCIPAL ──
                    _sectionCard(
                      icon: Icons.tag_rounded,
                      title: 'Identificación del equipo',
                      subtitle: _isEditing
                          ? 'El código de inventario es fijo una vez registrado.'
                          : 'Asigna el código único y el nombre descriptivo.',
                      children: [
                        TextFormField(
                          controller: _code,
                          enabled: !widget.readOnly && !_saving,
                          readOnly: _isEditing,
                          maxLength: 32,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isEditing
                                ? const Color(0xFF5C6B64)
                                : const Color(0xFF111815),
                          ),
                          decoration: _inputDecoration(
                            label: 'Código de inventario *',
                            hint: 'DTIC-R-014',
                            icon: Icons.qr_code_rounded,
                            readOnlyFill: _isEditing,
                          ),
                          validator: (value) {
                            final code = (value ?? '').trim();
                            if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$')
                                .hasMatch(code)) {
                              return 'Usa letras, números, guion o guion bajo.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          enabled: !widget.readOnly && !_saving,
                          maxLength: 80,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Nombre del equipo *',
                            hint: 'Router Cisco ISR 4321',
                            icon: Icons.devices_other_rounded,
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Ingresa el nombre del equipo.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _serial,
                          enabled: !widget.readOnly && !_saving,
                          maxLength: 64,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            label: 'Número de serie (opcional)',
                            hint: 'FDO241910AB',
                            icon: Icons.pin_outlined,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── TARJETA 2: ESPECIFICACIONES TÉCNICAS ──
                    _sectionCard(
                      icon: Icons.tune_rounded,
                      title: 'Especificaciones y clasificación',
                      subtitle: 'Datos opcionales para facilitar búsquedas.',
                      children: [
                        _detailField(
                          controller: _category,
                          label: 'Categoría',
                          hint: 'Redes, Cómputo, Medición…',
                          icon: Icons.category_outlined,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _detailField(
                                controller: _brand,
                                label: 'Marca',
                                hint: 'Cisco, HP, Fluke…',
                                icon: Icons.business_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _detailField(
                                controller: _model,
                                label: 'Modelo',
                                hint: 'ISR4321',
                                icon: Icons.memory_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── TARJETA 3: ESTADO OPERATIVO ──
                    _sectionCard(
                      icon: Icons.verified_outlined,
                      title: 'Disponibilidad en laboratorio',
                      children: [
                        DropdownButtonFormField<EquipmentStatus>(
                          initialValue: _status,
                          decoration: _inputDecoration(
                            label: 'Estado actual',
                            icon: Icons.circle_notifications_outlined,
                          ),
                          items: [
                            for (final status in EquipmentStatus.values)
                              if (status != EquipmentStatus.retired ||
                                  _isEditing)
                                DropdownMenuItem(
                                  value: status,
                                  child: Text(
                                    status.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                          ],
                          onChanged: widget.readOnly || _saving
                              ? null
                              : (value) {
                            if (value != null) {
                              setState(() => _status = value);
                            }
                          },
                        ),
                        if (_status == EquipmentStatus.retired) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.archive_outlined,
                                  size: 18,
                                  color: Color(0xFF475569),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'El equipo se conservará en el registro histórico de bajas y no podrá prestarse.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    // ── BANNER DE ERROR NATIVO ──
                    if (_error case final error?) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFECACA),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 20,
                                color: Color(0xFFB91C1C),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── BOTÓN DE GUARDADO ──
                    if (!widget.readOnly)
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _accentGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _saving
                                ? 'Guardando…'
                                : _isEditing
                                ? 'Guardar cambios'
                                : 'Registrar equipo',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: _accentGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111815),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E7D76),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _detailField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !widget.readOnly && !_saving,
      maxLength: 60,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
    bool readOnlyFill = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF5C6B64)),
      filled: true,
      fillColor: readOnlyFill
          ? const Color(0xFFF0F4F2)
          : const Color(0xFFF7FAF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentGreen, width: 1.6),
      ),
    );
  }
}