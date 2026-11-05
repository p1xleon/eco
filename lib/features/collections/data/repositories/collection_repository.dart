import 'package:isar_community/isar.dart';

import '../../../../core/crypto/field_cipher.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/network/network_monitor.dart';
import '../../../../core/network/remote_call.dart';
import '../../../../core/sync/sync_gate.dart';
import '../../../../core/sync/sync_issues.dart';
import '../../../../core/sync/sync_state.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../models/collection_mapper.dart';
import '../models/collection_model.dart';
import '../remote/collection_remote_source.dart';

/// Local-first collection storage, shaped like [CategoryRepository].
class CollectionRepository {
  final CollectionRemoteSource remote;
  final Isar _isar = IsarService.isar;
  final SyncGate _gate = SyncGate();

  /// Encrypts what leaves the device. Null until the user sets up a key.
  final FieldCipher? cipher;

  CollectionRepository(this.remote, {this.cipher});

  bool get _canSync =>
      remote.isAuthenticated && NetworkMonitor.instance.isOnline;

  Future<List<CollectionModel>> getAll() async {
    if (_canSync) {
      try {
        await _gate.run(() async {
          await _pullRemoteCollections();
          await pushPendingChanges();
        });
      } catch (_) {
        // Keep local data available when remote sync fails.
      }
    }

    return _getLocalCollections();
  }

  /// Makes the next [getAll] sync for real, skipping the recency window.
  void invalidateSyncWindow() => _gate.reset();

  Future<void> add(CollectionModel collection) async {
    collection.syncState = SyncState.pendingCreate;
    collection.localUpdatedAt = DateTime.now();
    _resetRetryBudget(collection);
    await _saveLocal(collection);

    if (_canSync) {
      await _pushCreate(collection);
    }
  }

  Future<void> update(CollectionModel collection) async {
    final isCreate = collection.remoteId == null;

    collection.syncState = isCreate
        ? SyncState.pendingCreate
        : SyncState.pendingUpdate;
    collection.localUpdatedAt = DateTime.now();
    _resetRetryBudget(collection);
    await _saveLocal(collection);

    if (_canSync) {
      if (isCreate) {
        await _pushCreate(collection);
      } else {
        await _pushUpdate(collection);
      }
    }
  }

  /// Removes the collection and un-assigns its transactions in the same write,
  /// so no transaction is ever left pointing at nothing. The transactions are
  /// not re-queued: the server's `on delete set null` clears them there.
  Future<void> delete(int id) async {
    final collection = await _isar.collectionModels.get(id);
    if (collection == null) return;

    final members = await _isar.transactionModels
        .filter()
        .collectionIdEqualTo(id)
        .findAll();
    for (final tx in members) {
      tx.collectionId = null;
    }

    if (collection.remoteId == null) {
      await _isar.writeTxn(() async {
        await _isar.transactionModels.putAll(members);
        await _isar.collectionModels.delete(collection.id);
      });
      return;
    }

    collection.syncState = SyncState.pendingDelete;
    collection.localUpdatedAt = DateTime.now();
    _resetRetryBudget(collection);
    await _isar.writeTxn(() async {
      await _isar.transactionModels.putAll(members);
      await _isar.collectionModels.put(collection);
    });

    if (_canSync) {
      await _pushDelete(collection);
    }
  }

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

