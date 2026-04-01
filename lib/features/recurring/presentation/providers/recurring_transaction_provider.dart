import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../../data/repositories/recurring_transaction_repository.dart';
import '../../data/providers/recurring_transaction_remote_provider.dart';
import '../../domain/services/recurring_transaction_service.dart';
import '../../../transactions/data/providers/transaction_repository_provider.dart';

final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) {
      final remote = ref.read(recurringTransactionRemoteSourceProvider);
      final categoryRepository = ref.read(categoryRepositoryProvider);

      return RecurringTransactionRepository(
        remote: remote,
        categoryRepository: categoryRepository,
      );
    });

final recurringTransactionServiceProvider =
    Provider<RecurringTransactionService>((ref) {
      final recurringRepository = ref.read(
        recurringTransactionRepositoryProvider,
      );
      final transactionRepository = ref.read(transactionRepositoryProvider);

      return RecurringTransactionService(
        recurringRepository: recurringRepository,
        transactionRepository: transactionRepository,
      );
    });

final recurringTransactionsProvider =
    FutureProvider<List<RecurringTransactionModel>>((ref) async {
      ref.watch(authStateProvider);
      final repository = ref.read(recurringTransactionRepositoryProvider);
      return repository.getAll();
    });

final dueRecurringTransactionsProvider =
    FutureProvider<List<RecurringTransactionModel>>((ref) async {
      ref.watch(authStateProvider);
      final service = ref.read(recurringTransactionServiceProvider);
      return service.getDueRecurringTransactions();
    });
