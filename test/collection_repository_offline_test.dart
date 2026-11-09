import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_backfill.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:eco/features/collections/data/repositories/collection_repository.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

CollectionModel buildCollection({String name = 'Lisbon trip'}) {
  return CollectionModel()
    ..name = name
    ..color = 0xFF3B82F6;
}

TransactionModel buildTransaction({
  int? collectionId,
  SyncState syncState = SyncState.synced,
  String? remoteId = 'tx-1',
}) {
  return TransactionModel()
    ..remoteId = remoteId
    ..title = 'Hotel'
    ..amount = 120
    ..date = DateTime.utc(2026, 10, 1)
    ..type = TransactionType.expense
    ..categoryId = 1
    ..collectionId = collectionId
    ..createdAt = DateTime.utc(2026, 10, 1)
    ..syncState = syncState;
}

void main() {
  late FakeCollectionRemoteSource remote;
  late CollectionRepository repository;

  setUp(() async {
    await TestIsar.open();
    setNetwork(online: true);

    remote = FakeCollectionRemoteSource();
    repository = CollectionRepository(remote);
  });

  tearDown(() async {
    setNetwork(online: true);
    await TestIsar.close();
  });

  test('offline delete is not resurrected by the next pull', () async {
    await repository.add(buildCollection());
    final saved = (await repository.getAll()).single;
    expect(saved.remoteId, isNotNull);

    setNetwork(online: false);
    await repository.delete(saved.id);
    expect(await repository.getAll(), isEmpty);

    reconnect(repository.invalidateSyncWindow);
    expect(await repository.getAll(), isEmpty);
    expect(remote.rows, isEmpty);
  });

  test('offline rename survives the next pull', () async {
    await repository.add(buildCollection());
    final saved = (await repository.getAll()).single;

    setNetwork(online: false);
    saved.name = 'Porto trip';
    await repository.update(saved);

    reconnect(repository.invalidateSyncWindow);
    expect((await repository.getAll()).single.name, 'Porto trip');
    expect(remote.rows.values.single['name'], 'Porto trip');
  });

  test('delete un-assigns its transactions and keeps them', () async {
    await repository.add(buildCollection());
    final collection = (await repository.getAll()).single;
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.transactionModels.put(
        buildTransaction(collectionId: collection.id),
      );
    });

    await repository.delete(collection.id);

    final tx =
        (await IsarService.isar.transactionModels.where().findAll()).single;
    expect(tx.collectionId, isNull);
    expect(tx.title, 'Hotel');
  });

  test('a collection deleted on another device disappears locally', () async {
    await repository.add(buildCollection());
    final collection = (await repository.getAll()).single;
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.transactionModels.put(
        buildTransaction(collectionId: collection.id),
      );
    });
    remote.rows.clear();

    repository.invalidateSyncWindow();
    expect(await repository.getAll(), isEmpty);

    // Un-assigned here too, so no push sends the now-dead uuid.
    final tx =
        (await IsarService.isar.transactionModels.where().findAll()).single;
    expect(tx.collectionId, isNull);
  });

  test('first push re-queues synced transactions that point at it', () async {
    setNetwork(online: false);
    await repository.add(buildCollection());
    final collection = (await repository.getAll()).single;
    expect(collection.remoteId, isNull);

    // Pushed while the collection was unsynced, so the server row holds null.
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.transactionModels.put(
        buildTransaction(collectionId: collection.id),
      );
    });

    reconnect(repository.invalidateSyncWindow);
    await repository.getAll();

    final tx =
        (await IsarService.isar.transactionModels.where().findAll()).single;
    expect(tx.syncState, SyncState.pendingUpdate);
  });

  test('backfill queues collections the server has never seen', () async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.collectionModels.put(buildCollection());
    });

    await SyncBackfill.run();

    final after = await IsarService.isar.collectionModels.where().findAll();
    expect(after.single.syncState, SyncState.pendingCreate);
  });
}