  Future<int> pendingCount() {
    return _isar.collectionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.synced)
        .count();
  }

  Future<List<CollectionModel>> _pending(SyncState state) async {
    final records = await _isar.collectionModels
        .filter()
        .syncStateEqualTo(state)
        .findAll();

    return records
        .where((record) => !isSyncBlocked(record.syncAttempts))
        .toList();
  }

  /// Records the server keeps rejecting, which no longer retry on their own.
  Future<List<CollectionModel>> blockedRecords() async {
    final records = await _isar.collectionModels
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
      await _isar.collectionModels.putAll(records);
    });
  }

  void _resetRetryBudget(CollectionModel record) {
    record.syncAttempts = 0;
    record.lastSyncError = null;
  }

  Future<void> _recordPushFailure(CollectionModel local, Object error) async {
    if (isNetworkFailure(error)) return;

    local.syncAttempts += 1;
    local.lastSyncError = describeSyncError(error);
    await _saveLocal(local);
  }

  Future<bool> _pushCreate(CollectionModel local) async {
    try {
      final user = remote.currentUser;
      if (user == null) return false;

      final saved = CollectionMapper.fromJson(
        await remote.addCollection(local.toJson(user.id, cipher: cipher)),
        cipher: cipher,
      );
      if (saved.remoteId == null) return false;

      local.remoteId = saved.remoteId;
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);
      await _saveLocal(local);
      await _requeueMembers(local.id);
      return true;
    } catch (error) {
      // Keep the local record and retry on the next sync.
      await _recordPushFailure(local, error);
      return false;
    }
  }

  /// Transactions assigned while this collection had no uuid went up with a
  /// null `collection_remote_id`. Now there is a uuid, push them again.
  ///
  /// Pending members are touched too: one may be mid-push with the null, and a
  /// newer `localUpdatedAt` is what makes that push finish as still pending.
  Future<void> _requeueMembers(int collectionId) async {
    final members = await _isar.transactionModels
        .filter()
        .collectionIdEqualTo(collectionId)
        .not()
        .syncStateEqualTo(SyncState.pendingDelete)
        .findAll();
    if (members.isEmpty) return;

    final now = DateTime.now();
    for (final tx in members) {
      tx.localUpdatedAt = now;
      if (tx.syncState == SyncState.synced) {
        tx.syncState = SyncState.pendingUpdate;
      }
    }
    await _isar.writeTxn(() async {
      await _isar.transactionModels.putAll(members);
    });
  }

  Future<bool> _pushUpdate(CollectionModel local) async {
    final remoteId = local.remoteId;
    if (remoteId == null) {
      return _pushCreate(local);
    }

    try {
      final user = remote.currentUser;
      if (user == null) return false;

      await remote.updateCollection(
        remoteId,
        local.toJson(user.id, cipher: cipher),
      );
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);
      await _saveLocal(local);
      return true;
    } catch (error) {
      await _recordPushFailure(local, error);
      return false;
    }
  }

  Future<bool> _pushDelete(CollectionModel local) async {
    final remoteId = local.remoteId;

    if (remoteId != null) {
      try {
        await remote.deleteCollection(remoteId);
      } catch (error) {
        await _recordPushFailure(local, error);
        return false;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.collectionModels.delete(local.id);
    });
    return true;
  }

  Future<List<CollectionModel>> _getLocalCollections() async {
    final collections = await _isar.collectionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.pendingDelete)
        .findAll();
    collections.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return collections;
  }

  Future<void> _saveLocal(CollectionModel collection) async {
    await _isar.writeTxn(() async {
      collection.id = await _isar.collectionModels.put(collection);
    });
  }

  /// Skips rows this device cannot read instead of failing the whole pull, but
  /// still counts them as present on the server so good local copies survive.
  Future<void> _pullRemoteCollections() async {
    final data = await remote.fetchCollections();
    final readable = <CollectionModel>[];
    var unreadable = 0;
    for (final json in data) {
      try {
        readable.add(CollectionMapper.fromJson(json, cipher: cipher));
      } catch (_) {
        unreadable++;
      }
    }
    SyncIssues.reportUnreadable('collections', unreadable);

    final serverIds = {
      for (final json in data)
        if (json['id'] is String) json['id'] as String,
    };

    final locals = await _isar.collectionModels.where().findAll();
    final localByRemoteId = <String, CollectionModel>{
      for (final local in locals)
        if (local.remoteId != null) local.remoteId!: local,
    };

    final merged = <CollectionModel>[];
    for (final incoming in readable) {
      final existing = localByRemoteId[incoming.remoteId];

      // Pending local changes win until the push resolves them.
      if (existing != null && existing.syncState.isPending) continue;

      incoming
        ..id = existing?.id ?? incoming.id
        ..syncState = SyncState.synced
        ..localUpdatedAt = existing?.localUpdatedAt;
      merged.add(incoming);
    }

    // Synced rows the server no longer has were deleted on another device.
    final removedIds = [
      for (final local in locals)
        if (local.syncState == SyncState.synced &&
            local.remoteId != null &&
            !serverIds.contains(local.remoteId))
          local.id,
    ];

    if (merged.isEmpty && removedIds.isEmpty) return;

    // Same as [delete]: members must not keep pointing at a gone collection, or
    // their next push sends a uuid the server's foreign key rejects.
    final orphans = [
      for (final id in removedIds)
        ...await _isar.transactionModels
            .filter()
            .collectionIdEqualTo(id)
            .findAll(),
    ];
    for (final tx in orphans) {
      tx.collectionId = null;
    }

    await _isar.writeTxn(() async {
      if (removedIds.isNotEmpty) {
        await _isar.collectionModels.deleteAll(removedIds);
        await _isar.transactionModels.putAll(orphans);
      }
      if (merged.isNotEmpty) {
        await _isar.collectionModels.putAll(merged);
      }
    });
  }
}
