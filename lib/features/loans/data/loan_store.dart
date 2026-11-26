import 'package:flutter/services.dart';

class Loan {
  Loan.fromMap(Map<Object?, Object?> row)
    : id = row['id'] as int,
      folio = (row['folio'] as int?) ?? (row['id'] as int),
      code = row['code'] as String,
      equipment = row['name'] as String,
      borrower = row['borrower'] as String,
      destination = row['destination'] as String,
      lentAt = DateTime.fromMillisecondsSinceEpoch(row['lentAt'] as int),
      dueAt = switch (row['dueAt']) {
        final int value => DateTime.fromMillisecondsSinceEpoch(value),
        _ => null,
      },
      returnedAt = switch (row['returnedAt']) {
        final int value => DateTime.fromMillisecondsSinceEpoch(value),
        _ => null,
      };

  final int id;
  final int folio;
  final String code;
  final String equipment;
  final String borrower;
  final String destination;
  final DateTime lentAt;
  final DateTime? returnedAt;
  final DateTime? dueAt;

  bool isOverdue(DateTime now) =>
      returnedAt == null && dueAt != null && now.isAfter(dueAt!);
}

class LoanEvent {
  LoanEvent.fromMap(Map<Object?, Object?> row)
      : id = row['id'] as int,
        type = row['type'] as String,
        detail = row['detail'] as String,
        createdAt = DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
        oldDueAt = switch (row['oldDueAt']) {
          final int value => DateTime.fromMillisecondsSinceEpoch(value),
          _ => null,
        },
        newDueAt = switch (row['newDueAt']) {
          final int value => DateTime.fromMillisecondsSinceEpoch(value),
          _ => null,
        };

  final int id;
  final String type;
  final String detail;
  final DateTime createdAt;
  final DateTime? oldDueAt;
  final DateTime? newDueAt;
}

class LoanStore {
  const LoanStore();

  static const _channel = MethodChannel('mx.edu.uttec.labcontrol/inventory');

  Future<List<Loan>> list() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listLoans',
    );
    return [
      for (final row in rows ?? const <Map<Object?, Object?>>[])
        Loan.fromMap(row),
    ];
  }

  Future<void> lend(
    String code,
    String borrower,
    String destination, {
    DateTime? dueAt,
  }) => _channel.invokeMethod<void>('lend', {
    'code': code,
    'borrower': borrower,
    'destination': destination,
    'dueAt': dueAt?.millisecondsSinceEpoch,
  });

  /// Registra 1 a 25 equipos de manera atómica y devuelve el folio común.
  Future<int> lendMany(
    List<String> codes,
    String borrower,
    String destination, {
    DateTime? dueAt,
  }) async {
    final folio = await _channel.invokeMethod<int>('lendMany', {
      'codes': codes,
      'borrower': borrower,
      'destination': destination,
      'dueAt': dueAt?.millisecondsSinceEpoch,
    });
    if (folio == null) throw StateError('No se recibió el folio del préstamo');
    return folio;
  }

  Future<List<LoanEvent>> listEvents(int id) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listLoanEvents',
      {'id': id},
    );
    return [
      for (final row in rows ?? const <Map<Object?, Object?>>[])
        LoanEvent.fromMap(row),
    ];
  }

  Future<void> extend(int id, DateTime dueAt, String reason) =>
      _channel.invokeMethod<void>('extendLoan', {
        'id': id,
        'dueAt': dueAt.millisecondsSinceEpoch,
        'reason': reason,
      });

  Future<void> addIncident(int id, String detail) =>
      _channel.invokeMethod<void>('addLoanIncident', {
        'id': id,
        'detail': detail,
      });

  Future<void> returnLoan(int id) =>
      _channel.invokeMethod<void>('returnLoan', {'id': id});
}
