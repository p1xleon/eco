import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/categories/presentation/providers/category_provider.dart';
import '../../features/recurring/presentation/providers/recurring_transaction_provider.dart';
import '../../features/transactions/data/providers/transaction_repository_provider.dart';
import '../../features/transactions/presentation/providers/transaction_provider.dart';
import '../network/network_monitor.dart';

/// A record the server keeps rejecting, described for display.
class SyncFailure {
  final String collection;
  final String label;
  final String? error;

  const SyncFailure({
    required this.collection,
    required this.label,
    required this.error,
  });
}

/// How many local changes are still waiting to reach the server.
///
/// Recomputed whenever any of the synced collections is refreshed, which is
/// also when a push has just had a chance to run.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  ref.watch(transactionsProvider);
  ref.watch(categoriesProvider);
  ref.watch(recurringTransactionsProvider);

  final counts = await Future.wait([
    ref.read(transactionRepositoryProvider).pendingCount(),
    ref.read(categoryRepositoryProvider).pendingCount(),
    ref.read(recurringTransactionRepositoryProvider).pendingCount(),
  ]);

  return counts.fold<int>(0, (total, count) => total + count);
});

/// Records that have exhausted their retry budget. These no longer sync on
/// their own and need the user to intervene.
final syncFailuresProvider = FutureProvider<List<SyncFailure>>((ref) async {
  ref.watch(transactionsProvider);
  ref.watch(categoriesProvider);
  ref.watch(recurringTransactionsProvider);

  final transactions = await ref
      .read(transactionRepositoryProvider)
      .blockedRecords();
  final categories = await ref.read(categoryRepositoryProvider).blockedRecords();
  final templates = await ref
      .read(recurringTransactionRepositoryProvider)
      .blockedRecords();

  return [
    for (final record in transactions)
      SyncFailure(
        collection: 'Transaction',
        label: record.title,
        error: record.lastSyncError,
      ),
    for (final record in categories)
      SyncFailure(
        collection: 'Category',
        label: record.name,
        error: record.lastSyncError,
      ),
    for (final record in templates)
      SyncFailure(
        collection: 'Recurring',
        label: record.title,
        error: record.lastSyncError,
      ),
  ];
});

/// Pushes everything pending and pulls fresh server state.
///
/// Clears the reachability backoff and the per-collection recency windows
/// first: the user asking for a sync is a good reason to try again now.
Future<void> syncNow(WidgetRef ref) async {
  NetworkMonitor.instance.resetBackoff();
  ref.read(transactionRepositoryProvider).invalidateSyncWindow();
  ref.read(categoryRepositoryProvider).invalidateSyncWindow();
  ref.read(recurringTransactionRepositoryProvider).invalidateSyncWindow();

  await refreshTransactions(ref);
  await refreshRecurringTransactions(ref);
  ref.invalidate(categoriesProvider);
  await ref.read(categoriesProvider.future);

  ref.invalidate(pendingSyncCountProvider);
  ref.invalidate(syncFailuresProvider);
}

/// Gives up-to-now-blocked records another chance, then syncs.
Future<void> retryFailedSync(WidgetRef ref) async {
  await ref.read(transactionRepositoryProvider).retryBlockedRecords();
  await ref.read(categoryRepositoryProvider).retryBlockedRecords();
  await ref.read(recurringTransactionRepositoryProvider).retryBlockedRecords();

  await syncNow(ref);
}
