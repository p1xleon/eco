import 'package:isar_community/isar.dart';

import '../../../../core/crypto/field_cipher.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/network/network_monitor.dart';
import '../../../../core/network/remote_call.dart';
import '../../../../core/sync/sync_gate.dart';
import '../../../../core/sync/sync_state.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/data/repositories/category_repository.dart';
import '../models/transaction_mapper.dart';
import '../models/transaction_model.dart';
import '../remote/transaction_remote_source.dart';

/// Local-first transaction storage.
///
/// Every mutation commits to Isar first and is replicated afterwards, so writes
/// never fail because of the network. A record that could not be pushed keeps a
/// pending [SyncState] and is retried by [pushPendingChanges] on the next read
/// or reconnect.
class TransactionRepository {
  final TransactionRemoteSource remote;

  /// Transactions reference categories, and a transaction can only be pushed
  /// with a meaningful category reference once its category has one.
  final CategoryRepository categoryRepository;

  final Isar _isar = IsarService.isar;
  final SyncGate _gate = SyncGate();

  /// Encrypts what leaves the device and decrypts what comes back. Null until
  /// the user sets up a key, in which case rows move in plaintext exactly as
  /// they did before — see [TransactionMapper.toJson].
  final FieldCipher? cipher;

  TransactionRepository(
    this.remote, {
    required this.categoryRepository,
    this.cipher,
  });

  /// Whether replication is worth attempting. Checking the network here is what
  /// keeps offline reads from paying an HTTP timeout.
  bool get _canSync =>
      remote.isAuthenticated && NetworkMonitor.instance.isOnline;

  Future<List<TransactionModel>> getAll() async {
    if (_canSync) {
      try {
        await _gate.run(() async {
          // Categories first: a transaction pushed before its category has a
          // server id would have nothing to point at.
          await categoryRepository.getAll();
          await pushPendingChanges();
          await _pullRemoteTransactions();
        });
      } catch (_) {
        // Keep local data available when remote sync fails.
      }
    }

    return _getLocalTransactions();
  }

  /// Makes the next [getAll] sync for real, skipping the recency window.
  void invalidateSyncWindow() {
    _gate.reset();
    categoryRepository.invalidateSyncWindow();
  }

  Future<TransactionModel> add(TransactionModel tx) async {
    tx.syncState = SyncState.pendingCreate;
    tx.localUpdatedAt = DateTime.now();
    _resetRetryBudget(tx);

    await _isar.writeTxn(() async {
      tx.id = await _isar.transactionModels.put(tx);
    });

    if (_canSync) {
      await _pushCreate(tx);
    }

    return tx;
  }

  Future<List<TransactionModel>> addAll(
    Iterable<TransactionModel> transactions,
  ) async {
    final items = transactions.toList(growable: false);
    if (items.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    for (final item in items) {
      item.syncState = SyncState.pendingCreate;
      item.localUpdatedAt = now;
      _resetRetryBudget(item);
    }

    // One write for the whole batch: an import is safe on disk before any
    // upload is attempted.
    await _isar.writeTxn(() async {
      await _isar.transactionModels.putAll(items);
    });

    if (_canSync) {
      for (final item in items) {
        await _pushCreate(item);
        if (!_canSync) {
          // Connection dropped mid-batch. The rest stay pending instead of
          // timing out one by one.
          break;
        }
      }
    }

    return items;
  }

  Future<TransactionModel> update(TransactionModel tx) async {
    // An edit to a record the server has never seen is still a create.
    final isCreate = tx.remoteId == null;

    tx.syncState = isCreate ? SyncState.pendingCreate : SyncState.pendingUpdate;
    tx.localUpdatedAt = DateTime.now();
    // The record changed, so whatever the server objected to may be gone.
    _resetRetryBudget(tx);

    await _isar.writeTxn(() async {
      tx.id = await _isar.transactionModels.put(tx);
    });

    if (_canSync) {
      if (isCreate) {
        await _pushCreate(tx);
      } else {
        await _pushUpdate(tx);
      }
    }

    return tx;
  }

  Future<void> delete(int id) async {
    final local = await _isar.transactionModels.get(id);
    if (local == null) return;

    // Never reached the server, so there is nothing to tombstone.
    if (local.remoteId == null) {
      await _isar.writeTxn(() async {
        await _isar.transactionModels.delete(local.id);
      });
      return;
    }

    local.syncState = SyncState.pendingDelete;
    local.localUpdatedAt = DateTime.now();
    _resetRetryBudget(local);

    await _isar.writeTxn(() async {
      await _isar.transactionModels.put(local);
    });

    if (_canSync) {
      await _pushDelete(local);
    }
  }

  /// Replays every local change the server has not accepted yet.
  Future<void> pushPendingChanges() async {
    if (!_canSync) return;

    for (final local in await _pending(SyncState.pendingCreate)) {
      await _pushCreate(local);
    }
    for (final local in await _pending(SyncState.pendingUpdate)) {
      await _pushUpdate(local);
    }
    for (final local in await _pending(SyncState.pendingDelete)) {
      await _pushDelete(local);
    }
  }

  /// Number of records still waiting to reach the server.
  Future<int> pendingCount() {
    return _isar.transactionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.synced)
        .count();
  }

