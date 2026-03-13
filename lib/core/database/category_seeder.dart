import '../../features/categories/data/models/category_model.dart';
import 'isar_service.dart';
import '../constants/default_categories.dart';

class CategorySeeder {
  static Future<void> seed() async {
    final isar = IsarService.isar;

    final existing = await isar.categoryModels.count();

    if (existing > 0) return;

    final categories = DefaultCategories.getAll();

    await isar.writeTxn(() async {
      await isar.categoryModels.putAll(categories);
    });
  }
}
