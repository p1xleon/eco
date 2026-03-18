import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/default_categories.dart';
import '../constants/default_transaction_presets.dart';
import '../../features/recurring/data/models/recurring_transaction_model.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../../features/categories/data/models/category_model.dart';
import '../../features/settings/data/models/transaction_preset_model.dart';

class IsarService {
  static late Isar isar;
  static Future<Isar>? _initFuture;
  static const _instanceName = Isar.defaultName;

  static Future<void> init() async {
    final existing = Isar.getInstance(_instanceName);
    if (existing != null && existing.isOpen) {
      isar = existing;
      return;
    }

    if (_initFuture != null) {
      isar = await _initFuture!;
      return;
    }

    _initFuture = _openWithRetry();
    isar = await _initFuture!;
    _initFuture = null;
  }

  static Future<Isar> _openWithRetry() async {
    final dir = await getApplicationDocumentsDirectory();
    const retryDelays = [
      Duration(milliseconds: 150),
      Duration(milliseconds: 350),
      Duration(milliseconds: 700),
    ];

    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      final existing = Isar.getInstance(_instanceName);
      if (existing != null && existing.isOpen) {
        return existing;
      }

      try {
        return await Isar.open(
          [
            RecurringTransactionModelSchema,
            TransactionModelSchema,
            CategoryModelSchema,
            TransactionPresetModelSchema,
          ],
          directory: dir.path,
          name: _instanceName,
        );
      } on IsarError catch (error) {
        final isRetryable = error.toString().contains('MdbxError (11)');
        if (!isRetryable || attempt == retryDelays.length) {
          rethrow;
        }

        await Future<void>.delayed(retryDelays[attempt]);
      }
    }

    throw StateError('Failed to initialize Isar.');
  }

  static Future<void> resetLocalData() async {
    await isar.writeTxn(() async {
      await isar.clear();
      await isar.categoryModels.putAll(DefaultCategories.getAll());
      await isar.transactionPresetModels.putAll(
        DefaultTransactionPresets.getAll(),
      );
    });
  }
}