  /// Records still worth pushing: pending, and not given up on.
  Future<List<TransactionModel>> _pending(SyncState state) async {
    final records = await _isar.transactionModels
        .filter()
        .syncStateEqualTo(state)
        .findAll();

    return records
        .where((record) => !isSyncBlocked(record.syncAttempts))
        .toList();
  }

  /// Records the server keeps rejecting, which no longer retry on their own.
  Future<List<TransactionModel>> blockedRecords() async {
    final records = await _isar.transactionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.synced)
        .findAll();

    return records
        .where((record) => isSyncBlocked(record.syncAttempts))
        .toList();
  }

  /// Gives blocked records their retry budget back.
  Future<void> retryBlockedRecords() async {
    final records = await blockedRecords();
    if (records.isEmpty) return;

    for (final record in records) {
      _resetRetryBudget(record);
    }

    await _isar.writeTxn(() async {
      await _isar.transactionModels.putAll(records);
    });
  }

  void _resetRetryBudget(TransactionModel record) {
    record.syncAttempts = 0;
    record.lastSyncError = null;
  }

  /// Charges a failed push against the record's retry budget, unless it failed
  /// because the device could not reach the server — that is not the record's
  /// fault and it keeps its budget.
  Future<void> _recordPushFailure(TransactionModel local, Object error) async {
    if (isNetworkFailure(error)) return;

    local.syncAttempts += 1;
    local.lastSyncError = describeSyncError(error);

    await _isar.writeTxn(() async {
      await _isar.transactionModels.put(local);
    });
  }

  Future<bool> _pushCreate(TransactionModel local) async {
    try {
      final saved = await uploadTransaction(local);
      if (saved.remoteId == null) {
        // No server identity came back, so the record is still local only.
        return false;
      }

      local.remoteId = saved.remoteId;
      local.updatedAt = saved.updatedAt ?? local.updatedAt;
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);

      await _isar.writeTxn(() async {
        await _isar.transactionModels.put(local);
      });
      return true;
    } catch (error) {
      // Stays pending and is retried on the next sync.
      await _recordPushFailure(local, error);
      return false;
    }
  }

  Future<bool> _pushUpdate(TransactionModel local) async {
    if (local.remoteId == null) {
      return _pushCreate(local);
    }

    try {
      final saved = await updateRemoteTransaction(local);
      local.updatedAt = saved.updatedAt ?? local.updatedAt;
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);

      await _isar.writeTxn(() async {
        await _isar.transactionModels.put(local);
      });
      return true;
    } catch (error) {
      await _recordPushFailure(local, error);
      return false;
    }
  }

  Future<bool> _pushDelete(TransactionModel local) async {
    final remoteId = local.remoteId;

    if (remoteId != null) {
      try {
        await deleteRemoteTransaction(remoteId);
      } catch (error) {
        // The tombstone survives, so the delete is retried rather than lost.
        await _recordPushFailure(local, error);
        return false;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.transactionModels.delete(local.id);
    });
    return true;
  }

  Future<List<TransactionModel>> _getLocalTransactions() {
    return _isar.transactionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.pendingDelete)
        .sortByDateDesc()
        .findAll();
  }

  /// Pulls the server state, resolving each row's category, and folds it in.
  ///
  /// Rows carry two category references: `category_remote_id` (the category's
  /// server uuid, meaningful anywhere) and the legacy `category_id` (the Isar id
  /// of whichever device wrote the row, meaningful only there). The uuid wins
  /// when it resolves; otherwise the legacy value is kept, which is exactly the
  /// old behaviour.
  ///
  /// Rows that predate the uuid column are *not* rewritten in bulk. This device
  /// cannot know what another device's integer meant, so guessing would freeze
  /// a wrong reference and hand it to every other device. They upgrade
  /// naturally when the user next edits them, where the category on screen is
  /// authoritative.
  Future<void> _pullRemoteTransactions() async {
    final data = await remote.fetchTransactions();
    final categoryIdsByRemoteId = await _localCategoryIdsByRemoteId();

    final transactions = [
      for (final json in data)
        TransactionMapper.fromJson(
          json,
          categoryId:
              categoryIdsByRemoteId[json[transactionCategoryRemoteIdColumn]],
          cipher: cipher,
        ),
    ];

    await _mergeRemoteTransactions(transactions);
  }

  Future<Map<String, int>> _localCategoryIdsByRemoteId() async {
    final categories = await _isar.categoryModels.where().findAll();

    return {
      for (final category in categories)
        if (category.remoteId != null && category.syncState.isVisible)
          category.remoteId!: category.id,
    };
  }

  /// Folds the server state into the local cache.
  ///
  /// Records with unpushed local changes are left alone — [pushPendingChanges]
  /// resolves those. Local ids are preserved so links held elsewhere (and by
  /// the UI) stay valid.
  Future<void> _mergeRemoteTransactions(
    List<TransactionModel> remoteTransactions,
  ) async {
    final locals = await _isar.transactionModels.where().findAll();
    final localByRemoteId = <String, TransactionModel>{
      for (final local in locals)
        if (local.remoteId != null) local.remoteId!: local,
    };

    final remoteIds = <String>{};
    final toPut = <TransactionModel>[];

    for (final incoming in remoteTransactions) {
      final remoteId = incoming.remoteId;
      if (remoteId == null) continue;
      remoteIds.add(remoteId);

      final existing = localByRemoteId[remoteId];
      if (existing == null) {
        incoming.syncState = SyncState.synced;
        toPut.add(incoming);
        continue;
      }

      if (existing.syncState.isPending) continue;

      incoming.id = existing.id;
      incoming.syncState = SyncState.synced;
      incoming.localUpdatedAt = existing.localUpdatedAt;
      // These columns were added after some rows were written, so the server
      // can still answer null for them. Keep what the device knows.
      incoming.recurringId ??= existing.recurringId;
      incoming.recurringTemplateId ??= existing.recurringTemplateId;
      incoming.isRecurringInstance ??= existing.isRecurringInstance;
      toPut.add(incoming);
    }

    // Synced rows the server no longer has were deleted on another device.
    final removedIds = [
      for (final local in locals)
        if (local.syncState == SyncState.synced &&
            local.remoteId != null &&
            !remoteIds.contains(local.remoteId))
          local.id,
    ];

    if (toPut.isEmpty && removedIds.isEmpty) return;

    await _isar.writeTxn(() async {
      if (removedIds.isNotEmpty) {
        await _isar.transactionModels.deleteAll(removedIds);
      }
      if (toPut.isNotEmpty) {
        await _isar.transactionModels.putAll(toPut);
      }
    });
  }

  Future<TransactionModel> uploadTransaction(TransactionModel tx) async {
    final user = remote.currentUser;
    if (user == null) {
      return tx;
    }

    final data = await remote.addTransaction(await _toRemoteJson(tx, user.id));
    return _fromRemoteJson(data, fallback: tx);
  }

  Future<TransactionModel> updateRemoteTransaction(TransactionModel tx) async {
    final user = remote.currentUser;
    if (user == null || tx.remoteId == null) {
      return tx;
    }

    final data = await remote.updateTransaction(
      tx.remoteId!,
      await _toRemoteJson(tx, user.id),
    );
    return _fromRemoteJson(data, fallback: tx);
  }

  Future<Map<String, dynamic>> _toRemoteJson(
    TransactionModel tx,
    String userId,
  ) async {
    final category = await _isar.categoryModels.get(tx.categoryId);

    return tx.toJson(
      userId,
      categoryRemoteId: category?.remoteId,
      cipher: cipher,
    );
  }

  /// Parses a row the server just echoed back. The category is already known
  /// locally, so it is carried over rather than re-resolved.
  TransactionModel _fromRemoteJson(
    Map<String, dynamic> json, {
    required TransactionModel fallback,
  }) {
    return TransactionMapper.fromJson(
      json,
      categoryId: fallback.categoryId,
      cipher: cipher,
    );
  }

  Future<List<TransactionModel>> fetchRemoteTransactions() async {
    final data = await remote.fetchTransactions();
    final categoryIdsByRemoteId = await _localCategoryIdsByRemoteId();

    return data.map((json) {
      final categoryRemoteId =
          json[transactionCategoryRemoteIdColumn] as String?;

      return TransactionMapper.fromJson(
        json,
        categoryId: categoryRemoteId == null
            ? null
            : categoryIdsByRemoteId[categoryRemoteId],
        cipher: cipher,
      );
    }).toList();
  }

  Future<void> deleteRemoteTransaction(String id) async {
    await remote.deleteTransaction(id);
  }
}
