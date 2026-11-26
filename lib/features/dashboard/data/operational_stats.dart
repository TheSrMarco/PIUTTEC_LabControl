import '../../inventory/data/inventory_store.dart';
import '../../loans/data/loan_store.dart';

/// Estadísticas calculadas a partir de la SQLite local (sin datos simulados).
class OperationalStats {
  const OperationalStats({
    required this.totalEquipment,
    required this.available,
    required this.onLoan,
    required this.maintenance,
    required this.retired,
    required this.activeLoans,
    required this.completedLoans,
  });

  final int totalEquipment;
  final int available;
  final int onLoan;
  final int maintenance;
  final int retired;
  final int activeLoans;
  final int completedLoans;

  factory OperationalStats.fromRecords(
    List<Equipment> equipment,
    List<Loan> loans,
  ) {
    var available = 0;
    var onLoan = 0;
    var maintenance = 0;
    var retired = 0;

    for (final item in equipment) {
      // Las categorías de equipos son mutuamente excluyentes.
      switch (item.status) {
        case EquipmentStatus.retired:
          retired++;
        case EquipmentStatus.maintenance:
          maintenance++;
        case EquipmentStatus.available:
          if (item.onLoan) {
            onLoan++;
          } else {
            available++;
          }
      }
    }

    // Los indicadores de préstamos cuentan folios, no equipos individuales.
    final folios = loans.map((loan) => loan.folio).toSet();
    final activeFolios = loans
        .where((loan) => loan.returnedAt == null)
        .map((loan) => loan.folio)
        .toSet();
    final activeLoans = activeFolios.length;
    return OperationalStats(
      totalEquipment: equipment.length,
      available: available,
      onLoan: onLoan,
      maintenance: maintenance,
      retired: retired,
      activeLoans: activeLoans,
      completedLoans: folios.length - activeLoans,
    );
  }

  bool get isEmpty => totalEquipment == 0 && activeLoans == 0 && completedLoans == 0;
}
