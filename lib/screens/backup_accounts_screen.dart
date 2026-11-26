import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/lab_database.dart';
import '../theme/piuttec_theme.dart';
import '../widgets/piuttec_ui.dart';

class BackupAccountsScreen extends StatefulWidget {
  final String laboratorista;
  const BackupAccountsScreen({super.key, required this.laboratorista});

  @override
  State<BackupAccountsScreen> createState() {
    return _BackupAccountsScreenState();
  }
}

class _BackupAccountsScreenState extends State<BackupAccountsScreen> {
  String _ultimoRespaldo = 'Sin respaldos exportados en esta sesión';

  Future<void> _generarYCompartirRespaldo() async {
    final ruta = await LabDatabase.instance.exportarRespaldoSQLite();
    await LabDatabase.instance.registrarAuditoria(
      'RESPALDO_SQLITE',
      null,
      null,
      widget.laboratorista,
      'Copia de seguridad SQLite generada: $ruta',
    );
    setState(() => _ultimoRespaldo = ruta);
    await Share.shareXFiles([XFile(ruta)], text: 'Respaldo PIUTTEC LabControl SQLite');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PiuttecHeader(
            subtitulo: 'Respaldos SQLite y Administración',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionBanner(
                          paso: 'DB',
                          titulo: 'Copia de Seguridad SQLite',
                          icon: Icons.storage_outlined,
                        ),
                        const SizedBox(height: 12),
                        const Text('Exporta la base de datos local con historial de trazabilidad, prórrogas e incidencias.'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Exportar Respaldo (.db)'),
                          onPressed: _generarYCompartirRespaldo,
                        ),
                        const SizedBox(height: 8),
                        Text(_ultimoRespaldo, style: const TextStyle(fontSize: 12, color: PiuttecTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_user, color: PiuttecTheme.primaryGreen),
                    title: Text('Turno activo: ${widget.laboratorista}'),
                    subtitle: const Text('Auditoría de acciones habilitada en SQLite'),
                    trailing: const StatusPill(label: 'ACTIVO', color: PiuttecTheme.primaryGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}