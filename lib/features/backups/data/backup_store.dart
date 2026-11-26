import 'package:flutter/services.dart';

class BackupResult {
  const BackupResult({required this.equipment, required this.loans, this.events = 0});

  final int equipment;
  final int loans;
  final int events;

  factory BackupResult.fromMap(Map<Object?, Object?> map) => BackupResult(
    equipment: (map['equipment'] as num).toInt(),
    loans: (map['loans'] as num).toInt(),
    events: (map['events'] as num?)?.toInt() ?? 0,
  );
}

class BackupStore {
  const BackupStore();

  static const _channel = MethodChannel('mx.edu.uttec.labcontrol/backup');

  /// False indica que el usuario canceló el selector.
  Future<bool> export() async =>
      await _channel.invokeMethod<bool>('exportBackup') ?? false;

  /// Null indica que el usuario canceló el selector.
  Future<BackupResult?> restore() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'restoreBackup',
    );
    return raw == null ? null : BackupResult.fromMap(raw);
  }
}
