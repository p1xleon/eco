import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_backfill.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

CategoryModel buildCategory({
  String name = 'Food',
  CategoryType type = CategoryType.expense,
  int color = 0xFFE57373,
}) {
  return CategoryModel()
    ..name = name
    ..type = type
    ..color = color;
}

void main() {
  late FakeCategoryRemoteSource remote;
  late CategoryRepository repository;

  setUp(() async {
    await TestIsar.open();
    setNetwork(online: true);

    remote = FakeCategoryRemoteSource();
    repository = CategoryRepository(remote);
  });

  tearDown(() async {
    setNetwork(online: true);
    await TestIsar.close();
  });

  test('offline delete is not resurrected by the next pull', () async {
    await repository.add(buildCategory());
    final saved = (await repository.getAll()).single;
    expect(saved.remoteId, isNotNull);

    setNetwork(online: false);
    await repository.delete(saved.id);
    expect(await repository.getAll(), isEmpty);

    reconnect(repository.invalidateSyncWindow);
    final visible = await repository.getAll();

    expect(visible, isEmpty);
    expect(remote.rows, isEmpty);
  });

  test('offline rename survives the next pull', () async {
    await repository.add(buildCategory());
    final saved = (await repository.getAll()).single;

    setNetwork(online: false);
    saved.name = 'Groceries';
    await repository.update(saved);

    reconnect(repository.invalidateSyncWindow);
    final visible = await repository.getAll();

    expect(visible.single.name, 'Groceries');
    expect(remote.rows.values.single['name'], 'Groceries');
  });

  test('seeded defaults adopt the matching server category instead of '
      'duplicating it', () async {
    // A fresh install seeds locally with no remote id, then the backfill queues
    // the seeds as creates.
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.categoryModels.putAll([
        buildCategory(),
        buildCategory(name: 'Transport', color: 0xFF64B5F6),
      ]);
    });
    await SyncBackfill.run();

    // The server already has one of them from another device.
    remote.rows['category-existing'] = {
      'id': 'category-existing',
      'user_id': 'user-1',
      'name': 'Food',
      'type': 'expense',
      'color': 0xFFE57373,
      'icon': null,
    };

    final visible = await repository.getAll();

    expect(visible.map((item) => item.name), ['Food', 'Transport']);
    expect(remote.rows, hasLength(2));

    final food = visible.firstWhere((item) => item.name == 'Food');
    expect(food.remoteId, 'category-existing');
    expect(food.syncState, SyncState.synced);
  });

  test('backfill queues records the server has never seen', () async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.categoryModels.put(buildCategory());
    });

    final before = await IsarService.isar.categoryModels.where().findAll();
    expect(before.single.syncState, SyncState.synced);

    await SyncBackfill.run();

    final after = await IsarService.isar.categoryModels.where().findAll();
    expect(after.single.syncState, SyncState.pendingCreate);
  });
}
