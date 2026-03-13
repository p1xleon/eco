import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/transaction_model.dart';
import 'transaction_provider.dart';
import '../models/month_group.dart';

final monthGroupsProvider = Provider<AsyncValue<List<MonthGroup>>>((ref) {
  final transactionsAsync = ref.watch(filteredTransactionsProvider);

  return transactionsAsync.whenData((transactions) {
    final Map<String, List<TransactionModel>> grouped = {};

    for (final tx in transactions) {
      final key = DateFormat('MMMM').format(tx.date);

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
    }

    final result = <MonthGroup>[];

    grouped.forEach((month, list) {
      double income = 0;
      double expense = 0;

      for (final tx in list) {
        if (tx.type == TransactionType.income) {
          income += tx.amount;
        } else {
          expense += tx.amount;
        }
      }

      result.add(
        MonthGroup(
          month: month,
          income: income,
          expense: expense,
          transactions: list,
        ),
      );
    });

    return result;
  });
});
