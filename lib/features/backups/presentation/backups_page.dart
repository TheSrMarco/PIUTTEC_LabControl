import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backup_store.dart';

class BackupsPage extends StatefulWidget {
  const BackupsPage({super.key, this.store = const BackupStore()});

  final BackupStore store;

  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  bool _busy = false;

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.store.export();
      if (!mounted) return;
      if (saved) {
        _notify('Respaldo guardado. Conserva el archivo en un lugar seguro.');
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      _notify(
        error.code == 'backup_too_large'
            ? 'El respaldo excede el tamaño admitido (8 MB).'
            : error.code == 'file_picker_unavailable'
                ? 'No hay un selector de documentos disponible.'
                : 'No se pudo exportar el respaldo.',
      );
    } on MissingPluginException {
      if (mounted) _notify('Esta opción requiere la aplicación Android.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: const Text(
          'La restauración solo está permitida si esta instalación no '
          'contiene equipos ni préstamos. No se reemplazarán los datos '
          'actuales. Selecciona un respaldo creado por PIUTTEC LabControl.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Elegir archivo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final restored = await widget.store.restore();
      if (!mounted || restored == null) return;
      _notify(
        'Restaurados ${restored.equipment} equipos y '
        '${restored.loans} préstamos y '
        '${restored.events} eventos de bitácora.',
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      _notify(switch (error.code) {
        'device_not_empty' =>
          'La base local contiene registros. No se modificó ningún dato.',
        'invalid_backup' =>
          'Archivo incompatible, inválido o mayor que 8 MB.',
        'file_picker_unavailable' =>
          'No hay un selector de documentos disponible.',
        _ => 'No se pudo restaurar el archivo. No se aplicó el respaldo.',
      });
    } on MissingPluginException {
      if (mounted) _notify('Esta opción requiere la aplicación Android.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Respaldos')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(
                    Icons.storage_outlined,
                    size: 52,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Protege los registros del laboratorio',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El respaldo incluye las fichas de equipos, sus estados, '
                    'los préstamos, solicitantes, destinos, folios, fechas '
          'límite, incidencias y prórrogas.',
                  ),
                  const SizedBox(height: 20),
                  Card.outlined(
                    child: ListTile(
                      leading: const Icon(Icons.save_alt_outlined),
                      title: const Text('Exportar respaldo'),
                      subtitle: const Text(
                        'Guarda un archivo JSON en la ubicación que elijas.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : _export,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card.outlined(
                    child: ListTile(
                      leading: const Icon(Icons.restore_outlined),
                      title: const Text('Restaurar respaldo'),
                      subtitle: const Text(
                        'Recupera datos únicamente en una instalación vacía.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : _restore,
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  const SizedBox(height: 20),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El archivo JSON no está cifrado y puede contener '
                          'nombres de solicitantes. Guárdalo en una ubicación '
                          'privada. No se sube automáticamente a la nube.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'La exportación no elimina ni modifica los registros. '
                    'La restauración valida el archivo antes de insertarlo '
                    'y no sobrescribe una base de datos ocupada.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
