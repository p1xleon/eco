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

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();

    isar = await Isar.open([
      RecurringTransactionModelSchema,
      TransactionModelSchema,
      CategoryModelSchema,
      TransactionPresetModelSchema,
    ], directory: dir.path);
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
