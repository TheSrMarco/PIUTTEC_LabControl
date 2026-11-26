import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/lab_database.dart';
import '../theme/piuttec_theme.dart';
import '../widgets/piuttec_ui.dart';

class TraceabilityBackupScreen extends StatefulWidget {
  final String laboratorista;
  const TraceabilityBackupScreen({super.key, required this.laboratorista});

  @override
  State<TraceabilityBackupScreen> createState() {
    return _TraceabilityBackupScreenState();
  }
}

class _TraceabilityBackupScreenState extends State<TraceabilityBackupScreen> {
  List _logs = [];
  List _incidencias = [];

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    final db = await LabDatabase.instance.database;
    final logs = await db.query('trazabilidad', orderBy: 'id DESC', limit: 100);
    final inc = await db.query('incidencias', orderBy: 'id DESC', limit: 50);
    setState(() {
      _logs = logs;
      _incidencias = inc;
    });
  }

  Future<void> _exportarRespaldo() async {
    final path = await LabDatabase.instance.exportarRespaldoSQLite();
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Respaldo SQLite PIUTTEC LabControl',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            PiuttecHeader(
              subtitulo: 'Historial Auditable e Incidencias',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    tooltip: 'Exportar Respaldo SQLite',
                    onPressed: _exportarRespaldo,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              color: PiuttecTheme.primaryDark,
              child: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Historial Auditable'),
                  Tab(text: 'Incidencias'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) {
                      final item = _logs[i] as Map;
                      final titulo = item['equipo_qr'] ?? item['folio'] ?? '';
                      final fecha = item['fecha'].toString().substring(0, 16);
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.history, color: PiuttecTheme.primaryGreen),
                          title: Text('${item['accion']} • $titulo'),
                          subtitle: Text(
                            '${item['detalle']}\nPor: ${item['usuario']} • $fecha',
                          ),
                        ),
                      );
                    },
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _incidencias.length,
                    itemBuilder: (ctx, i) {
                      final inc = _incidencias[i] as Map;
                      final fecha = inc['fecha'].toString().substring(0, 16);
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber, color: PiuttecTheme.dangerRed),
                          title: Text('${inc['tipo']} • ${inc['equipo_qr'] ?? ''}'),
                          subtitle: Text(
                            '${inc['descripcion']}\nFecha: $fecha',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}