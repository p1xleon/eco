import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/providers/transaction_repository_provider.dart';
import 'transaction_filter.dart';
import 'transaction_filter_provider.dart';

final transactionsProvider = FutureProvider<List<TransactionModel>>((
  ref,
) async {
  ref.watch(authStateProvider);
  final repo = ref.read(transactionRepositoryProvider);
  return repo.getAll();
});

Future<List<TransactionModel>> refreshTransactions(WidgetRef ref) {
  ref.invalidate(transactionsProvider);
  return ref.read(transactionsProvider.future);
}

final visibleTransactionsProvider =
    Provider<AsyncValue<List<TransactionModel>>>((ref) {
      final transactionsAsync = ref.watch(transactionsProvider);
      final visibility = ref.watch(transactionVisibilityProvider);

      return transactionsAsync.whenData(visibility.applyToTransactions);
    });

final filteredTransactionsProvider =
    Provider<AsyncValue<List<TransactionModel>>>((ref) {
      final transactionsAsync = ref.watch(visibleTransactionsProvider);
      final filter = ref.watch(transactionFilterProvider);

      return transactionsAsync.whenData((transactions) {
        return transactions.where((tx) {
          if (filter.search.isNotEmpty) {
            final search = filter.search.toLowerCase();
            final matches = [tx.title, tx.paymentMethod, tx.payee, tx.note]
                .whereType<String>()
                .any((value) {
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

          if (filter.paymentMethod != null &&
              tx.paymentMethod?.trim() != filter.paymentMethod) {
            return false;
          }

          if (filter.payee != null && tx.payee?.trim() != filter.payee) {
            return false;
          }

          if (filter.minAmount != null && tx.amount < filter.minAmount!) {
            return false;
          }

          if (filter.maxAmount != null && tx.amount > filter.maxAmount!) {
            return false;
          }

          if (filter.recurring == RecurringFilter.recurringOnly &&
              tx.recurringId == null) {
            return false;
          }

          if (filter.recurring == RecurringFilter.nonRecurringOnly &&
              tx.recurringId != null) {
            return false;
          }

          if (filter.syncStatus == SyncStatusFilter.syncedOnly &&
              tx.remoteId == null) {
            return false;
          }

          if (filter.syncStatus == SyncStatusFilter.localOnly &&
              tx.remoteId != null) {
            return false;
          }

          final hasNotes = tx.note != null && tx.note!.trim().isNotEmpty;
          if (filter.notes == NotesFilter.withNotes && !hasNotes) {
            return false;
          }

          if (filter.notes == NotesFilter.withoutNotes && hasNotes) {
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
