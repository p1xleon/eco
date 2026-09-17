import 'package:isar_community/isar.dart';

import '../../../../core/crypto/field_cipher.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/network/network_monitor.dart';
import '../../../../core/network/remote_call.dart';
import '../../../../core/sync/sync_gate.dart';
import '../../../../core/sync/sync_state.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/data/repositories/category_repository.dart';
import '../models/recurring_transaction_mapper.dart';
import '../models/recurring_transaction_model.dart';
import '../remote/recurring_transaction_remote_source.dart';

/// Local-first recurring template storage. See [TransactionRepository] for the
/// shape: local write first, replication after, pending records retried later.
class RecurringTransactionRepository {
  final RecurringTransactionRemoteSource remote;
  final CategoryRepository categoryRepository;
  final Isar _isar = IsarService.isar;
  final SyncGate _gate = SyncGate();

  /// Encrypts what leaves the device. Null until the user sets up a key —
  /// see [RecurringTransactionMapper.toJson].
  final FieldCipher? cipher;

  RecurringTransactionRepository({
    required this.remote,
    required this.categoryRepository,
    this.cipher,
  });

  bool get _canSync =>
      remote.isAuthenticated && NetworkMonitor.instance.isOnline;

  Future<List<RecurringTransactionModel>> getAll() async {
    if (_canSync) {
      try {
        await _gate.run(() async {
          // Templates reference categories by local id, so categories have to
          // be reconciled first.
          await categoryRepository.getAll();
          await _pullRemoteTemplates();
          await pushPendingChanges();
        });
      } catch (_) {
        // Keep local templates available when remote sync fails.
      }
    }

    return _getLocalTemplates();
  }

  /// Makes the next [getAll] sync for real, skipping the recency window.
  void invalidateSyncWindow() {
    _gate.reset();
    categoryRepository.invalidateSyncWindow();
  }

  Future<RecurringTransactionModel?> getById(int id) async {
    final template = await _isar.recurringTransactionModels.get(id);
    if (template == null || template.syncState == SyncState.pendingDelete) {
      return null;
    }

    return template;
  }

  Future<RecurringTransactionModel> save(
    RecurringTransactionModel template,
  ) async {
    final isCreate = template.remoteId == null;

    template.syncState = isCreate
        ? SyncState.pendingCreate
        : SyncState.pendingUpdate;
    template.localUpdatedAt = DateTime.now();
    // The record changed, so whatever the server objected to may be gone.
    _resetRetryBudget(template);

    await _isar.writeTxn(() async {
      template.id = await _isar.recurringTransactionModels.put(template);
    });

    if (_canSync) {
      try {
        await categoryRepository.getAll();
      } catch (_) {
        // A stale category map only costs a retry on the next sync.
      }

      if (isCreate) {
        await _pushCreate(template);
      } else {
        await _pushUpdate(template);
      }
    }

    return template;
  }

  Future<void> delete(int id) async {
    final template = await _isar.recurringTransactionModels.get(id);
    if (template == null) return;

    if (template.remoteId == null) {
      await _isar.writeTxn(() async {
        await _isar.recurringTransactionModels.delete(template.id);
      });
      return;
    }

    template.syncState = SyncState.pendingDelete;
    template.localUpdatedAt = DateTime.now();
    _resetRetryBudget(template);

    await _isar.writeTxn(() async {
      await _isar.recurringTransactionModels.put(template);
    });

    if (_canSync) {
      await _pushDelete(template);
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
    return _isar.recurringTransactionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.synced)
        .count();
  }

  /// Records still worth pushing: pending, and not given up on.
  Future<List<RecurringTransactionModel>> _pending(SyncState state) async {
    final records = await _isar.recurringTransactionModels
        .filter()
        .syncStateEqualTo(state)
        .findAll();

    return records
        .where((record) => !isSyncBlocked(record.syncAttempts))
        .toList();
  }

