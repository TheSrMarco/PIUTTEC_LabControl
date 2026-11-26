import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/dashboard/data/operational_stats.dart';
import 'package:piuttec_labcontrol/features/inventory/data/inventory_store.dart';
import 'package:piuttec_labcontrol/features/loans/data/loan_store.dart';

Equipment equipment(
  String code, {
  EquipmentStatus status = EquipmentStatus.available,
  bool onLoan = false,
}) => Equipment(
  code: code,
  name: 'Equipo $code',
  serial: '',
  status: status,
  onLoan: onLoan,
);

Loan loan(int id, {int? folio, int? returnedAt}) => Loan.fromMap({
  'id': id,
  if (folio != null) 'folio': folio,
  'code': 'DTIC-$id',
  'name': 'Laptop',
  'borrower': 'Prueba',
  'destination': 'Laboratorio',
  'lentAt': 1000,
  'returnedAt': returnedAt,
});

void main() {
  test('Base vacía muestra todos los indicadores en cero', () {
    final stats = OperationalStats.fromRecords([], []);
    expect(stats.totalEquipment, 0);
    expect(stats.available, 0);
    expect(stats.onLoan, 0);
    expect(stats.maintenance, 0);
    expect(stats.retired, 0);
    expect(stats.activeLoans, 0);
    expect(stats.completedLoans, 0);
    expect(stats.isEmpty, true);
  });

  test('Los estados de los equipos se cuentan sin duplicarlos', () {
    final stats = OperationalStats.fromRecords([
      equipment('01'),
      equipment('02', onLoan: true),
      equipment('03', status: EquipmentStatus.maintenance),
      equipment('04', status: EquipmentStatus.retired),
    ], [
      loan(10),
      loan(11, returnedAt: 2000),
    ]);

    expect(stats.totalEquipment, 4);
    expect(stats.available, 1);
    expect(stats.onLoan, 1);
    expect(stats.maintenance, 1);
    expect(stats.retired, 1);
    expect(stats.activeLoans, 1);
    expect(stats.completedLoans, 1);
    expect(
      stats.available + stats.onLoan + stats.maintenance + stats.retired,
      stats.totalEquipment,
    );
  });

  test('Conserva el total histórico de préstamos devueltos', () {
    final stats = OperationalStats.fromRecords([
      equipment('01'),
    ], [
      loan(1, returnedAt: 2000),
      loan(2, returnedAt: 3000),
    ]);
    expect(stats.activeLoans, 0);
    expect(stats.completedLoans, 2);
    expect(stats.isEmpty, false);
  });
  test('Los indicadores cuentan un folio aunque tenga varios equipos', () {
    final stats = OperationalStats.fromRecords([
      equipment('01', onLoan: true),
      equipment('02', onLoan: true),
      equipment('03'),
    ], [
      loan(20, folio: 12),
      loan(21, folio: 12, returnedAt: 4000),
      loan(22, folio: 12),
      loan(23, folio: 13, returnedAt: 5000),
    ]);
    expect(stats.onLoan, 2);
    expect(stats.activeLoans, 1);
    expect(stats.completedLoans, 1);
  });

}
