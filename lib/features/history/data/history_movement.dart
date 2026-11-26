import '../../loans/data/loan_store.dart';

enum MovementType { loan, returnLoan }
enum MovementFilter { all, loans, returns }

class HistoryMovement {
  const HistoryMovement({required this.loan, required this.type});

  final Loan loan;
  final MovementType type;

  DateTime get occurredAt =>
      type == MovementType.loan ? loan.lentAt : loan.returnedAt!;

  String get title => type == MovementType.loan
      ? 'Préstamo registrado'
      : 'Devolución registrada';
}

/// Reconstruye eventos cronológicos desde los folios guardados en SQLite.
List<HistoryMovement> buildHistoryMovements(List<Loan> loans) {
  final movements = <HistoryMovement>[];
  for (final loan in loans) {
    movements.add(HistoryMovement(loan: loan, type: MovementType.loan));
    if (loan.returnedAt != null) {
      movements.add(HistoryMovement(loan: loan, type: MovementType.returnLoan));
    }
  }
  movements.sort((a, b) {
    final byDate = b.occurredAt.compareTo(a.occurredAt);
    if (byDate != 0) return byDate;
    return b.loan.id.compareTo(a.loan.id);
  });
  return movements;
}

List<HistoryMovement> filterHistoryMovements(
  List<HistoryMovement> movements, {
  required MovementFilter filter,
  required String query,
}) {
  final search = query.trim().toLowerCase();
  return movements.where((movement) {
    if (filter == MovementFilter.loans &&
        movement.type != MovementType.loan) {
      return false;
    }
    if (filter == MovementFilter.returns &&
        movement.type != MovementType.returnLoan) {
      return false;
    }
    if (search.isEmpty) return true;

    final loan = movement.loan;
    return [
      loan.folio.toString(),
      loan.id.toString(),
      loan.code,
      loan.equipment,
      loan.borrower,
      loan.destination,
    ].any((value) => value.toLowerCase().contains(search));
  }).toList(growable: false);
}
