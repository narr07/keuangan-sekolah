/// Ringkasan keuangan satu tahun anggaran.
class YearSummary {
  final int year;

  /// Sisa saldo dari tahun-tahun sebelumnya (saldo awal tahun).
  final double openingBalance;
  final double income;
  final double expense;

  /// Saldo akhir tahun per sumber dana (kumulatif, termasuk saldo awal).
  final double bosBalance;
  final double otherBalance;

  const YearSummary({
    required this.year,
    required this.openingBalance,
    required this.income,
    required this.expense,
    required this.bosBalance,
    required this.otherBalance,
  });

  double get closingBalance => openingBalance + income - expense;
}
