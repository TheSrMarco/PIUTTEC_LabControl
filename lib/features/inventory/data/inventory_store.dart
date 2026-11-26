import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum EquipmentStatus {
  available('Disponible'),
  maintenance('En mantenimiento'),
  retired('Baja');

  const EquipmentStatus(this.label);
  final String label;

  static EquipmentStatus fromRaw(String? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return EquipmentStatus.available;
  }
}

@immutable
class Equipment {
  const Equipment({
    required this.code,
    required this.name,
    this.serial = '',
    this.category = '',
    this.brand = '',
    this.model = '',
    this.status = EquipmentStatus.available,
    this.onLoan = false,
  });

  final String code;
  final String name;
  final String serial;
  final String category;
  final String brand;
  final String model;
  final EquipmentStatus status;
  final bool onLoan;

  /// Verdadero únicamente cuando está disponible en catálogo y no tiene préstamo activo.
  bool get isAvailableForLoan =>
      !onLoan && status == EquipmentStatus.available;

  bool get isMaintenance => !onLoan && status == EquipmentStatus.maintenance;
  bool get isRetired => status == EquipmentStatus.retired;

  String get statusLabel => onLoan ? 'En préstamo' : status.label;

  /// Resumen compacto de marca y modelo (ej. "Cisco · ISR4321").
  String get brandModelLabel {
    final parts = [brand.trim(), model.trim()].where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }

  /// Útil para filtros de búsqueda en inventario y selector de préstamos.
  bool matchesQuery(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return code.toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        serial.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        brand.toLowerCase().contains(q) ||
        model.toLowerCase().contains(q);
  }

  factory Equipment.fromMap(Map<Object?, Object?> data) => Equipment(
    code: (data['code'] as String? ?? '').trim(),
    name: (data['name'] as String? ?? '').trim(),
    serial: (data['serial'] as String? ?? '').trim(),
    category: (data['category'] as String? ?? '').trim(),
    brand: (data['brand'] as String? ?? '').trim(),
    model: (data['model'] as String? ?? '').trim(),
    status: EquipmentStatus.fromRaw(data['status'] as String?),
    onLoan: data['onLoan'] == true || data['onLoan']?.toString() == 'true',
  );

  Map<String, String> toMap() => {
    'code': code.trim(),
    'name': name.trim(),
    'serial': serial.trim(),
    'category': category.trim(),
    'brand': brand.trim(),
    'model': model.trim(),
    'status': status.name,
  };

  Equipment copyWith({
    String? code,
    String? name,
    String? serial,
    String? category,
    String? brand,
    String? model,
    EquipmentStatus? status,
    bool? onLoan,
  }) {
    return Equipment(
      code: code ?? this.code,
      name: name ?? this.name,
      serial: serial ?? this.serial,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      status: status ?? this.status,
      onLoan: onLoan ?? this.onLoan,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Equipment &&
              runtimeType == other.runtimeType &&
              code == other.code &&
              name == other.name &&
              serial == other.serial &&
              category == other.category &&
              brand == other.brand &&
              model == other.model &&
              status == other.status &&
              onLoan == other.onLoan;

  @override
  int get hashCode => Object.hash(
    code,
    name,
    serial,
    category,
    brand,
    model,
    status,
    onLoan,
  );
}

class InventoryStore {
  const InventoryStore();

  static const _channel = MethodChannel('mx.edu.uttec.labcontrol/inventory');

  Future<List<Equipment>> list() async {
    final rows = await _channel.invokeListMethod<Object?>('list');
    return [
      for (final row in rows ?? const <Object?>[])
        Equipment.fromMap(Map<Object?, Object?>.from(row as Map)),
    ];
  }

  /// Devuelve solo los equipos listos para prestarse (disponibles y sin préstamo activo).
  Future<List<Equipment>> listAvailable() async {
    final all = await list();
    return all.where((e) => e.isAvailableForLoan).toList(growable: false);
  }

  /// Busca un equipo exacto por código (útil tras escanear su QR).
  Future<Equipment?> findByCode(String rawCode) async {
    final normalized = rawCode.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final all = await list();
    for (final item in all) {
      if (item.code.toUpperCase() == normalized) return item;
    }
    return null;
  }

  Future<void> add(Equipment equipment) =>
      _channel.invokeMethod<void>('add', equipment.toMap());

  Future<void> update(Equipment equipment) =>
      _channel.invokeMethod<void>('update', equipment.toMap());
}