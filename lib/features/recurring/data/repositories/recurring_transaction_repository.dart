import 'package:isar_community/isar.dart';

import '../../../../core/database/isar_service.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/data/repositories/category_repository.dart';
import '../models/recurring_transaction_mapper.dart';
import '../models/recurring_transaction_model.dart';
import '../remote/recurring_transaction_remote_source.dart';

class RecurringTransactionRepository {
  final RecurringTransactionRemoteSource remote;
  final CategoryRepository categoryRepository;
  final Isar _isar = IsarService.isar;

  RecurringTransactionRepository({
    required this.remote,
    required this.categoryRepository,
  });

  Future<List<RecurringTransactionModel>> getAll() async {
    if (!remote.isAuthenticated) {
      return _getLocalTemplates();
    }

    try {
      await categoryRepository.getAll();
      final remoteTemplates = await fetchRemoteRecurringTransactions();
      await _mergeRemoteTemplates(remoteTemplates);
      await _uploadPendingLocalTemplates();
    } catch (_) {
      // Keep local templates available when remote sync fails.
    }

    return _getLocalTemplates();
  }

  Future<RecurringTransactionModel?> getById(int id) {
    return _isar.recurringTransactionModels.get(id);
  }

  Future<RecurringTransactionModel> save(
    RecurringTransactionModel template,
  ) async {
    if (remote.isAuthenticated) {
      try {
        await categoryRepository.getAll();
        final saved = template.remoteId == null
            ? await uploadRecurringTransaction(template)
            : await updateRemoteRecurringTransaction(template);
        template.remoteId = saved.remoteId;
      } catch (_) {
        // Keep local save even if remote sync fails.
      }
    }

    await _isar.writeTxn(() async {
      template.id = await _isar.recurringTransactionModels.put(template);
    });

    return template;
  }

  Future<void> delete(int id) async {
    final template = await _isar.recurringTransactionModels.get(id);
    if (template == null) return;

    if (remote.isAuthenticated && template.remoteId != null) {
      try {
        await deleteRemoteRecurringTransaction(template.remoteId!);
      } catch (_) {
        // Keep local delete when remote is unavailable.
      }
    }

    await _isar.writeTxn(() async {
      await _isar.recurringTransactionModels.delete(template.id);
    });
  }

  Future<List<RecurringTransactionModel>> _getLocalTemplates() async {
    return _isar.recurringTransactionModels
        .where()
        .sortByNextDueDate()
        .findAll();
  }

  Future<void> _mergeRemoteTemplates(
    List<RecurringTransactionModel> remoteTemplates,
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
      final existing =
          localByRemoteId[remoteTemplate.remoteId] ??
          localByFingerprint[_fingerprint(remoteTemplate)];
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
        ..updatedAt = remoteTemplate.updatedAt;
      merged.add(template);
    }

    if (merged.isEmpty) return;

    await _isar.writeTxn(() async {
      await _isar.recurringTransactionModels.putAll(merged);
    });
  }

  Future<void> _uploadPendingLocalTemplates() async {
    final localTemplates = await _isar.recurringTransactionModels
        .filter()
        .remoteIdIsNull()
        .findAll();

    for (final template in localTemplates) {
      try {
        final saved = await uploadRecurringTransaction(template);
        template.remoteId = saved.remoteId;
        await _isar.writeTxn(() async {
          await _isar.recurringTransactionModels.put(template);
        });
      } catch (_) {
        // Keep unsynced local templates intact and retry later.
      }
    }
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

    return template.toJson(userId, categoryRemoteId: categoryRemoteId);
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

    return RecurringTransactionMapper.fromJson(json, categoryId: categoryId);
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
    final categories = await _isar.categoryModels.where().findAll();
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
