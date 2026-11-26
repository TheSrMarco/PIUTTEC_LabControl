import 'loan_store.dart';

/// Agrupa movimientos por folio sin perder el ID de préstamo de cada equipo.
/// Los registros migrados desde SQLite v4 conservan folio == id.
class LoanGroup {
  LoanGroup(this.folio, List<Loan> loans)
      : loans = List<Loan>.unmodifiable(loans);

  final int folio;
  final List<Loan> loans;

  int get activeCount =>
      loans.where((loan) => loan.returnedAt == null).length;
  int get returnedCount => loans.length - activeCount;
  bool get isComplete => activeCount == 0;

  String get borrower => loans.first.borrower;
  String get destination => loans.first.destination;
  DateTime get lentAt => loans.first.lentAt;
}

/// Pone arriba los folios con equipos pendientes, ordenados del más reciente.
List<LoanGroup> groupLoansByFolio(List<Loan> loans) {
  final grouped = <int, List<Loan>>{};
  for (final loan in loans) {
    grouped.putIfAbsent(loan.folio, () => []).add(loan);
  }
  final result = [
    for (final entry in grouped.entries)
      LoanGroup(entry.key, entry.value),
  ];
  result.sort((a, b) {
    final active = b.activeCount.compareTo(a.activeCount);
    if (a.isComplete != b.isComplete) {
      return a.isComplete ? 1 : -1;
    }
    if (active != 0 && a.lentAt == b.lentAt) return active;
    final date = b.lentAt.compareTo(a.lentAt);
    return date != 0 ? date : b.folio.compareTo(a.folio);
  });
  return result;
}
