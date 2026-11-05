import '../../../core/utils/money.dart';
import '../../transactions/data/models/transaction_model.dart';

class CollectionTotals {
  final double income;
  final double expense;

  const CollectionTotals({required this.income, required this.expense});

  double get net => roundCents(income - expense);
}

/// Income and expense per collection. Unassigned transactions are left out;
/// collections with no transactions have no entry.
Map<int, CollectionTotals> totalsByCollection(
  Iterable<TransactionModel> transactions,
) {
  final income = <int, double>{};
  final expense = <int, double>{};

  for (final tx in transactions) {
    final id = tx.collectionId;
    if (id == null) continue;
    final bucket = tx.type == TransactionType.income ? income : expense;
    bucket[id] = (bucket[id] ?? 0) + tx.amount;
  }

  return {
    for (final id in {...income.keys, ...expense.keys})
      id: CollectionTotals(
        income: roundCents(income[id] ?? 0),
        expense: roundCents(expense[id] ?? 0),
      ),
  };
}
