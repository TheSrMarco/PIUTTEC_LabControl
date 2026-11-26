import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/loans/data/loan_group.dart';
import 'package:piuttec_labcontrol/features/loans/data/loan_store.dart';

Loan item({
  required int id,
  int? folio,
  int? returnedAt,
  int lentAt = 1000,
}) => Loan.fromMap({
  'id': id,
  if (folio != null) 'folio': folio,
  'code': 'DTIC-$id',
  'name': 'Equipo $id',
  'borrower': 'Persona',
  'destination': 'Laboratorio',
  'lentAt': lentAt,
  'returnedAt': returnedAt,
  'dueAt': null,
});

void main() {
  test('Agrupa tres equipos bajo un único folio', () {
    final groups = groupLoansByFolio([
      item(id: 42, folio: 30),
      item(id: 43, folio: 30, returnedAt: 4000),
      item(id: 44, folio: 30),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.folio, 30);
    expect(groups.single.loans.map((x) => x.id), [42, 43, 44]);
    expect(groups.single.activeCount, 2);
    expect(groups.single.returnedCount, 1);
  });

  test('Préstamos antiguos mantienen folio igual a ID individual', () {
    final groups = groupLoansByFolio([
      item(id: 1),
      item(id: 2, returnedAt: 3000),
    ]);
    expect(groups.map((group) => group.folio).toSet(), {1, 2});
    expect(groups.first.folio, 1);
    expect(groups.last.isComplete, isTrue);
  });

  test('Ordena folios pendientes antes de los devueltos', () {
    final groups = groupLoansByFolio([
      item(id: 3, folio: 9, lentAt: 3000, returnedAt: 4000),
      item(id: 5, folio: 10, lentAt: 2000),
      item(id: 6, folio: 10, lentAt: 2000),
    ]);
    expect(groups.map((group) => group.folio), [10, 9]);
    expect(groups.first.isComplete, isFalse);
    expect(groups.last.isComplete, isTrue);
  });
}
