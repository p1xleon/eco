import 'package:isar_community/isar.dart';

import '../constants/default_transaction_presets.dart';
import '../../features/settings/data/models/transaction_preset_model.dart';
import 'isar_service.dart';

class TransactionPresetSeeder {
  static Future<void> seed() async {
    final isar = IsarService.isar;
    final existing = await isar.transactionPresetModels.count();

    if (existing > 0) return;

    final presets = DefaultTransactionPresets.getAll();

    await isar.writeTxn(() async {
      await isar.transactionPresetModels.putAll(presets);
    });
  }

  static Future<void> ensureDefaults() async {
    final isar = IsarService.isar;
    final existing = await isar.transactionPresetModels.where().anyId().findAll();

    final existingKeys = existing
        .map((preset) => '${preset.type.name}:${preset.value.toLowerCase()}')
        .toSet();

    final missing = DefaultTransactionPresets.getAll().where((preset) {
      final key = '${preset.type.name}:${preset.value.toLowerCase()}';
      return !existingKeys.contains(key);
    }).toList();

    if (missing.isEmpty) return;

    await isar.writeTxn(() async {
      await isar.transactionPresetModels.putAll(missing);
    });
  }
}
