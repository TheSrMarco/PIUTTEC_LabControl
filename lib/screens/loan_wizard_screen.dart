import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../database/lab_database.dart';
import '../models/lab_models.dart';
import '../services/evidence_service.dart';
import '../services/sync_queue_service.dart';
import '../theme/piuttec_theme.dart';
import '../widgets/piuttec_ui.dart';
import 'inventory_detail_screen.dart';
import 'return_partial_screen.dart';
import 'traceability_backup_screen.dart';
import 'backup_accounts_screen.dart';

class LoanWizardScreen extends StatefulWidget {
  final String laboratorista;
  final String tabletIp;
  const LoanWizardScreen({super.key, required this.laboratorista, required this.tabletIp});

  @override
  State<LoanWizardScreen> createState() {
    return _LoanWizardScreenState();
  }
}

class _LoanWizardScreenState extends State<LoanWizardScreen> {
  final _folioCtrl = TextEditingController(
    text: 'FOL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
  );
  final _solicitanteCtrl = TextEditingController();
  final _qrEquipoCtrl = TextEditingController();

  String _destinoSeleccionado = 'Laboratorio de Electrónica A';
  int _duracionHoras = 2;
  String? _fotoActualPath;
  double? _latActual;
  double? _lngActual;
  String _estadoGps = 'SIN_CAPTURA';
  final List _equiposEnFolio = [];

