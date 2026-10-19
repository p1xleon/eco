import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

TransactionModel build(String title) {
  final now = DateTime.utc(2026, 8, 17);

  return TransactionModel()
    ..title = title
    ..amount = 4.5
    ..date = now
    ..type = TransactionType.expense
    ..categoryId = 1
    ..createdAt = now;
}

void main() {
  late FakeTransactionRemoteSource remote;
  late TransactionRepository repository;

  setUp(() async {
    await TestIsar.open();
    setNetwork(online: true);

    remote = FakeTransactionRemoteSource();
    repository = TransactionRepository(
      remote,
      categoryRepository: CategoryRepository(FakeCategoryRemoteSource()),
    );
  });

  tearDown(() async {
    setNetwork(online: true);
    await TestIsar.close();
  });

  test('a lost reply does not insert the transaction twice', () async {
    remote.loseNextReply = true;
    final saved = await repository.add(build('Coffee'));

    // The server kept the row, the app never heard back.
    expect(remote.rows, hasLength(1));
    expect(saved.syncState, SyncState.pendingCreate);
    expect(saved.remoteId, remote.rows.keys.single);

    repository.invalidateSyncWindow();
    final local = await repository.getAll();

    expect(remote.rows, hasLength(1));
    expect(local, hasLength(1));
    expect(local.single.syncState, SyncState.synced);
  });

  test('an edit made while the create is in flight is not lost', () async {
    remote.onInsert = () async {
      remote.onInsert = null;
      final inFlight = await IsarService.isar.transactionModels
          .where()
          .findFirst();
      await repository.update(inFlight!..title = 'Edited');
    };

    await repository.add(build('Original'));

    repository.invalidateSyncWindow();
    final local = await repository.getAll();

    expect(local.single.title, 'Edited');
    expect(remote.rows.values.single['title'], 'Edited');
    expect(remote.rows, hasLength(1));
  });

  test('editing a row that was deleted elsewhere puts it back, once', () async {
    final saved = await repository.add(build('Rent'));
    final id = saved.remoteId!;

    remote.rows.clear(); // deleted on another device
    await repository.update(saved..title = 'Rent (edited)');

    expect(remote.rows.keys, [id]);
    expect(remote.rows[id]!['title'], 'Rent (edited)');
    expect((await repository.getAll()).single.syncState, SyncState.synced);
  });

  test(
    'deleting after a lost reply removes the orphan from the server',
    () async {
      remote.loseNextReply = true;
      final saved = await repository.add(build('Oops'));
      expect(remote.rows, hasLength(1));

      await repository.delete(saved.id);

      expect(remote.rows, isEmpty);
      expect(await repository.getAll(), isEmpty);
    },
  );
}
