import 'package:intl/intl.dart';

import '../../features/transactions/data/models/transaction_model.dart';

final DateFormat _monthKeyFormatter = DateFormat('MMMM yyyy');

List<TransactionMonthGroup> groupTransactionsByMonth(
  List<TransactionModel> transactions,
) {
  final Map<int, List<TransactionModel>> grouped = {};

  for (final tx in transactions) {
    final monthKey = tx.date.year * 100 + tx.date.month;

    grouped.putIfAbsent(monthKey, () => []);
    grouped[monthKey]!.add(tx);
  }

  for (final list in grouped.values) {
    list.sort((a, b) => b.date.compareTo(a.date));
  }

  final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

  return sortedKeys
      .map((key) {
        final year = key ~/ 100;
        final month = key % 100;
        final monthTransactions = grouped[key]!;

        double income = 0;
        double expense = 0;
        for (final tx in monthTransactions) {
          if (tx.type == TransactionType.income) {
            income += tx.amount;
          } else {
            expense += tx.amount;
          }
        }

        return TransactionMonthGroup(
          title: _monthKeyFormatter.format(DateTime(year, month)),
          transactions: monthTransactions,
          income: income,
          expense: expense,
        );
      })
      .toList(growable: false);
}

class TransactionMonthGroup {
  final String title;
  final List<TransactionModel> transactions;
  final double income;
  final double expense;

  const TransactionMonthGroup({
    required this.title,
    required this.transactions,
    required this.income,
    required this.expense,
  });
}
