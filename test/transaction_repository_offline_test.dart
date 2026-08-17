import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

TransactionModel buildTransaction({
  String title = 'Coffee',
  double amount = 4.5,
  TransactionType type = TransactionType.expense,
}) {
  final now = DateTime.utc(2026, 8, 17);

  return TransactionModel()
    ..title = title
    ..amount = amount
    ..date = now
    ..type = type
    ..categoryId = 1
    ..createdAt = now;
}

void main() {
  late FakeTransactionRemoteSource remote;
  late FakeCategoryRemoteSource categoryRemote;
  late TransactionRepository repository;

  setUp(() async {
    await TestIsar.open();
    setNetwork(online: true);

    remote = FakeTransactionRemoteSource();
    categoryRemote = FakeCategoryRemoteSource();
    repository = TransactionRepository(
      remote,
      categoryRepository: CategoryRepository(categoryRemote),
    );
  });

  tearDown(() async {
    setNetwork(online: true);
    await TestIsar.close();
  });

  group('offline writes', () {
    test('create is stored locally and queued', () async {
      setNetwork(online: false);

      final saved = await repository.add(buildTransaction());

      expect(saved.remoteId, isNull);
      expect(saved.syncState, SyncState.pendingCreate);
      expect(remote.rows, isEmpty);

      final visible = await repository.getAll();
      expect(visible, hasLength(1));
      expect(visible.single.title, 'Coffee');
    });

    test('edit of an already-synced record survives', () async {
      final saved = await repository.add(buildTransaction());
      expect(saved.remoteId, isNotNull);
      expect(saved.syncState, SyncState.synced);

      setNetwork(online: false);
      saved.title = 'Edited offline';
      await repository.update(saved);

      final visible = await repository.getAll();
      expect(visible.single.title, 'Edited offline');
      expect(visible.single.syncState, SyncState.pendingUpdate);
      // The server still has the old value; the edit is queued, not lost.
      expect(remote.rows.values.single['title'], 'Coffee');
    });

    test('delete of an already-synced record hides it and queues a tombstone',
        () async {
      final saved = await repository.add(buildTransaction());

      setNetwork(online: false);
      await repository.delete(saved.id);

      expect(await repository.getAll(), isEmpty);
      expect(remote.rows, hasLength(1));

      final stored = await IsarService.isar.transactionModels.get(saved.id);
      expect(stored, isNotNull);
      expect(stored!.syncState, SyncState.pendingDelete);
    });

    test('delete of a never-synced record removes it outright', () async {
      setNetwork(online: false);
      final saved = await repository.add(buildTransaction());

      await repository.delete(saved.id);

      expect(await IsarService.isar.transactionModels.count(), 0);
    });
  });

  group('reconnect', () {
    test('queued create, edit and delete are replayed', () async {
      setNetwork(online: false);

      final created = await repository.add(buildTransaction(title: 'Created'));
      expect(remote.rows, isEmpty);

      reconnect(repository.invalidateSyncWindow);
      await repository.getAll();

      expect(remote.rows, hasLength(1));
      final stored = await IsarService.isar.transactionModels.get(created.id);
      expect(stored!.syncState, SyncState.synced);
      expect(stored.remoteId, isNotNull);

      // Edit it while offline, then reconnect.
      setNetwork(online: false);
      stored.title = 'Edited';
      await repository.update(stored);
      reconnect(repository.invalidateSyncWindow);
      await repository.getAll();

      expect(remote.rows.values.single['title'], 'Edited');

      // And delete it while offline.
      setNetwork(online: false);
      await repository.delete(stored.id);
      reconnect(repository.invalidateSyncWindow);
      await repository.getAll();

      expect(remote.rows, isEmpty);
      expect(await IsarService.isar.transactionModels.count(), 0);
    });

    test('a failed push leaves the record queued for the next attempt',
        () async {
      setNetwork(online: false);
      await repository.add(buildTransaction());

      // Network says it is back, but the server is still refusing.
      setNetwork(online: true);
      remote.isReachable = false;
      await repository.getAll();

      final stored = await IsarService.isar.transactionModels.where().findAll();
      expect(stored.single.syncState, SyncState.pendingCreate);

      remote.isReachable = true;
      await repository.getAll();

      expect(remote.rows, hasLength(1));
    });
  });

  group('merge', () {
    test('does not overwrite a record with unpushed local changes', () async {
      final saved = await repository.add(buildTransaction());
      final remoteId = saved.remoteId!;

      setNetwork(online: false);
      saved.title = 'Local edit';
      await repository.update(saved);

      // Someone else changed the same record on the server.
      remote.rows[remoteId] = {
        ...remote.rows[remoteId]!,
        'title': 'Server edit',
      };

      setNetwork(online: true);
      final visible = await repository.getAll();

      // The local edit is pushed rather than clobbered.
      expect(visible.single.title, 'Local edit');
      expect(remote.rows.values.single['title'], 'Local edit');
    });

    test('keeps local ids stable across a pull', () async {
      final saved = await repository.add(buildTransaction());
      final originalId = saved.id;

      await repository.getAll();
      await repository.getAll();

      final stored = await IsarService.isar.transactionModels.where().findAll();
      expect(stored.single.id, originalId);
    });

    test('applies a delete made on another device', () async {
      final saved = await repository.add(buildTransaction());
      remote.rows.remove(saved.remoteId);

      expect(await repository.getAll(), isEmpty);
      expect(await IsarService.isar.transactionModels.count(), 0);
    });

    test('does not resurrect a record deleted offline', () async {
      final saved = await repository.add(buildTransaction());

      setNetwork(online: false);
      await repository.delete(saved.id);

      // A pull happens before the tombstone can be pushed.
      setNetwork(online: true);
      remote.isReachable = true;
      final visible = await repository.getAll();

      expect(visible, isEmpty);
      expect(remote.rows, isEmpty);
    });

    test('a locally created record is not dropped by the delete reconcile',
        () async {
      setNetwork(online: false);
      await repository.add(buildTransaction(title: 'Offline only'));

      setNetwork(online: true);
      remote.isReachable = false;
      final visible = await repository.getAll();

      expect(visible, hasLength(1));
      expect(visible.single.title, 'Offline only');
    });
  });

  group('retry budget', () {
    test('being offline does not count against a record', () async {
      setNetwork(online: false);
      await repository.add(buildTransaction());

      // Several passes that all fail because there is no connection.
      for (var attempt = 0; attempt < maxSyncAttempts + 2; attempt++) {
        setNetwork(online: true);
        remote.isReachable = false;
        await repository.getAll();
      }

      final stored = await IsarService.isar.transactionModels.where().findAll();
      expect(stored.single.syncAttempts, 0);
      expect(await repository.blockedRecords(), isEmpty);

      remote.isReachable = true;
      await repository.getAll();
      expect(remote.rows, hasLength(1));
    });

    test('a rejected record stops retrying once the cap is reached', () async {
      setNetwork(online: false);
      await repository.add(buildTransaction());

      setNetwork(online: true);
      remote.rejectsWrites = true;

      for (var attempt = 0; attempt < maxSyncAttempts; attempt++) {
        repository.invalidateSyncWindow();
        await repository.getAll();
      }

      final blocked = await repository.blockedRecords();
      expect(blocked, hasLength(1));
      expect(blocked.single.syncAttempts, maxSyncAttempts);
      expect(blocked.single.lastSyncError, contains('row-level security'));

      // Further passes leave it alone rather than hammering the server.
      repository.invalidateSyncWindow();
      await repository.getAll();
      final stored = await IsarService.isar.transactionModels.where().findAll();
      expect(stored.single.syncAttempts, maxSyncAttempts);

      // The record is still there and still visible to the user.
      expect(await repository.getAll(), hasLength(1));
    });

    test('a manual retry gives a blocked record another chance', () async {
      setNetwork(online: false);
      await repository.add(buildTransaction());

      setNetwork(online: true);
      remote.rejectsWrites = true;
      for (var attempt = 0; attempt < maxSyncAttempts; attempt++) {
        repository.invalidateSyncWindow();
        await repository.getAll();
      }
      expect(await repository.blockedRecords(), hasLength(1));

      remote.rejectsWrites = false;
      await repository.retryBlockedRecords();
      repository.invalidateSyncWindow();
      await repository.getAll();

      expect(await repository.blockedRecords(), isEmpty);
      expect(remote.rows, hasLength(1));
      expect(await repository.pendingCount(), 0);
    });

    test('editing a blocked record clears its error', () async {
      setNetwork(online: true);
      remote.rejectsWrites = true;
      final saved = await repository.add(buildTransaction());

      for (var attempt = 0; attempt < maxSyncAttempts; attempt++) {
        repository.invalidateSyncWindow();
        await repository.getAll();
      }
      expect(await repository.blockedRecords(), hasLength(1));

      remote.rejectsWrites = false;
      saved.title = 'Fixed up';
      await repository.update(saved);

      expect(await repository.blockedRecords(), isEmpty);
      expect(remote.rows.values.single['title'], 'Fixed up');
    });
  });

  group('sync window', () {
    test('collapses repeated reads into a single round trip', () async {
      await repository.add(buildTransaction());
      final before = remote.fetchCount;

      await repository.getAll();
      await repository.getAll();
      await repository.getAll();

      expect(remote.fetchCount, before + 1);

      repository.invalidateSyncWindow();
      await repository.getAll();
      expect(remote.fetchCount, before + 2);
    });
  });

  group('bulk import', () {
    test('stores every row locally even with no connection', () async {
      setNetwork(online: false);

      final items = await repository.addAll([
        buildTransaction(title: 'One'),
        buildTransaction(title: 'Two'),
        buildTransaction(title: 'Three'),
      ]);

      expect(items, hasLength(3));
      expect(await repository.getAll(), hasLength(3));
      expect(await repository.pendingCount(), 3);

      setNetwork(online: true);
      await repository.getAll();

      expect(remote.rows, hasLength(3));
      expect(await repository.pendingCount(), 0);
    });
  });
}
