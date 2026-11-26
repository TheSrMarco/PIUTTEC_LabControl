import 'package:flutter/material.dart';
import '../database/lab_database.dart';
import '../models/lab_models.dart';
import '../services/evidence_service.dart';
import '../theme/piuttec_theme.dart';
import '../widgets/piuttec_ui.dart';

class ReturnPartialScreen extends StatefulWidget {
  final String laboratorista;
  const ReturnPartialScreen({super.key, required this.laboratorista});

  @override
  State<ReturnPartialScreen> createState() {
    return _ReturnPartialScreenState();
  }
}

class _ReturnPartialScreenState extends State<ReturnPartialScreen> {
  final _buscarCtrl = TextEditingController();
  List _prestamosActivos = [];

  @override
  void initState() {
    super.initState();
    _cargarPrestamos();
  }

  Future<void> _cargarPrestamos() async {
    final db = await LabDatabase.instance.database;
    final q = _buscarCtrl.text.trim();
    final rows = await db.query(
      'prestamos_detalle',
      where: q.isEmpty
          ? "estado_entrega = 'ENTREGADO'"
          : "estado_entrega = 'ENTREGADO' AND (folio LIKE ? OR equipo_qr LIKE ? OR solicitante_id LIKE ?)",
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'],
      orderBy: 'id DESC',
    );
    setState(() => _prestamosActivos = rows.map((r) => PrestamoDetalle.fromMap(r)).toList());
  }

  Future<void> _procesarDevolucion(PrestamoDetalle item, bool reportarDano) async {
    try {
      final evidencia = await EvidenceService.capturarFotoYGps();
      await LabDatabase.instance.registrarDevolucionIndividual(
        detalleId: item.id!,
        folio: item.folio,
        equipoQr: item.equipoQr,
        fotoDevolucionPath: evidencia.fotoPath!,
        conDano: reportarDano,
        descripcionDano: reportarDano ? 'Equipo marcado EN_REVISION al momento de devolución' : null,
        laboratista: widget.laboratorista,
      );
      _cargarPrestamos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recepción registrada para ${item.equipoQr}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _devolverTodoElFolio(String folio) async {
    try {
      final evidencia = await EvidenceService.capturarFotoYGps();
      final itemsFolio = _prestamosActivos.where((e) => (e as PrestamoDetalle).folio == folio).toList();
      for (final raw in itemsFolio) {
        final item = raw as PrestamoDetalle;
        await LabDatabase.instance.registrarDevolucionIndividual(
          detalleId: item.id!,
          folio: item.folio,
          equipoQr: item.equipoQr,
          fotoDevolucionPath: evidencia.fotoPath!,
          conDano: false,
          laboratista: widget.laboratorista,
        );
      }
      _cargarPrestamos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folio $folio devuelto por completo (${itemsFolio.length} equipos).')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _abrirProrroga(PrestamoDetalle item) {
    final motivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Prórroga • ${item.equipoQr}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vencimiento original: ${item.fechaVencimientoOriginal.substring(11, 16)} hrs'),
            const SizedBox(height: 10),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(labelText: 'Motivo de la prórroga (obligatorio)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (motivoCtrl.text.trim().isEmpty) return;
              final nuevo = DateTime.parse(item.fechaVencimientoActual).add(const Duration(hours: 1)).toIso8601String();
              await LabDatabase.instance.registrarProrroga(
                detalleId: item.id!,
                folio: item.folio,
                equipoQr: item.equipoQr,
                vencimientoAnterior: item.fechaVencimientoActual,
                nuevoVencimiento: nuevo,
                motivo: motivoCtrl.text.trim(),
                laboratista: widget.laboratorista,
              );
              if (mounted) Navigator.pop(context);
              _cargarPrestamos();
            },
            child: const Text('Autorizar +1 Hora'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PiuttecHeader(
            subtitulo: 'Devoluciones Parciales y Prórrogas',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _buscarCtrl,
              onChanged: (_) => _cargarPrestamos(),
              decoration: const InputDecoration(
                labelText: 'Filtrar por Folio, QR de equipo o Solicitante',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _prestamosActivos.length,
              itemBuilder: (_, i) {
                final item = _prestamosActivos[i] as PrestamoDetalle;
                final vencido = DateTime.now().isAfter(DateTime.parse(item.fechaVencimientoActual));
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.folio} • ${item.equipoQr}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            StatusPill(
                              label: vencido ? 'VENCIDO' : 'EN PRÉSTAMO',
                              color: vencido ? PiuttecTheme.dangerRed : PiuttecTheme.warningAmber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Solicitante: ${item.solicitanteId} | Destino: ${item.destino}'),
                        Text('Vencimiento actual: ${item.fechaVencimientoActual.substring(11, 16)} hrs'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Devolver Equipo'),
                              onPressed: () => _procesarDevolucion(item, false),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.done_all, size: 18),
                              label: const Text('Devolver Folio'),
                              onPressed: () => _devolverTodoElFolio(item.folio),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.report_problem, size: 18, color: Colors.red),
                              label: const Text('Con Daño', style: TextStyle(color: Colors.red)),
                              onPressed: () => _procesarDevolucion(item, true),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.more_time),
                              label: const Text('Prórroga'),
                              onPressed: () => _abrirProrroga(item),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}