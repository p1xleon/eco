import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/providers/transaction_repository_provider.dart';
import 'transaction_filter_provider.dart';

final transactionsProvider = FutureProvider<List<TransactionModel>>((
  ref,
) async {
  ref.watch(authStateProvider);
  final repo = ref.read(transactionRepositoryProvider);
  return repo.getAll();
});

final filteredTransactionsProvider =
    Provider<AsyncValue<List<TransactionModel>>>((ref) {
      final transactionsAsync = ref.watch(transactionsProvider);
      final filter = ref.watch(transactionFilterProvider);

      return transactionsAsync.whenData((transactions) {
        return transactions.where((tx) {
          if (filter.search.isNotEmpty) {
            final search = filter.search.toLowerCase();
            final matches = [
              tx.title,
              tx.paymentMethod,
              tx.payee,
              tx.note,
            ].whereType<String>().any((value) {
              return value.toLowerCase().contains(search);
            });

            if (!matches) {
              return false;
            }
          }

          if (filter.type != null && tx.type != filter.type) {
            return false;
          }

          if (filter.categoryId != null && tx.categoryId != filter.categoryId) {
            return false;
          }

          if (filter.startDate != null && tx.date.isBefore(filter.startDate!)) {
            return false;
          }

          if (filter.endDate != null && tx.date.isAfter(filter.endDate!)) {
            return false;
          }

          return true;
        }).toList();
      });
    });
