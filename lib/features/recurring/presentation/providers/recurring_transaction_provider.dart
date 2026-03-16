import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/recurring_transaction_model.dart';
import '../../data/repositories/recurring_transaction_repository.dart';
import '../../domain/services/recurring_transaction_service.dart';
import '../../../transactions/data/providers/transaction_repository_provider.dart';

final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) {
      return RecurringTransactionRepository();
    });

final recurringTransactionServiceProvider =
    Provider<RecurringTransactionService>((ref) {
      final recurringRepository = ref.read(recurringTransactionRepositoryProvider);
      final transactionRepository = ref.read(transactionRepositoryProvider);

      return RecurringTransactionService(
        recurringRepository: recurringRepository,
        transactionRepository: transactionRepository,
      );
    });

final recurringTransactionsProvider =
    FutureProvider<List<RecurringTransactionModel>>((ref) async {
      final repository = ref.read(recurringTransactionRepositoryProvider);
      return repository.getAll();
    });

final dueRecurringTransactionsProvider =
    FutureProvider<List<RecurringTransactionModel>>((ref) async {
      final service = ref.read(recurringTransactionServiceProvider);
      return service.getDueRecurringTransactions();
    });