  void _escanearEquipoParaPrestar() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SizedBox(
        height: 360,
        child: MobileScanner(
          onDetect: (capture) {
            final code = capture.barcodes.first.rawValue;
            if (code != null) {
              setState(() => _qrEquipoCtrl.text = code);
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  Future<void> _capturarEvidenciaEquipo() async {
    try {
      final res = await EvidenceService.capturarFotoYGps();
      setState(() {
        _fotoActualPath = res.fotoPath;
        _latActual = res.lat;
        _lngActual = res.lng;
        _estadoGps = res.gpsEstado;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _agregarEquipoAlFolio() async {
    if (_solicitanteCtrl.text.trim().isEmpty || _qrEquipoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa matrícula/empleado y código QR del equipo.')),
      );
      return;
    }
    if (_fotoActualPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obligatorio: toma una fotografía individual antes de autorizar.')),
      );
      return;
    }

    final equipo = await LabDatabase.instance.consultarPorQr(_qrEquipoCtrl.text.trim());
    if (equipo == null || !equipo.isActive || equipo.estado != 'DISPONIBLE') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El equipo no existe, está prestado o tiene baja lógica.')),
        );
      }
      return;
    }

    final ahora = DateTime.now();
    final limite = ahora.add(Duration(hours: _duracionHoras)).toIso8601String();

    final detalle = PrestamoDetalle(
      folio: _folioCtrl.text.trim(),
      equipoQr: equipo.codigoQr,
      solicitanteId: _solicitanteCtrl.text.trim(),
      destino: _destinoSeleccionado,
      fechaSalida: ahora.toIso8601String(),
      fechaVencimientoOriginal: limite,
      fechaVencimientoActual: limite,
      fotoEntregaPath: _fotoActualPath!,
      latitud: _latActual,
      longitud: _lngActual,
      gpsEstado: _estadoGps,
      estadoEntrega: 'ENTREGADO',
      syncStatus: 0,
    );

    await LabDatabase.instance.registrarEntregaEquipo(detalle, widget.laboratorista);

    if (_estadoGps == 'FALLO_GPS_INCIDENCIA') {
      await LabDatabase.instance.registrarIncidencia(
        equipoQr: equipo.codigoQr,
        folio: detalle.folio,
        tipo: 'FALLO_GPS',
        descripcion: 'Entrega autorizada sin señal GPS en celular',
        evidenciaPath: _fotoActualPath,
        usuario: widget.laboratorista,
      );
    }

    setState(() {
      _equiposEnFolio.add(detalle);
      _qrEquipoCtrl.clear();
      _fotoActualPath = null;
      _estadoGps = 'SIN_CAPTURA';
    });
  }

  Future<void> _sincronizarConTableta() async {
    try {
      final total = await SyncQueueService.enviarColaATableta(widget.tabletIp, widget.laboratorista);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sincronización local exitosa: $total entregas enviadas.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin conexión con tableta. Evidencias guardadas en cola local.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PiuttecHeader(
            subtitulo: 'Turno: ${widget.laboratorista}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.sync, color: Colors.white),
                  tooltip: 'Sincronizar con Tableta',
                  onPressed: _sincronizarConTableta,
                ),
                IconButton(
                  icon: const Icon(Icons.assignment_return, color: Colors.white),
                  tooltip: 'Devoluciones',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnPartialScreen(laboratorista: widget.laboratorista))),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_2, color: Colors.white),
                  tooltip: 'Inventario QR',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryDetailScreen(laboratorista: widget.laboratorista))),
                ),
                PopupMenuButton<String>(
                  iconColor: Colors.white,
                  onSelected: (opcion) {
                    if (opcion == 'trazabilidad') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TraceabilityBackupScreen(laboratorista: widget.laboratorista)));
                    } else if (opcion == 'respaldos') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BackupAccountsScreen(laboratorista: widget.laboratorista)));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'trazabilidad', child: Text('Historial e Incidencias')),
                    PopupMenuItem(value: 'respaldos', child: Text('Respaldos SQLite')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const SectionBanner(
                            paso: '03',
                            titulo: 'Preparar Préstamo y Solicitante',
                            icon: Icons.assignment_ind_outlined,
                          ),
                          const SizedBox(height: 14),
                          TextField(controller: _folioCtrl, decoration: const InputDecoration(labelText: 'Folio de Préstamo')),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _solicitanteCtrl,
                            decoration: const InputDecoration(labelText: 'Matrícula o No. Empleado (Credencial verificada)'),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _destinoSeleccionado,
                            decoration: const InputDecoration(labelText: 'Destino del Catálogo'),
                            items: const [
                              DropdownMenuItem(value: 'Laboratorio de Electrónica A', child: Text('Laboratorio de Electrónica A')),
                              DropdownMenuItem(value: 'Laboratorio de Redes Cisco', child: Text('Laboratorio de Redes Cisco')),
                              DropdownMenuItem(value: 'Taller de Automatización', child: Text('Taller de Automatización')),
                            ],
                            onChanged: (v) => setState(() => _destinoSeleccionado = v!),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: _duracionHoras,
                            decoration: const InputDecoration(labelText: 'Duración Configurable'),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 Hora')),
                              DropdownMenuItem(value: 2, child: Text('2 Horas')),
                              DropdownMenuItem(value: 4, child: Text('4 Horas')),
                            ],
                            onChanged: (v) => setState(() => _duracionHoras = v!),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionBanner(
                            paso: '04',
                            titulo: 'Fotografía Individual y GPS',
                            icon: Icons.camera_alt_outlined,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _qrEquipoCtrl,
                                  decoration: const InputDecoration(labelText: 'QR del Equipo'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                style: IconButton.styleFrom(backgroundColor: PiuttecTheme.primaryDark),
                                onPressed: _escanearEquipoParaPrestar,
                                icon: const Icon(Icons.qr_code_scanner),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Tomar Foto + Coordenadas GPS'),
                            onPressed: _capturarEvidenciaEquipo,
                          ),
                          if (_fotoActualPath != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(File(_fotoActualPath!), height: 140, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: StatusPill(
                                label: _estadoGps == 'OK'
                                    ? 'GPS OK (${_latActual?.toStringAsFixed(4)}, ${_lngActual?.toStringAsFixed(4)})'
                                    : 'INCIDENCIA GPS REGISTRADA',
                                color: _estadoGps == 'OK' ? PiuttecTheme.primaryGreen : PiuttecTheme.warningAmber,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Confirmar «Entregado» en Folio'),
                            onPressed: _agregarEquipoAlFolio,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_equiposEnFolio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: PiuttecTheme.accentMint,
                      child: ListTile(
                        leading: const Icon(Icons.inventory_outlined, color: PiuttecTheme.primaryDark),
                        title: Text('Folio ${_folioCtrl.text} activo', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${_equiposEnFolio.length} equipo(s) entregados en este folio'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}