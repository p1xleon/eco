import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';

class DashboardStats {
  final double income;
  final double expense;

  const DashboardStats({required this.income, required this.expense});

  double get balance => income - expense;
}

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.whenData((transactions) {
    double income = 0;
    double expense = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }

    return DashboardStats(income: income, expense: expense);
  });
});
