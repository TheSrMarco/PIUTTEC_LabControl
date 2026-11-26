import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../database/lab_database.dart';
import '../models/lab_models.dart';
import '../theme/piuttec_theme.dart';
import '../widgets/piuttec_ui.dart';

class InventoryDetailScreen extends StatefulWidget {
  final String laboratorista;
  const InventoryDetailScreen({super.key, required this.laboratorista});

  @override
  State<InventoryDetailScreen> createState() {
    return _InventoryDetailScreenState();
  }
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  List _equipos = [];
  bool _verBajasLogicas = false;
  final _busquedaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarInventario();
  }

  Future<void> _cargarInventario() async {
    final lista = await LabDatabase.instance.listarEquipos(incluirBajas: _verBajasLogicas);
    final filtro = _busquedaCtrl.text.trim().toLowerCase();
    setState(() {
      _equipos = filtro.isEmpty
          ? lista
          : lista.where((e) =>
      e.codigoQr.toLowerCase().contains(filtro) ||
          e.serie.toLowerCase().contains(filtro) ||
          e.categoria.toLowerCase().contains(filtro)).toList();
    });
  }

  void _abrirEscanerQr() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: 400,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Escanear Etiqueta QR del Equipo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) async {
                  final qrLeido = capture.barcodes.first.rawValue;
                  if (qrLeido != null) {
                    Navigator.pop(context);
                    final eq = await LabDatabase.instance.consultarPorQr(qrLeido);
                    if (!mounted) return;
                    if (eq != null) {
                      _verFichaTecnica(eq);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Código $qrLeido no encontrado en inventario')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verFichaTecnica(Equipo eq) {
    final motivoBajaCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Ficha • ${eq.codigoQr}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: QrImageView(data: eq.codigoQr, version: QrVersions.auto),
                ),
              ),
              const SizedBox(height: 12),
              Text('${eq.categoria} - ${eq.marca} ${eq.modelo}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Serie física verificable: ${eq.serie}'),
              const SizedBox(height: 8),
              StatusPill(
                label: eq.estado,
                color: eq.isActive ? PiuttecTheme.primaryGreen : PiuttecTheme.dangerRed,
              ),
              if (!eq.isActive)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Baja lógica: ${eq.motivoBaja}', style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        actions: [
          if (eq.isActive && eq.estado == 'DISPONIBLE')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Baja Lógica • ${eq.codigoQr}'),
                    content: TextField(
                      controller: motivoBajaCtrl,
                      decoration: const InputDecoration(labelText: 'Motivo de baja (conserva historial)'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: PiuttecTheme.dangerRed),
                        onPressed: () async {
                          final motivo = motivoBajaCtrl.text.trim().isEmpty
                              ? 'Baja administrativa'
                              : motivoBajaCtrl.text.trim();
                          await LabDatabase.instance.bajaLogicaEquipo(eq.codigoQr, motivo, widget.laboratorista);
                          if (mounted) Navigator.pop(context);
                          _cargarInventario();
                        },
                        child: const Text('Confirmar Baja'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Baja Lógica', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _dialogoAltaEquipo() {
    final qrCtrl = TextEditingController(text: 'UTTEC-EQ-${DateTime.now().millisecond}');
    final serieCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alta de Equipo en SQLite'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qrCtrl, decoration: const InputDecoration(labelText: 'Código QR Estable')),
              const SizedBox(height: 8),
              TextField(controller: serieCtrl, decoration: const InputDecoration(labelText: 'Número de Serie Físico')),
              const SizedBox(height: 8),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Categoría')),
              const SizedBox(height: 8),
              TextField(controller: marcaCtrl, decoration: const InputDecoration(labelText: 'Marca')),
              const SizedBox(height: 8),
              TextField(controller: modeloCtrl, decoration: const InputDecoration(labelText: 'Modelo')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final nuevo = Equipo(
                codigoQr: qrCtrl.text.trim(),
                serie: serieCtrl.text.trim(),
                categoria: catCtrl.text.trim(),
                marca: marcaCtrl.text.trim(),
                modelo: modeloCtrl.text.trim(),
              );
              await LabDatabase.instance.registrarEquipo(nuevo, widget.laboratorista);
              if (mounted) Navigator.pop(context);
              _cargarInventario();
            },
            child: const Text('Registrar'),
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
            subtitulo: 'Inventario Digital y Consulta QR',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.white), tooltip: 'Escanear QR', onPressed: _abrirEscanerQr),
                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white), tooltip: 'Alta Equipo', onPressed: _dialogoAltaEquipo),
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _busquedaCtrl,
              onChanged: (_) => _cargarInventario(),
              decoration: const InputDecoration(
                labelText: 'Buscar por QR, serie o categoría',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Incluir equipos con baja lógica'),
            value: _verBajasLogicas,
            onChanged: (v) {
              setState(() => _verBajasLogicas = v);
              _cargarInventario();
            },
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _equipos.length,
              itemBuilder: (_, i) {
                final eq = _equipos[i] as Equipo;
                final pillColor = eq.estado == 'DISPONIBLE'
                    ? PiuttecTheme.primaryGreen
                    : (eq.estado == 'PRESTADO' ? PiuttecTheme.warningAmber : PiuttecTheme.dangerRed);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: eq.isActive ? PiuttecTheme.accentMint : Colors.red.shade100,
                      child: Icon(Icons.qr_code, color: eq.isActive ? PiuttecTheme.primaryDark : Colors.red),
                    ),
                    title: Text('${eq.categoria} • ${eq.marca} ${eq.modelo}'),
                    subtitle: Text('QR: ${eq.codigoQr} | Serie: ${eq.serie}'),
                    trailing: StatusPill(label: eq.estado, color: pillColor),
                    onTap: () => _verFichaTecnica(eq),
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