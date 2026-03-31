import 'package:isar_community/isar.dart';

import '../../../../core/database/isar_service.dart';
import '../models/category_mapper.dart';
import '../models/category_model.dart';
import '../remote/category_remote_source.dart';

class CategoryRepository {
  final CategoryRemoteSource remote;
  final Isar _isar = IsarService.isar;

  CategoryRepository(this.remote);

  Future<List<CategoryModel>> getAll() async {
    if (!remote.isAuthenticated) {
      return _getLocalCategories();
    }

    try {
      final remoteCategories = await fetchRemoteCategories();
      await _mergeRemoteCategories(remoteCategories);
      await _uploadPendingLocalCategories();
    } catch (_) {
      // Keep local data available when remote sync fails.
    }

    return _getLocalCategories();
  }

  Future<void> add(CategoryModel category) async {
    if (remote.isAuthenticated) {
      try {
        final saved = await uploadCategory(category);
        category.remoteId = saved.remoteId;
      } catch (_) {
        // Keep local save even if remote sync fails.
      }
    }

    await _saveLocal(category);
  }

  Future<void> update(CategoryModel category) async {
    if (remote.isAuthenticated) {
      try {
        final saved = category.remoteId == null
            ? await uploadCategory(category)
            : await updateRemoteCategory(category);
        category.remoteId = saved.remoteId;
      } catch (_) {
        // Keep local edits even if remote sync fails.
      }
    }

    await _saveLocal(category);
  }

  Future<void> delete(int id) async {
    final category = await _isar.categoryModels.get(id);
    if (category == null) return;

    if (remote.isAuthenticated && category.remoteId != null) {
      try {
        await deleteRemoteCategory(category.remoteId!);
      } catch (_) {
        // Still allow local-first delete when remote is unavailable.
      }
    }

    await _isar.writeTxn(() async {
      await _isar.categoryModels.delete(category.id);
    });
  }

  Future<List<CategoryModel>> _getLocalCategories() async {
    final categories = await _isar.categoryModels.where().findAll();
    categories.sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) return typeCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return categories;
  }

  Future<void> _saveLocal(CategoryModel category) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.put(category);
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
    final localByFingerprint = <String, CategoryModel>{
      for (final category in localCategories)
        if (category.remoteId == null) _fingerprint(category): category,
    };
    final merged = <CategoryModel>[];

    for (final remoteCategory in remoteCategories) {
      final existing =
          localByRemoteId[remoteCategory.remoteId] ??
          localByFingerprint[_fingerprint(remoteCategory)];
      final category = existing ?? CategoryModel();

      category
        ..id = existing?.id ?? category.id
        ..remoteId = remoteCategory.remoteId
        ..name = remoteCategory.name
        ..type = remoteCategory.type
        ..color = remoteCategory.color
        ..icon = remoteCategory.icon;
      merged.add(category);
    }

    if (merged.isEmpty) return;

    await _isar.writeTxn(() async {
      await _isar.categoryModels.putAll(merged);
    });
  }

  Future<void> _uploadPendingLocalCategories() async {
    final localCategories = await _isar.categoryModels
        .filter()
        .remoteIdIsNull()
        .findAll();

    for (final category in localCategories) {
      try {
        final saved = await uploadCategory(category);
        category.remoteId = saved.remoteId;
        await _saveLocal(category);
      } catch (_) {
        // Keep unsynced local categories intact and retry later.
      }
    }
  }

  Future<CategoryModel> uploadCategory(CategoryModel category) async {
    final user = remote.currentUser;
    if (user == null) return category;

    final data = await remote.addCategory(category.toJson(user.id));
    return CategoryMapper.fromJson(data);
  }

  Future<CategoryModel> updateRemoteCategory(CategoryModel category) async {
    final user = remote.currentUser;
    if (user == null || category.remoteId == null) {
      return category;
    }

    final data = await remote.updateCategory(
      category.remoteId!,
      category.toJson(user.id),
    );
    return CategoryMapper.fromJson(data);
  }

  Future<List<CategoryModel>> fetchRemoteCategories() async {
    final data = await remote.fetchCategories();
    return data.map(CategoryMapper.fromJson).toList();
  }

  Future<void> deleteRemoteCategory(String id) async {
    await remote.deleteCategory(id);
  }

  String _fingerprint(CategoryModel category) {
    return '${category.type.name}:${category.name.trim().toLowerCase()}';
  }
}
