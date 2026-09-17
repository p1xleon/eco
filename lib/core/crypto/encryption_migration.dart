import 'package:isar_community/isar.dart';

import '../../features/categories/data/models/category_model.dart';
import '../../features/recurring/data/models/recurring_transaction_model.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../sync/sync_state.dart';

/// Rewrites everything the server already holds in plaintext, once a key exists.
///
/// There is no bespoke migration code here on purpose. Marking each synced
/// record `pendingUpdate` hands the job to the push path, which already knows
/// how to rewrite a row, retry a failure and give up gracefully on a record the
/// server keeps rejecting. The mappers encrypt on the way out because the
/// repositories now hold a cipher.
///
/// Records that were never pushed are left alone: they are already queued as
/// creates and will go up encrypted anyway.
class EncryptionMigration {
  const EncryptionMigration._();

  /// Queues every synced record for re-upload. Returns how many were queued.
  static Future<int> queueAll(Isar isar) async {
    final transactions = await isar.transactionModels
        .filter()
        .syncStateEqualTo(SyncState.synced)
        .remoteIdIsNotNull()
        .findAll();
    final categories = await isar.categoryModels
        .filter()
        .syncStateEqualTo(SyncState.synced)
        .remoteIdIsNotNull()
        .findAll();
    final templates = await isar.recurringTransactionModels
        .filter()
        .syncStateEqualTo(SyncState.synced)
        .remoteIdIsNotNull()
        .findAll();

    final now = DateTime.now();

    for (final item in transactions) {
      item.syncState = SyncState.pendingUpdate;
      item.localUpdatedAt = now;
      item.syncAttempts = 0;
      item.lastSyncError = null;
    }
    for (final item in categories) {
      item.syncState = SyncState.pendingUpdate;
      item.localUpdatedAt = now;
      item.syncAttempts = 0;
      item.lastSyncError = null;
    }
    for (final item in templates) {
      item.syncState = SyncState.pendingUpdate;
      item.localUpdatedAt = now;
      item.syncAttempts = 0;
      item.lastSyncError = null;
    }

    await isar.writeTxn(() async {
      await isar.transactionModels.putAll(transactions);
      await isar.categoryModels.putAll(categories);
      await isar.recurringTransactionModels.putAll(templates);
    });

    return transactions.length + categories.length + templates.length;
  }
}
