import 'package:isar_community/isar.dart';

import '../../features/categories/data/models/category_model.dart';
import '../../features/recurring/data/models/recurring_transaction_model.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../database/isar_service.dart';
import 'sync_state.dart';

/// Repairs the [SyncState] of records written before the field existed.
///
/// Isar defaults new enum properties to index 0 (`synced`), which is wrong for
/// rows that were never pushed. The invariant `remoteId == null` means "the
/// server has never seen this record" holds for every collection, so those rows
/// are pending creates — exactly what the old `remoteIdIsNull()` upload queries
/// treated them as.
///
/// Idempotent, so it runs on every launch and needs no migration flag.
class SyncBackfill {
  const SyncBackfill._();

  static Future<void> run() async {
    final isar = IsarService.isar;

    final transactions = await isar.transactionModels
        .filter()
        .remoteIdIsNull()
        .findAll();
    final categories = await isar.categoryModels
        .filter()
        .remoteIdIsNull()
        .findAll();
    final templates = await isar.recurringTransactionModels
        .filter()
        .remoteIdIsNull()
        .findAll();

    // A record without a `remoteId` cannot be `synced`.
    final staleTransactions = transactions
        .where((item) => item.syncState == SyncState.synced)
        .toList();
    final staleCategories = categories
        .where((item) => item.syncState == SyncState.synced)
        .toList();
    final staleTemplates = templates
        .where((item) => item.syncState == SyncState.synced)
        .toList();

    if (staleTransactions.isEmpty &&
        staleCategories.isEmpty &&
        staleTemplates.isEmpty) {
      return;
    }

    for (final item in staleTransactions) {
      item.syncState = SyncState.pendingCreate;
    }
    for (final item in staleCategories) {
      item.syncState = SyncState.pendingCreate;
    }
    for (final item in staleTemplates) {
      item.syncState = SyncState.pendingCreate;
    }

    await isar.writeTxn(() async {
      await isar.transactionModels.putAll(staleTransactions);
      await isar.categoryModels.putAll(staleCategories);
      await isar.recurringTransactionModels.putAll(staleTemplates);
    });
  }
}
