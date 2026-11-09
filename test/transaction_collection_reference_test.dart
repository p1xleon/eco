import 'package:eco/core/database/isar_service.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:eco/features/collections/data/repositories/collection_repository.dart';
import 'package:eco/features/transactions/data/models/transaction_mapper.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

TransactionModel buildTx({int? collectionId}) => TransactionModel()
  ..title = 'Hotel'
  ..amount = 120
  ..date = DateTime.utc(2026, 10, 1)
  ..type = TransactionType.expense
  ..categoryId = 1
  ..collectionId = collectionId
  ..createdAt = DateTime.utc(2026, 10, 1);

Future<CollectionModel> putCollection({String? remoteId}) async {
  final c = CollectionModel()
    ..name = 'Trip'
    ..color = 0
    ..remoteId = remoteId
    ..syncState = remoteId == null ? SyncState.pendingCreate : SyncState.synced;
  await IsarService.isar.writeTxn(() async {
    c.id = await IsarService.isar.collectionModels.put(c);
  });
  return c;
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

  tearDown(TestIsar.close);

  test('mapper writes and reads the collection uuid column', () {
    final json = buildTx().toJson('user-1', collectionRemoteId: 'c-uuid');
    expect(json[transactionCollectionRemoteIdColumn], 'c-uuid');

    final back = TransactionMapper.fromJson({
      ...json,
      'id': 'tx-1',
    }, collectionId: 5);
    expect(back.collectionId, 5);
  });

  test(
    'a synced collection travels as its uuid and resolves on pull',
    () async {
      final collection = await putCollection(remoteId: 'c-uuid');
      await repository.add(buildTx(collectionId: collection.id));

      expect(
        remote.rows.values.single[transactionCollectionRemoteIdColumn],
        'c-uuid',
      );

      repository.invalidateSyncWindow();
      final pulled = (await repository.getAll()).single;
      expect(pulled.collectionId, collection.id);
    },
  );

  test(
    'pull keeps the link to a collection the server has not seen yet',
    () async {
      final collection = await putCollection(); // pendingCreate, no uuid
      await repository.add(buildTx(collectionId: collection.id));

      expect(
        remote.rows.values.single[transactionCollectionRemoteIdColumn],
        isNull,
      );

      repository.invalidateSyncWindow();
      final pulled = (await repository.getAll()).single;
      expect(pulled.collectionId, collection.id);
    },
  );

  test(
    'a uuid pointing at a locally deleted collection resolves to none',
    () async {
      final collection = await putCollection(remoteId: 'c-uuid');
      await repository.add(buildTx(collectionId: collection.id));

      collection.syncState = SyncState.pendingDelete;
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.collectionModels.put(collection);
      });

      repository.invalidateSyncWindow();
      expect((await repository.getAll()).single.collectionId, isNull);
    },
  );

  test(
    'a collection that syncs mid-push still reaches the transaction',
    () async {
      final collection = await putCollection(); // pendingCreate, no uuid
      final collections = CollectionRepository(FakeCollectionRemoteSource());

      // The transaction is already on the wire with a null collection when the
      // collection's own first push lands.
      remote.onInsert = collections.pushPendingChanges;
      await repository.add(buildTx(collectionId: collection.id));
      remote.onInsert = null;

      expect(
        remote.rows.values.single[transactionCollectionRemoteIdColumn],
        isNull,
      );

      await repository.pushPendingChanges();

      final uuid = (await IsarService.isar.collectionModels.get(
        collection.id,
      ))!.remoteId;
      expect(uuid, isNotNull);
      expect(
        remote.rows.values.single[transactionCollectionRemoteIdColumn],
        uuid,
      );
    },
  );
}
