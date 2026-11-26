import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../database/lab_database.dart';
import '../services/sync_queue_service.dart';
import '../theme/piuttec_theme.dart';
import '../widgets/piuttec_ui.dart';
import 'inventory_detail_screen.dart';
import 'return_partial_screen.dart';
import 'traceability_backup_screen.dart';
import 'backup_accounts_screen.dart';
import 'loan_wizard_screen.dart';

class TabletDashboardScreen extends StatefulWidget {
  final String laboratorista;
  const TabletDashboardScreen({super.key, required this.laboratorista});

  @override
  State<TabletDashboardScreen> createState() {
    return _TabletDashboardScreenState();
  }
}

class _TabletDashboardScreenState extends State<TabletDashboardScreen> {
  String _serverStatus = 'Iniciando red local...';
  String _ipParaQr = '192.168.1.50';
  int _disponibles = 0;
  int _prestados = 0;
  int _revision = 0;
  List _movimientosRecientes = [];

  @override
  void initState() {
    super.initState();
    _cargarPanel();
  }

  Future<void> _cargarPanel() async {
    final status = await SyncQueueService.iniciarServidorTableta();
    final equipos = await LabDatabase.instance.listarEquipos();
    final db = await LabDatabase.instance.database;
    final logs = await db.query('trazabilidad', orderBy: 'id DESC', limit: 6);

    setState(() {
      _serverStatus = status;
      _disponibles = equipos.where((e) => e.estado == 'DISPONIBLE').length;
      _prestados = equipos.where((e) => e.estado == 'PRESTADO').length;
      _revision = equipos.where((e) => e.estado == 'EN_REVISION').length;
      _movimientosRecientes = logs;
    });
  }

  void _mostrarQrVinculacion() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vincular Celular a Tableta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Escanea este QR temporal desde el celular al iniciar turno:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: 170,
              height: 170,
              child: QrImageView(data: _ipParaQr, version: QrVersions.auto),
            ),
            const SizedBox(height: 8),
            Text(_serverStatus, style: const TextStyle(fontWeight: FontWeight.bold, color: PiuttecTheme.primaryGreen)),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Barra lateral institucional tipo Tableta (Diapositivas 26-28)
          Container(
            width: 230,
            color: PiuttecTheme.primaryDark,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: const Text('π', style: TextStyle(color: PiuttecTheme.primaryDark, fontSize: 20, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('PIUTTEC\nLabControl', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, height: 1.15)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  _navItem(Icons.dashboard, 'Panel Principal', () => _cargarPanel()),
                  _navItem(Icons.add_box_outlined, 'Nuevo Préstamo', () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => LoanWizardScreen(laboratorista: widget.laboratorista, tabletIp: '127.0.0.1')));
                    _cargarPanel();
                  }),
                  _navItem(Icons.inventory_2_outlined, 'Inventario y QR', () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryDetailScreen(laboratorista: widget.laboratorista)));
                    _cargarPanel();
                  }),
                  _navItem(Icons.assignment_return_outlined, 'Devoluciones y Prórrogas', () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnPartialScreen(laboratorista: widget.laboratorista)));
                    _cargarPanel();
                  }),
                  _navItem(Icons.history, 'Historial e Incidencias', () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraceabilityBackupScreen(laboratorista: widget.laboratorista)))),
                  _navItem(Icons.backup_outlined, 'Respaldos y Cuentas', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BackupAccountsScreen(laboratorista: widget.laboratorista)))),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('QR de Vínculo'),
                      onPressed: _mostrarQrVinculacion,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Área principal operativa
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Panel de Control Operativo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Turno activo: ${widget.laboratorista}', style: const TextStyle(fontSize: 12, color: PiuttecTheme.textMuted)),
                        ],
                      ),
                      Row(
                        children: [
                          StatusPill(label: _serverStatus, color: PiuttecTheme.primaryGreen),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarPanel),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _kpiCard('Equipos Disponibles', '$_disponibles', Icons.check_circle_outline, PiuttecTheme.primaryGreen),
                            const SizedBox(width: 12),
                            _kpiCard('En Préstamo Activo', '$_prestados', Icons.swap_horiz, PiuttecTheme.warningAmber),
                            const SizedBox(width: 12),
                            _kpiCard('En Revisión / Incidencia', '$_revision', Icons.build_circle_outlined, PiuttecTheme.dangerRed),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Movimientos Recientes y Trazabilidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const Divider(),
                                if (_movimientosRecientes.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('Sin movimientos registrados en este turno.'),
                                  ),
                                ..._movimientosRecientes.map((raw) {
                                  final log = raw as Map;
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.fiber_manual_record, size: 12, color: PiuttecTheme.primaryGreen),
                                    title: Text('${log['accion']} • ${log['equipo_qr'] ?? log['folio'] ?? ''}'),
                                    subtitle: Text(log['detalle'].toString()),
                                    trailing: Text(log['fecha'].toString().substring(11, 16), style: const TextStyle(color: PiuttecTheme.textMuted)),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      onTap: onTap,
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  Text(title, style: const TextStyle(fontSize: 12, color: PiuttecTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}