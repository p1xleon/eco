import 'package:isar_community/isar.dart';

import '../../../../core/database/isar_service.dart';
import '../models/recurring_transaction_model.dart';

class RecurringTransactionRepository {
  final Isar _isar = IsarService.isar;

  Future<List<RecurringTransactionModel>> getAll() {
    return _isar.recurringTransactionModels
        .where()
        .sortByNextDueDate()
        .findAll();
  }

  Future<RecurringTransactionModel?> getById(int id) {
    return _isar.recurringTransactionModels.get(id);
  }

  Future<RecurringTransactionModel> save(RecurringTransactionModel template) async {
    await _isar.writeTxn(() async {
      template.id = await _isar.recurringTransactionModels.put(template);
    });

    return template;
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.recurringTransactionModels.delete(id);
    });
  }
}
