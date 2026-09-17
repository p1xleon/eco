import 'package:isar_community/isar.dart';

import '../../../../core/crypto/field_cipher.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/network/network_monitor.dart';
import '../../../../core/network/remote_call.dart';
import '../../../../core/sync/sync_gate.dart';
import '../../../../core/sync/sync_state.dart';
import '../models/category_mapper.dart';
import '../models/category_model.dart';
import '../remote/category_remote_source.dart';

/// Local-first category storage. See [TransactionRepository] for the shape:
/// local write first, replication after, pending records retried later.
class CategoryRepository {
  final CategoryRemoteSource remote;
  final Isar _isar = IsarService.isar;
  final SyncGate _gate = SyncGate();

  /// Encrypts what leaves the device. Null until the user sets up a key —
  /// see [CategoryMapper.toJson].
  final FieldCipher? cipher;

  CategoryRepository(this.remote, {this.cipher});

  bool get _canSync =>
      remote.isAuthenticated && NetworkMonitor.instance.isOnline;

  Future<List<CategoryModel>> getAll() async {
    if (_canSync) {
      try {
        await _gate.run(() async {
          await _mergeRemoteCategories(await fetchRemoteCategories());
          await pushPendingChanges();
        });
      } catch (_) {
        // Keep local data available when remote sync fails.
      }
    }

    return _getLocalCategories();
  }

  /// Makes the next [getAll] sync for real, skipping the recency window.
  void invalidateSyncWindow() => _gate.reset();

  Future<void> add(CategoryModel category) async {
    category.syncState = SyncState.pendingCreate;
    category.localUpdatedAt = DateTime.now();
    _resetRetryBudget(category);
    await _saveLocal(category);

    if (_canSync) {
      await _pushCreate(category);
    }
  }

  Future<void> update(CategoryModel category) async {
    final isCreate = category.remoteId == null;

    category.syncState = isCreate
        ? SyncState.pendingCreate
        : SyncState.pendingUpdate;
    category.localUpdatedAt = DateTime.now();
    // The record changed, so whatever the server objected to may be gone.
    _resetRetryBudget(category);
    await _saveLocal(category);

    if (_canSync) {
      if (isCreate) {
        await _pushCreate(category);
      } else {
        await _pushUpdate(category);
      }
    }
  }

  Future<void> delete(int id) async {
    final category = await _isar.categoryModels.get(id);
    if (category == null) return;

    if (category.remoteId == null) {
      await _isar.writeTxn(() async {
        await _isar.categoryModels.delete(category.id);
      });
      return;
    }

    category.syncState = SyncState.pendingDelete;
    category.localUpdatedAt = DateTime.now();
    _resetRetryBudget(category);
    await _saveLocal(category);

    if (_canSync) {
      await _pushDelete(category);
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
    return _isar.categoryModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.synced)
        .count();
  }

  /// Records still worth pushing: pending, and not given up on.
  Future<List<CategoryModel>> _pending(SyncState state) async {
    final records = await _isar.categoryModels
        .filter()
        .syncStateEqualTo(state)
        .findAll();

    return records
        .where((record) => !isSyncBlocked(record.syncAttempts))
        .toList();
  }

