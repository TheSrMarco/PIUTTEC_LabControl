import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/history/data/history_movement.dart';
import 'package:piuttec_labcontrol/features/loans/data/loan_store.dart';

Loan makeLoan({
  required int id,
  required int lentAt,
  int? returnedAt,
  String code = 'DTIC-01',
  String borrower = 'Ana',
}) => Loan.fromMap({
  'id': id,
  'code': code,
  'name': 'Laptop Dell',
  'borrower': borrower,
  'destination': 'Laboratorio 2',
  'lentAt': lentAt,
  'returnedAt': returnedAt,
});

void main() {
  test('Un préstamo activo genera un solo movimiento', () {
    final movements = buildHistoryMovements([
      makeLoan(id: 1, lentAt: 1000),
    ]);
    expect(movements, hasLength(1));
    expect(movements.single.type, MovementType.loan);
  });

  test('Un préstamo devuelto conserva ambos eventos ordenados por fecha', () {
    final movements = buildHistoryMovements([
      makeLoan(id: 1, lentAt: 1000, returnedAt: 3000),
      makeLoan(id: 2, lentAt: 2000),
    ]);
    expect(movements.map((m) => m.type), [
      MovementType.returnLoan,
      MovementType.loan,
      MovementType.loan,
    ]);
    expect(movements.map((m) => m.occurredAt.millisecondsSinceEpoch), [
      3000,
      2000,
      1000,
    ]);
  });

  test('Filtra devoluciones y busca sin distinguir mayúsculas', () {
    final movements = buildHistoryMovements([
      makeLoan(id: 8, lentAt: 1000, returnedAt: 3000, borrower: 'Ana López'),
      makeLoan(id: 9, lentAt: 2000, borrower: 'Luis'),
    ]);
    final results = filterHistoryMovements(
      movements,
      filter: MovementFilter.returns,
      query: 'ANA',
    );
    expect(results, hasLength(1));
    expect(results.single.loan.id, 8);
    expect(results.single.type, MovementType.returnLoan);
  });
}
