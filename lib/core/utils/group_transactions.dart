import 'package:intl/intl.dart';

import '../../features/transactions/data/models/transaction_model.dart';

Map<String, List<TransactionModel>> groupTransactionsByMonth(
  List<TransactionModel> transactions,
) {
  final Map<String, List<TransactionModel>> grouped = {};

  for (final tx in transactions) {
    final monthKey = DateFormat('MMMM yyyy').format(tx.date);

    grouped.putIfAbsent(monthKey, () => []);
    grouped[monthKey]!.add(tx);
  }

  // Sort transactions inside each month
  for (final list in grouped.values) {
    list.sort((a, b) => b.date.compareTo(a.date));
  }

  // Sort months (latest first)
  final sortedEntries = grouped.entries.toList()
    ..sort((a, b) {
      final dateA = DateFormat('MMMM yyyy').parse(a.key);
      final dateB = DateFormat('MMMM yyyy').parse(b.key);
      return dateB.compareTo(dateA);
    });

  return Map.fromEntries(sortedEntries);
}