  /// Records the server keeps rejecting, which no longer retry on their own.
  Future<List<CategoryModel>> blockedRecords() async {
    final records = await _isar.categoryModels
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
      await _isar.categoryModels.putAll(records);
    });
  }

  void _resetRetryBudget(CategoryModel record) {
    record.syncAttempts = 0;
    record.lastSyncError = null;
  }

  /// Charges a failed push against the record's retry budget, unless the
  /// server simply could not be reached.
  Future<void> _recordPushFailure(CategoryModel local, Object error) async {
    if (isNetworkFailure(error)) return;

    local.syncAttempts += 1;
    local.lastSyncError = describeSyncError(error);
    await _saveLocal(local);
  }

  Future<bool> _pushCreate(CategoryModel local) async {
    try {
      final saved = await uploadCategory(local);
      if (saved.remoteId == null) return false;

      local.remoteId = saved.remoteId;
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);
      await _saveLocal(local);
      return true;
    } catch (error) {
      // Keep the local record and retry on the next sync.
      await _recordPushFailure(local, error);
      return false;
    }
  }

  Future<bool> _pushUpdate(CategoryModel local) async {
    if (local.remoteId == null) {
      return _pushCreate(local);
    }

    try {
      final saved = await updateRemoteCategory(local);
      local.remoteId = saved.remoteId ?? local.remoteId;
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);
      await _saveLocal(local);
      return true;
    } catch (error) {
      await _recordPushFailure(local, error);
      return false;
    }
  }

  Future<bool> _pushDelete(CategoryModel local) async {
    final remoteId = local.remoteId;

    if (remoteId != null) {
      try {
        await deleteRemoteCategory(remoteId);
      } catch (error) {
        await _recordPushFailure(local, error);
        return false;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.categoryModels.delete(local.id);
    });
    return true;
  }

  Future<List<CategoryModel>> _getLocalCategories() async {
    final categories = await _isar.categoryModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.pendingDelete)
        .findAll();
    categories.sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) return typeCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return categories;
  }

  Future<void> _saveLocal(CategoryModel category) async {
    await _isar.writeTxn(() async {
      category.id = await _isar.categoryModels.put(category);
    });
  }

  Future<void> _mergeRemoteCategories(
    List<CategoryModel> remoteCategories,
  ) async {
    final localCategories = await _isar.categoryModels.where().findAll();
    final localByRemoteId = <String, CategoryModel>{
      for (final category in localCategories)
        if (category.remoteId != null) category.remoteId!: category,
    };
    // Seeded defaults have no remote id yet; matching them by name adopts the
    // server's copy instead of creating a duplicate.
    final localByFingerprint = <String, CategoryModel>{
      for (final category in localCategories)
        if (category.remoteId == null) _fingerprint(category): category,
    };

    final remoteIds = <String>{};
    final merged = <CategoryModel>[];

    for (final remoteCategory in remoteCategories) {
      final remoteId = remoteCategory.remoteId;
      if (remoteId != null) {
        remoteIds.add(remoteId);
      }

      final existing =
          localByRemoteId[remoteId] ??
          localByFingerprint[_fingerprint(remoteCategory)];

      // Deleted locally: the pending push removes it from the server, so do
      // not resurrect it here.
      if (existing != null && existing.syncState == SyncState.pendingDelete) {
        continue;
      }

      // Edited locally: the local version wins until the push resolves it. It
      // can still adopt a remote id it was missing.
      if (existing != null && existing.syncState == SyncState.pendingUpdate) {
        if (existing.remoteId == null && remoteId != null) {
          existing.remoteId = remoteId;
          merged.add(existing);
        }
        continue;
      }

      // Everything else takes the server version. A `pendingCreate` that
      // matched by fingerprint is a seeded default adopting the server's copy
      // rather than duplicating it.
      final category = existing ?? CategoryModel();

      category
        ..id = existing?.id ?? category.id
        ..remoteId = remoteCategory.remoteId
        ..name = remoteCategory.name
        ..type = remoteCategory.type
        ..color = remoteCategory.color
        ..icon = remoteCategory.icon
        ..syncState = SyncState.synced
        ..localUpdatedAt = existing?.localUpdatedAt;
      merged.add(category);
    }

    // Synced rows the server no longer has were deleted on another device.
    final removedIds = [
      for (final category in localCategories)
        if (category.syncState == SyncState.synced &&
            category.remoteId != null &&
            !remoteIds.contains(category.remoteId))
          category.id,
    ];

    if (merged.isEmpty && removedIds.isEmpty) return;

    await _isar.writeTxn(() async {
      if (removedIds.isNotEmpty) {
        await _isar.categoryModels.deleteAll(removedIds);
      }
      if (merged.isNotEmpty) {
        await _isar.categoryModels.putAll(merged);
      }
    });
  }

  Future<CategoryModel> uploadCategory(CategoryModel category) async {
    final user = remote.currentUser;
    if (user == null) return category;

    final data = await remote.addCategory(
      category.toJson(user.id, cipher: cipher),
    );
    return CategoryMapper.fromJson(data, cipher: cipher);
  }

  Future<CategoryModel> updateRemoteCategory(CategoryModel category) async {
    final user = remote.currentUser;
    if (user == null || category.remoteId == null) {
      return category;
    }

    final data = await remote.updateCategory(
      category.remoteId!,
      category.toJson(user.id, cipher: cipher),
    );
    return CategoryMapper.fromJson(data, cipher: cipher);
  }

  Future<List<CategoryModel>> fetchRemoteCategories() async {
    final data = await remote.fetchCategories();
    return data
        .map((json) => CategoryMapper.fromJson(json, cipher: cipher))
        .toList();
  }

  Future<void> deleteRemoteCategory(String id) async {
    await remote.deleteCategory(id);
  }

  String _fingerprint(CategoryModel category) {
    return '${category.type.name}:${category.name.trim().toLowerCase()}';
  }
}
