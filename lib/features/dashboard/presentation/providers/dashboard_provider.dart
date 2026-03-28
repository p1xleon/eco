import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../recurring/domain/services/recurring_transaction_service.dart';
import '../../../recurring/presentation/providers/recurring_transaction_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';

class DashboardStats {
  final double income;
  final double expense;

  const DashboardStats({required this.income, required this.expense});

  double get balance => income - expense;
}

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final transactionsAsync = ref.watch(visibleTransactionsProvider);

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

final dashboardRecurringProvider = FutureProvider<DashboardRecurringSnapshot>((
  ref,
) async {
  final service = ref.read(recurringTransactionServiceProvider);
  return service.getDashboardRecurring();
});
