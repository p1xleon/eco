import 'package:isar_community/isar.dart';

import '../../../../core/database/isar_service.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final Isar _isar = IsarService.isar;

  Future<List<CategoryModel>> getAll() {
    return _isar.categoryModels.where().findAll();
  }

  Future<void> add(CategoryModel category) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.put(category);
    });
  }

  Future<void> update(CategoryModel category) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.put(category);
    });
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.delete(id);
    });
  }
}
