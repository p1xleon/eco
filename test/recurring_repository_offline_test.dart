import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/recurring/data/repositories/recurring_transaction_repository.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

RecurringTransactionModel buildTemplate({
  String title = 'Rent',
  required int categoryId,
}) {
  final now = DateTime.utc(2026, 8, 17);

  return RecurringTransactionModel()
    ..title = title
    ..type = TransactionType.expense
    ..defaultAmount = 800
    ..amountType = RecurringAmountType.fixed
    ..categoryId = categoryId
    ..intervalType = RecurringIntervalType.monthly
    ..intervalCount = 1
    ..nextDueDate = now
    ..isActive = true
    ..createdAt = now;
}

void main() {
  late FakeRecurringTransactionRemoteSource remote;
  late FakeCategoryRemoteSource categoryRemote;
  late RecurringTransactionRepository repository;
  late int categoryId;

  setUp(() async {
    await TestIsar.open();
    setNetwork(online: true);

    remote = FakeRecurringTransactionRemoteSource();
    categoryRemote = FakeCategoryRemoteSource();

    final categoryRepository = CategoryRepository(categoryRemote);
    await categoryRepository.add(
      CategoryModel()
        ..name = 'Housing'
        ..type = CategoryType.expense
        ..color = 0xFF64B5F6,
    );
    categoryId = (await categoryRepository.getAll()).single.id;

    repository = RecurringTransactionRepository(
      remote: remote,
      categoryRepository: categoryRepository,
    );
  });

  tearDown(() async {
    setNetwork(online: true);
    await TestIsar.close();
  });

  test('template created offline is queued and pushed on reconnect', () async {
    setNetwork(online: false);

    final saved = await repository.save(buildTemplate(categoryId: categoryId));
    expect(saved.syncState, SyncState.pendingCreate);
    expect(remote.rows, isEmpty);
    expect(await repository.getAll(), hasLength(1));

    reconnect(repository.invalidateSyncWindow);
    await repository.getAll();

    expect(remote.rows, hasLength(1));
    expect(await repository.pendingCount(), 0);
  });

  test('edit made offline is not clobbered by the next pull', () async {
    final saved = await repository.save(buildTemplate(categoryId: categoryId));
    expect(saved.remoteId, isNotNull);

    setNetwork(online: false);
    saved.title = 'Rent (new flat)';
    await repository.save(saved);

    reconnect(repository.invalidateSyncWindow);
    final templates = await repository.getAll();

    expect(templates.single.title, 'Rent (new flat)');
    expect(remote.rows.values.single['title'], 'Rent (new flat)');
  });

  test('delete made offline is not resurrected', () async {
    final saved = await repository.save(buildTemplate(categoryId: categoryId));

    setNetwork(online: false);
    await repository.delete(saved.id);
    expect(await repository.getAll(), isEmpty);
    expect(await repository.getById(saved.id), isNull);

    reconnect(repository.invalidateSyncWindow);
    expect(await repository.getAll(), isEmpty);
    expect(remote.rows, isEmpty);
  });

  test('a template the server cannot describe is not deleted locally',
      () async {
    final saved = await repository.save(buildTemplate(categoryId: categoryId));
    final remoteId = saved.remoteId!;

    // The server row points at a category this device does not have, so it
    // cannot be parsed into a local template. That must not read as "deleted
    // on the server".
    remote.rows[remoteId] = {
      ...remote.rows[remoteId]!,
      'category_id': 'category-unknown-elsewhere',
    };

    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.categoryModels.clear();
    });

    repository.invalidateSyncWindow();
    final templates = await repository.getAll();

    expect(templates, hasLength(1));
    expect(templates.single.remoteId, remoteId);
  });
}