  /// Records the server keeps rejecting, which no longer retry on their own.
  Future<List<RecurringTransactionModel>> blockedRecords() async {
    final records = await _isar.recurringTransactionModels
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
      await _isar.recurringTransactionModels.putAll(records);
    });
  }

  void _resetRetryBudget(RecurringTransactionModel record) {
    record.syncAttempts = 0;
    record.lastSyncError = null;
  }

  /// Charges a failed push against the record's retry budget, unless the
  /// server simply could not be reached.
  Future<void> _recordPushFailure(
    RecurringTransactionModel local,
    Object error,
  ) async {
    if (isNetworkFailure(error)) return;

    local.syncAttempts += 1;
    local.lastSyncError = describeSyncError(error);
    await _saveLocal(local);
  }

  Future<bool> _pushCreate(RecurringTransactionModel local) async {
    try {
      final saved = await uploadRecurringTransaction(local);
      if (saved.remoteId == null) return false;

      local.remoteId = saved.remoteId;
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);
      await _saveLocal(local);
      return true;
    } catch (error) {
      // Keep the local template and retry on the next sync.
      await _recordPushFailure(local, error);
      return false;
    }
  }

  Future<bool> _pushUpdate(RecurringTransactionModel local) async {
    if (local.remoteId == null) {
      return _pushCreate(local);
    }

    try {
      final saved = await updateRemoteRecurringTransaction(local);
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

  Future<bool> _pushDelete(RecurringTransactionModel local) async {
    final remoteId = local.remoteId;

    if (remoteId != null) {
      try {
        await deleteRemoteRecurringTransaction(remoteId);
      } catch (error) {
        await _recordPushFailure(local, error);
        return false;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.recurringTransactionModels.delete(local.id);
    });
    return true;
  }

  Future<void> _saveLocal(RecurringTransactionModel template) async {
    await _isar.writeTxn(() async {
      template.id = await _isar.recurringTransactionModels.put(template);
    });
  }

  Future<List<RecurringTransactionModel>> _getLocalTemplates() async {
    return _isar.recurringTransactionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.pendingDelete)
        .sortByNextDueDate()
        .findAll();
  }

  /// Pulls the server state and folds it in.
  ///
  /// The server ids are taken from the raw rows rather than from the parsed
  /// templates: [_fromRemoteJson] drops a row whose category cannot be
  /// resolved locally, and treating that as "deleted on the server" would
  /// delete a perfectly good local template.
  Future<void> _pullRemoteTemplates() async {
    final data = await remote.fetchRecurringTransactions();
    final serverIds = <String>{
      for (final item in data)
        if (item['id'] is String) item['id'] as String,
    };

    final templates = <RecurringTransactionModel>[];
    for (final item in data) {
      final template = await _fromRemoteJson(item);
      if (template != null) {
        templates.add(template);
      }
    }

    await _mergeRemoteTemplates(templates, serverIds);
  }

  Future<void> _mergeRemoteTemplates(
    List<RecurringTransactionModel> remoteTemplates,
    Set<String> serverIds,
  ) async {
    final localTemplates = await _isar.recurringTransactionModels
        .where()
        .findAll();
    final localByRemoteId = <String, RecurringTransactionModel>{
      for (final template in localTemplates)
        if (template.remoteId != null) template.remoteId!: template,
    };
    final localByFingerprint = <String, RecurringTransactionModel>{
      for (final template in localTemplates)
        if (template.remoteId == null) _fingerprint(template): template,
    };

    final merged = <RecurringTransactionModel>[];

    for (final remoteTemplate in remoteTemplates) {
      final remoteId = remoteTemplate.remoteId;
      final existing =
          localByRemoteId[remoteId] ??
          localByFingerprint[_fingerprint(remoteTemplate)];

      // Deleted locally: the pending push removes it from the server.
      if (existing != null && existing.syncState == SyncState.pendingDelete) {
        continue;
      }

      // Edited locally: the local version wins until the push resolves it.
      if (existing != null && existing.syncState == SyncState.pendingUpdate) {
        if (existing.remoteId == null && remoteId != null) {
          existing.remoteId = remoteId;
          merged.add(existing);
        }
        continue;
      }

      final template = existing ?? RecurringTransactionModel();

      template
        ..id = existing?.id ?? template.id
        ..remoteId = remoteTemplate.remoteId
        ..title = remoteTemplate.title
        ..type = remoteTemplate.type
        ..defaultAmount = remoteTemplate.defaultAmount
        ..amountType = remoteTemplate.amountType
        ..categoryId = remoteTemplate.categoryId
        ..accountId = remoteTemplate.accountId
        ..intervalType = remoteTemplate.intervalType
        ..intervalCount = remoteTemplate.intervalCount
        ..nextDueDate = remoteTemplate.nextDueDate
        ..endDate = remoteTemplate.endDate
        ..isActive = remoteTemplate.isActive
        ..note = remoteTemplate.note
        ..createdAt = remoteTemplate.createdAt
        ..updatedAt = remoteTemplate.updatedAt
        ..syncState = SyncState.synced
        ..localUpdatedAt = existing?.localUpdatedAt;
      merged.add(template);
    }

    // Synced rows the server no longer has were deleted on another device.
    final removedIds = [
      for (final template in localTemplates)
        if (template.syncState == SyncState.synced &&
            template.remoteId != null &&
            !serverIds.contains(template.remoteId))
          template.id,
    ];

    if (merged.isEmpty && removedIds.isEmpty) return;

    await _isar.writeTxn(() async {
      if (removedIds.isNotEmpty) {
        await _isar.recurringTransactionModels.deleteAll(removedIds);
      }
      if (merged.isNotEmpty) {
        await _isar.recurringTransactionModels.putAll(merged);
      }
    });
  }

  Future<RecurringTransactionModel> uploadRecurringTransaction(
    RecurringTransactionModel template,
  ) async {
    final user = remote.currentUser;
    if (user == null) return template;

    final data = await remote.addRecurringTransaction(
      await _toRemoteJson(template, user.id),
    );
    return await _fromRemoteJson(data) ?? template;
  }

  Future<RecurringTransactionModel> updateRemoteRecurringTransaction(
    RecurringTransactionModel template,
  ) async {
    final user = remote.currentUser;
    if (user == null || template.remoteId == null) {
      return template;
    }

    final data = await remote.updateRecurringTransaction(
      template.remoteId!,
      await _toRemoteJson(template, user.id),
    );
    return await _fromRemoteJson(data) ?? template;
  }

  Future<List<RecurringTransactionModel>>
  fetchRemoteRecurringTransactions() async {
    final data = await remote.fetchRecurringTransactions();
    final templates = <RecurringTransactionModel>[];

    for (final item in data) {
      final template = await _fromRemoteJson(item);
      if (template != null) {
        templates.add(template);
      }
    }

    return templates;
  }

  Future<void> deleteRemoteRecurringTransaction(String id) async {
    await remote.deleteRecurringTransaction(id);
  }

  Future<Map<String, dynamic>> _toRemoteJson(
    RecurringTransactionModel template,
    String userId,
  ) async {
    final category = await _isar.categoryModels.get(template.categoryId);
    final categoryRemoteId = category?.remoteId;

    return template.toJson(
      userId,
      categoryRemoteId: categoryRemoteId,
      cipher: cipher,
    );
  }

  Future<RecurringTransactionModel?> _fromRemoteJson(
    Map<String, dynamic> json,
  ) async {
    final categoryRemoteId = json['category_id'] as String?;
    final categoryId = await _resolveLocalCategoryId(
      categoryRemoteId: categoryRemoteId,
      typeName: json['type'] as String?,
    );
    if (categoryId == null) {
      return null;
    }

    return RecurringTransactionMapper.fromJson(
      json,
      categoryId: categoryId,
      cipher: cipher,
    );
  }

  Future<int?> _resolveLocalCategoryId({
    required String? categoryRemoteId,
    required String? typeName,
  }) async {
    if (categoryRemoteId != null) {
      final matched = await _isar.categoryModels
          .filter()
          .remoteIdEqualTo(categoryRemoteId)
          .findFirst();
      if (matched != null) {
        return matched.id;
      }
    }

    final fallbackType = typeName == 'income' ? 1 : 0;
    final categories = await _isar.categoryModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.pendingDelete)
        .findAll();
    final fallback = categories.where(
      (item) => item.type.index == fallbackType,
    );
    return fallback.isEmpty ? null : fallback.first.id;
  }

  String _fingerprint(RecurringTransactionModel template) {
    return [
      template.type.name,
      template.title.trim().toLowerCase(),
      template.intervalType.name,
      template.intervalCount.toString(),
      template.nextDueDate.toIso8601String(),
    ].join('|');
  }
}
