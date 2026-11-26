import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../inventory/data/inventory_store.dart';
import '../data/loan_store.dart';

class LoanForm extends StatefulWidget {
  const LoanForm({super.key, required this.store, required this.equipment});

  final LoanStore store;
  final List<Equipment> equipment;

  @override
  State<LoanForm> createState() => _LoanFormState();
}

class _LoanFormState extends State<LoanForm> {
  final _form = GlobalKey<FormState>();

  // Campos del solicitante
  final _nombres = TextEditingController();
  final _apellidoPaterno = TextEditingController();
  final _apellidoMaterno = TextEditingController();
  final _carrera = TextEditingController();
  final _grupo = TextEditingController();
  final _matricula = TextEditingController();
  final _celular = TextEditingController();
  final _correo = TextEditingController();

  // Campos siempre visibles
  final _destination = TextEditingController();
  final _searchEquipment = TextEditingController();
  final Set<String> _codes = {};
  late DateTime _registroFechaHora;
  DateTime? _dueDate;

  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _scannerOpen = true;
  bool _showApplicantSection = false;
  bool _qrApplied = false;
  List<String> _unavailableQrCodes = [];
  String _equipmentFilter = '';

  String? _error;
  bool _saving = false;

  // Paleta limpia alineada con LabControl
  static const _bgCanvas = Color(0xFFF5F7F6);
  static const _cardBorder = Color(0xFFDFE6E2);
  static const _accentGreen = Color(0xFF1B6B4A);

  @override
  void initState() {
    super.initState();
    _registroFechaHora = DateTime.now();
  }

