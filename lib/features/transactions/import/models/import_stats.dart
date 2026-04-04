class ImportStats {
  final int total;
  final int validCount;
  final int errorCount;
  final double totalIncome;
  final double totalExpense;

  const ImportStats({
    required this.total,
    required this.validCount,
    required this.errorCount,
    required this.totalIncome,
    required this.totalExpense,
  });

  const ImportStats.empty()
    : total = 0,
      validCount = 0,
      errorCount = 0,
      totalIncome = 0,
      totalExpense = 0;
}
