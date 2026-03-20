import 'package:isar_community/isar.dart';

import '../../../../core/database/isar_service.dart';
import '../models/transaction_preset_model.dart';

class TransactionPresetRepository {
  final Isar _isar = IsarService.isar;

  Future<List<TransactionPresetModel>> getByType(TransactionPresetType type) {
    return _isar.transactionPresetModels
        .filter()
        .typeEqualTo(type)
        .sortByValue()
        .findAll();
  }

  Future<void> add(TransactionPresetType type, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final existing = await getByType(type);
    final hasDuplicate = existing.any(
      (preset) => preset.value.toLowerCase() == trimmed.toLowerCase(),
    );
    if (hasDuplicate) return;

    final preset = TransactionPresetModel()
      ..type = type
      ..value = trimmed;

    await _isar.writeTxn(() async {
      await _isar.transactionPresetModels.put(preset);
    });
  }

  Future<void> update(int id, TransactionPresetType type, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final existing = await getByType(type);
    final hasDuplicate = existing.any(
      (preset) =>
          preset.id != id &&
          preset.value.toLowerCase() == trimmed.toLowerCase(),
    );
    if (hasDuplicate) return;

    final preset = await _isar.transactionPresetModels.get(id);
    if (preset == null) return;

    preset
      ..type = type
      ..value = trimmed;

    await _isar.writeTxn(() async {
      await _isar.transactionPresetModels.put(preset);
    });
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.transactionPresetModels.delete(id);
    });
  }
}