  @override
  void dispose() {
    _scanner.dispose();
    _nombres.dispose();
    _apellidoPaterno.dispose();
    _apellidoMaterno.dispose();
    _carrera.dispose();
    _grupo.dispose();
    _matricula.dispose();
    _celular.dispose();
    _correo.dispose();
    _destination.dispose();
    _searchEquipment.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_scannerOpen || _saving) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        HapticFeedback.mediumImpact();
        _applyQrData(raw.trim());
        break;
      }
    }
  }

  void _applyQrData(String raw) {
    String nombres = '';
    String apellidoPaterno = '';
    String apellidoMaterno = '';
    String carrera = '';
    String grupo = '';
    String matricula = '';
    String celular = '';
    String correo = '';
    String destination = '';
    List<String> scannedCodes = [];

    if (raw.startsWith('{')) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        nombres = (data['nombres'] ?? data['nombre'] ?? '').toString().trim();
        apellidoPaterno = (data['apellidoPaterno'] ??
            data['apellido_paterno'] ??
            data['paterno'] ??
            '')
            .toString()
            .trim();
        apellidoMaterno = (data['apellidoMaterno'] ??
            data['apellido_materno'] ??
            data['materno'] ??
            '')
            .toString()
            .trim();
        carrera = (data['carrera'] ?? '').toString().trim();
        grupo = (data['grupo'] ?? '').toString().trim();
        matricula = (data['matricula'] ?? '').toString().trim();
        celular = (data['celular'] ??
            data['telefono'] ??
            data['numeroCelular'] ??
            '')
            .toString()
            .trim();
        correo = (data['correo'] ??
            data['correoInstitucional'] ??
            data['email'] ??
            '')
            .toString()
            .trim();
        destination =
            (data['destino'] ?? data['destination'] ?? '').toString().trim();

        final rawCodes = data['codigos'] ?? data['codes'] ?? data['codigo'];
        if (rawCodes is List) {
          scannedCodes = rawCodes
              .map((e) => e.toString().trim().toUpperCase())
              .where((e) => e.isNotEmpty)
              .toList();
        } else if (rawCodes != null) {
          scannedCodes = rawCodes
              .toString()
              .split(',')
              .map((e) => e.trim().toUpperCase())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    } else if (raw.contains('|')) {
      final p = raw.split('|');
      nombres = p.isNotEmpty ? p[0].trim() : '';
      apellidoPaterno = p.length > 1 ? p[1].trim() : '';
      apellidoMaterno = p.length > 2 ? p[2].trim() : '';
      carrera = p.length > 3 ? p[3].trim() : '';
      grupo = p.length > 4 ? p[4].trim() : '';
      matricula = p.length > 5 ? p[5].trim() : '';
      celular = p.length > 6 ? p[6].trim() : '';
      correo = p.length > 7 ? p[7].trim() : '';
      destination = p.length > 8 ? p[8].trim() : '';
      if (p.length > 9) {
        scannedCodes = p[9]
            .split(',')
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } else {
      scannedCodes = raw
          .split(',')
          .map((e) => e.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final availableByUpper = <String, String>{
      for (final eq in widget.equipment) eq.code.trim().toUpperCase(): eq.code,
    };

    final matched = <String>{};
    final missing = <String>[];

    for (final code in scannedCodes) {
      final realCode = availableByUpper[code];
      if (realCode != null) {
        if (matched.length < 25) matched.add(realCode);
      } else {
        missing.add(code);
      }
    }

    setState(() {
      if (nombres.isNotEmpty) _nombres.text = nombres;
      if (apellidoPaterno.isNotEmpty) _apellidoPaterno.text = apellidoPaterno;
      if (apellidoMaterno.isNotEmpty) _apellidoMaterno.text = apellidoMaterno;
      if (carrera.isNotEmpty) _carrera.text = carrera;
      if (grupo.isNotEmpty) _grupo.text = grupo;
      if (matricula.isNotEmpty) _matricula.text = matricula;
      if (celular.isNotEmpty) _celular.text = celular;
      if (correo.isNotEmpty) _correo.text = correo;
      if (destination.isNotEmpty) _destination.text = destination;

      _registroFechaHora = DateTime.now();

      if (scannedCodes.isNotEmpty) {
        _codes
          ..clear()
          ..addAll(matched);
      }

      _unavailableQrCodes = missing;
      _scannerOpen = false;
      _showApplicantSection = true;
      _qrApplied = true;
      _error = null;
    });
  }

  Future<void> _chooseDueDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 10, 12, 31),
      helpText: 'Fecha límite de devolución',
    );
    if (!mounted || picked == null) return;
    setState(() => _dueDate = picked);
  }

  String _buildBorrowerSummary() {
    final fullName = [
      _nombres.text.trim(),
      _apellidoPaterno.text.trim(),
      _apellidoMaterno.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final extras = <String>[
      if (_matricula.text.trim().isNotEmpty) 'Mat: ${_matricula.text.trim()}',
      if (_carrera.text.trim().isNotEmpty) _carrera.text.trim(),
      if (_grupo.text.trim().isNotEmpty) 'Grupo: ${_grupo.text.trim()}',
      if (_celular.text.trim().isNotEmpty) 'Cel: ${_celular.text.trim()}',
      if (_correo.text.trim().isNotEmpty) _correo.text.trim(),
    ];

    if (extras.isEmpty) return fullName;
    return '$fullName (${extras.join(' · ')})';
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_showApplicantSection) {
      setState(() {
        _error =
        'Escanea un QR o presiona "Llenar manualmente" para capturar los datos del solicitante.';
      });
      return;
    }
    if (_codes.isEmpty || _codes.length > 25) {
      setState(() => _error = 'Selecciona entre 1 y 25 equipos.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.lendMany(
        _codes.toList(),
        _buildBorrowerSummary(),
        _destination.text.trim(),
        dueAt: _dueDate == null
            ? null
            : DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          23,
          59,
          59,
          999,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.code == 'equipment_unavailable'
            ? 'Alguno de los equipos dejó de estar disponible. No se registró ninguno.'
            : 'No se pudo registrar (${error.code}): ${error.message ?? 'sin detalle'}';
      });
    }

  }

  InputDecoration _inputStyle(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: const Color(0xFFF9FBFA),
      counterText: '',
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

  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: _accentGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111815),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5C6B64),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFEDF1EF)),
          ),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = MaterialLocalizations.of(context);
    final fechaHoraTexto =
        '${locale.formatCompactDate(_registroFechaHora)} · '
        '${locale.formatTimeOfDay(TimeOfDay.fromDateTime(_registroFechaHora))}';

    final filteredEquipment = _equipmentFilter.isEmpty
        ? widget.equipment
        : widget.equipment.where((eq) {
      final q = _equipmentFilter.toLowerCase();
      return eq.name.toLowerCase().contains(q) ||
          eq.code.toLowerCase().contains(q);
    }).toList();

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
          title: const Text(
            'Nuevo préstamo',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            if (_scannerOpen)
              IconButton(
                icon: const Icon(Icons.flash_on_rounded),
                tooltip: 'Linterna',
                onPressed: _saving ? null : () => _scanner.toggleTorch(),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _cardBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          _saving
                              ? 'Registrando préstamo…'
                              : 'Registrar préstamo (${_codes.length})',
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
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    // ── TARJETA 1: LECTOR QR + BOTÓN LLENAR MANUALMENTE ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Column(
                        children: [
                          if (_scannerOpen) ...[
                            Container(
                              height: 210,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _accentGreen,
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  MobileScanner(
                                    controller: _scanner,
                                    onDetect: _onBarcodeDetected,
                                  ),
                                  Center(
                                    child: Container(
                                      width: 145,
                                      height: 145,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    left: 16,
                                    right: 16,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.72),
                                          borderRadius:
                                          BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Escanea el QR para autollenar el formulario',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _accentGreen,
                                  side: const BorderSide(color: _accentGreen),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _saving
                                    ? null
                                    : () => setState(() {
                                  _scannerOpen = false;
                                  _showApplicantSection = true;
                                  _error = null;
                                }),
                                icon: const Icon(Icons.edit_note_rounded),
                                label: const Text(
                                  'Llenar manualmente',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _accentGreen,
                                      side: const BorderSide(
                                        color: _accentGreen,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                        setState(() => _scannerOpen = true),
                                    icon: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                    ),
                                    label: Text(
                                      _qrApplied
                                          ? 'Volver a escanear QR'
                                          : 'Abrir escáner QR',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── TARJETA 2: DATOS DEL SOLICITANTE (AL ESCANEAR O LLENAR MANUAL) ──
                    if (_showApplicantSection) ...[
                      const SizedBox(height: 14),
                      _sectionCard(
                        icon: Icons.person_outline_rounded,
                        title: 'Datos del solicitante',
                        subtitle: _qrApplied
                            ? 'Autollenado por QR · Editable'
                            : 'Captura manual',
                        trailing: _qrApplied
                            ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'QR listo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _accentGreen,
                            ),
                          ),
                        )
                            : null,
                        children: [
                          if (_unavailableQrCodes.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Códigos del QR no disponibles: ${_unavailableQrCodes.join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          TextFormField(
                            controller: _nombres,
                            enabled: !_saving,
                            maxLength: 60,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputStyle(
                              'Nombres *',
                              icon: Icons.badge_outlined,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Escribe el nombre o nombres.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _apellidoPaterno,
                                  enabled: !_saving,
                                  maxLength: 40,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _inputStyle('Apellido paterno *'),
                                  validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Requerido.'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _apellidoMaterno,
                                  enabled: !_saving,
                                  maxLength: 40,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _inputStyle('Apellido materno *'),
                                  validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Requerido.'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _carrera,
                                  enabled: !_saving,
                                  maxLength: 60,
                                  textCapitalization:
                                  TextCapitalization.characters,
                                  decoration: _inputStyle(
                                    'Carrera *',
                                    icon: Icons.school_outlined,
                                  ),
                                  validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Ingresa la carrera.'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _grupo,
                                  enabled: !_saving,
                                  maxLength: 20,
                                  textCapitalization:
                                  TextCapitalization.characters,
                                  decoration: _inputStyle('Grupo *'),
                                  validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Requerido.'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _matricula,
                                  enabled: !_saving,
                                  maxLength: 20,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputStyle(
                                    'Matrícula *',
                                    icon: Icons.pin_outlined,
                                  ),
                                  validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Ingresa la matrícula.'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _celular,
                                  enabled: !_saving,
                                  maxLength: 15,
                                  keyboardType: TextInputType.phone,
                                  decoration: _inputStyle(
                                    'Celular *',
                                    icon: Icons.phone_android_outlined,
                                  ),
                                  validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Ingresa el celular.'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _correo,
                            enabled: !_saving,
                            maxLength: 80,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputStyle(
                              'Correo institucional *',
                              icon: Icons.alternate_email_rounded,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa el correo institucional.';
                              }
                              if (!v.contains('@')) {
                                return 'Ingresa un correo válido.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    // ── TARJETA 3: DESTINO, FECHA AUTOMÁTICA Y FECHA LÍMITE (SIEMPRE VISIBLES) ──
                    _sectionCard(
                      icon: Icons.schedule_rounded,
                      title: 'Detalles de entrega',
                      subtitle: 'Registro automático y condiciones del folio',
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F7F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_filled_rounded,
                                size: 19,
                                color: _accentGreen,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Fecha y hora de registro',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF5C6B64),
                                      ),
                                    ),
                                    Text(
                                      fechaHoraTexto,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111815),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Actualizar hora actual',
                                onPressed: _saving
                                    ? null
                                    : () => setState(
                                      () => _registroFechaHora =
                                      DateTime.now(),
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                  color: _accentGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _destination,
                          enabled: !_saving,
                          maxLength: 80,
                          decoration: _inputStyle(
                            'Destino (opcional)',
                            icon: Icons.place_outlined,
                            hint: 'Ej. Laboratorio de Redes, Aula B-12',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FBFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_available_outlined,
                                size: 20,
                                color: Color(0xFF5C6B64),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Fecha límite de devolución',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF5C6B64),
                                      ),
                                    ),
                                    Text(
                                      _dueDate == null
                                          ? 'Sin establecer'
                                          : locale.formatCompactDate(_dueDate!),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _saving ? null : _chooseDueDate,
                                child: Text(
                                  _dueDate == null ? 'Elegir' : 'Cambiar',
                                ),
                              ),
                              if (_dueDate != null)
                                IconButton(
                                  tooltip: 'Quitar fecha límite',
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() => _dueDate = null),
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── TARJETA 4: SELECCIÓN DE EQUIPOS CON BUSCADOR ──
                    _sectionCard(
                      icon: Icons.devices_other_rounded,
                      title: 'Equipos disponibles',
                      subtitle: 'Selecciona hasta 25 equipos para este folio',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _codes.isEmpty
                              ? const Color(0xFFF0F3F1)
                              : _accentGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_codes.length}/25',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _codes.isEmpty
                                ? const Color(0xFF5C6B64)
                                : Colors.white,
                          ),
                        ),
                      ),
                      children: [
                        TextField(
                          controller: _searchEquipment,
                          enabled: !_saving,
                          onChanged: (val) =>
                              setState(() => _equipmentFilter = val.trim()),
                          decoration: _inputStyle(
                            'Filtrar equipo por nombre o código',
                            icon: Icons.search_rounded,
                          ).copyWith(
                            suffixIcon: _equipmentFilter.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchEquipment.clear();
                                setState(() => _equipmentFilter = '');
                              },
                            )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (filteredEquipment.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No se encontraron equipos con ese filtro.',
                                style: TextStyle(
                                  color: Color(0xFF5C6B64),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          for (final equipment in filteredEquipment) ...[
                            Builder(
                              builder: (context) {
                                final isSelected =
                                _codes.contains(equipment.code);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _accentGreen.withValues(alpha: 0.06)
                                        : const Color(0xFFF9FBFA),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? _accentGreen
                                          : _cardBorder,
                                      width: isSelected ? 1.4 : 1,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    key: ValueKey('select-${equipment.code}'),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 2,
                                    ),
                                    controlAffinity:
                                    ListTileControlAffinity.leading,
                                    activeColor: _accentGreen,
                                    title: Text(
                                      equipment.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      equipment.code,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF5C6B64),
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: _saving
                                        ? null
                                        : (selected) => setState(() {
                                      if (selected == true) {
                                        if (_codes.length < 25) {
                                          _codes.add(equipment.code);
                                        }
                                      } else {
                                        _codes.remove(equipment.code);
                                      }
                                      _error = null;
                                    }),
                                  ),
                                );
                              },
                            ),
                          ],
                      ],
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
}