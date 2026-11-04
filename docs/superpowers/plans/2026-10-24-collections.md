# Collections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users group transactions into named Collections that have their own page and totals, while every transaction still counts in the normal list, dashboard and analytics.

**Architecture:** A new `collections` feature copied from `categories` (Isar model, mapper encrypting `name`, remote source, offline-first repository, Riverpod providers). `TransactionModel` gets a nullable `collectionId`; the server row gets `collection_remote_id` (uuid, FK `on delete set null`). UI adds a Collections tab, a collection detail page reusing `TransactionListGrouped`, a picker on the transaction form, and a filter in the filter sheet.

**Tech Stack:** Flutter, Riverpod 2 (`StateNotifier`, `FutureProvider`), Isar Community 3.3 (codegen via `build_runner`), Supabase, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-24-collections-design.md`

## Global Constraints

- The user-facing term is "Collection" everywhere (code, UI, SQL). Never "project", "space" or "folder".
- A transaction belongs to **at most one** collection (`collectionId` is `int?`).
- A collection is a grouping only. Nothing is ever excluded from overall totals.
- Deleting a collection un-assigns its transactions. It never deletes them.
- Only `name` is encrypted on the server (same as categories). `color` and `icon` stay readable.
- Totals use `roundCents` / `formatMoney` from `lib/core/utils/money.dart`, and amounts go through `TransactionVisibilityState.displayAmount` so masked mode hides them.
- Out of scope: budgets, archiving, collections on recurring templates or bulk add, a per-collection analytics page.
- Migrations are applied by hand in the Supabase dashboard (see `supabase/migrations/README.md`). Never run `supabase db push`.
- After any `@collection` model change, run `dart run build_runner build --delete-conflicting-outputs` and commit the regenerated `.g.dart` files.

## Review Focus

1. **Assigned to a collection that has not synced yet.** The transaction is pushed with `collection_remote_id = null`, and the next pull must not wipe the local link. Once the collection syncs, the transaction is re-pushed with the uuid. Tested in Task 3.
2. **Collection deleted while transactions point at it, offline.** Local transactions are un-assigned at once, and a pull before the delete is pushed must not re-link them. Tested in Tasks 2 and 3.
3. **Old backup (no `collections` key, no `collection_id` field).** Restores cleanly with nothing assigned. Tested in Task 5.
4. **Masked mode on the collection pages.** Totals show `•••`, never real numbers. Tested in Task 7.
5. **Collection deleted on another device.** The local list drops it, and its transactions show as unassigned rather than crashing a lookup. Tested in Tasks 2 and 6.

---

### Task 1: Collection model, mapper, remote source, Isar registration

**Files:**
- Create: `lib/features/collections/data/models/collection_model.dart`
- Create: `lib/features/collections/data/models/collection_mapper.dart`
- Create: `lib/features/collections/data/remote/collection_remote_source.dart`
- Create: `lib/features/collections/data/providers/collection_remote_provider.dart`
- Modify: `lib/features/transactions/data/models/transaction_model.dart` (add `collectionId`)
- Modify: `lib/core/database/isar_service.dart:51-57` (register schema)
- Modify: `test/support/test_isar.dart:23-29` (register schema)
- Test: `test/collection_mapper_test.dart`

**Interfaces:**
- Produces: `CollectionModel` (`id`, `remoteId`, `name`, `color`, `icon`, `syncState`, `localUpdatedAt`, `syncAttempts`, `lastSyncError`); `isar.collectionModels`; `CollectionMapper.toJson(String userId, {FieldCipher? cipher})`, `CollectionMapper.fromJson(Map<String, dynamic>, {FieldCipher? cipher})`; `CollectionRemoteSource` with `currentUser`, `isAuthenticated`, `addCollection`, `updateCollection`, `fetchCollections`, `deleteCollection`; `collectionRemoteSourceProvider`; `TransactionModel.collectionId` (`int?`).

- [ ] **Step 1: Write the failing test**

```dart
// test/collection_mapper_test.dart
import 'package:cryptography/cryptography.dart';
import 'package:eco/core/crypto/field_cipher.dart';
import 'package:eco/features/collections/data/models/collection_mapper.dart';
import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:flutter_test/flutter_test.dart';

FieldCipher cipherOf(int seed) => FieldCipher(
  SecretKeyData(List<int>.generate(32, (i) => (i + seed) & 0xFF)),
);

void main() {
  CollectionModel build() => CollectionModel()
    ..name = 'Lisbon trip'
    ..color = 0xFF3B82F6
    ..icon = 'flight';

  test('encrypts only the name and round-trips', () {
    final cipher = cipherOf(1);
    final json = build().toJson('user-1', cipher: cipher);

    expect(json['name'], isNot('Lisbon trip'));
    expect(json['color'], 0xFF3B82F6);
    expect(json['icon'], 'flight');
    expect(json['user_id'], 'user-1');

    final back = CollectionMapper.fromJson({...json, 'id': 'c-1'}, cipher: cipher);
    expect(back.remoteId, 'c-1');
    expect(back.name, 'Lisbon trip');
    expect(back.color, 0xFF3B82F6);
  });

  test('without a cipher the name stays readable', () {
    final json = build().toJson('user-1');
    expect(json['name'], 'Lisbon trip');
    expect(CollectionMapper.fromJson({...json, 'id': 'c-1'}).name, 'Lisbon trip');
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/collection_mapper_test.dart`
Expected: compile error, `collection_model.dart` not found.

- [ ] **Step 3: Create the model**

```dart
// lib/features/collections/data/models/collection_model.dart
import 'package:isar_community/isar.dart';

import '../../../../core/sync/sync_state.dart';

part 'collection_model.g.dart';

/// A user-named group of transactions, such as a trip or a renovation. A
/// grouping only: its transactions still count everywhere else.
@collection
class CollectionModel {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late String name;

  late int color;

  String? icon;

  /// What this record still owes the server. See [SyncState].
  @enumerated
  SyncState syncState = SyncState.synced;

  DateTime? localUpdatedAt;

  /// Consecutive times the server rejected this record. See [maxSyncAttempts].
  int syncAttempts = 0;

  String? lastSyncError;
}
```

- [ ] **Step 4: Create the mapper**

```dart
// lib/features/collections/data/models/collection_mapper.dart
import '../../../../core/crypto/field_cipher.dart';
import 'collection_model.dart';

extension CollectionMapper on CollectionModel {
  /// Builds the server row. Only `name` is encrypted, as with categories.
  Map<String, dynamic> toJson(String userId, {FieldCipher? cipher}) {
    return <String, dynamic>{
      'user_id': userId,
      'name': cipher == null ? name : cipher.encrypt(name),
      'color': color,
      'icon': icon,
    };
  }

  static CollectionModel fromJson(
    Map<String, dynamic> json, {
    FieldCipher? cipher,
  }) {
    return CollectionModel()
      ..remoteId = json['id'] as String?
      ..name = FieldCipher.readString(cipher, json['name'])!
      ..color = (json['color'] as num).toInt()
      ..icon = json['icon'] as String?;
  }
}
```

- [ ] **Step 5: Create the remote source and its provider**

```dart
// lib/features/collections/data/remote/collection_remote_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/remote_call.dart';

class CollectionRemoteSource {
  final SupabaseClient client;

  /// See [TransactionRemoteSource]: a full fetch has to page so the sync merge
  /// can trust it as the complete server state.
  static const _pageSize = 1000;

  CollectionRemoteSource(this.client);

  User? get currentUser => client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String get _currentUserId {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }

    return user.id;
  }

  Future<Map<String, dynamic>> addCollection(Map<String, dynamic> data) {
    return remoteCall(
      () async =>
          await client.from('collections').insert(data).select().single(),
    );
  }

  Future<Map<String, dynamic>> updateCollection(
    String id,
    Map<String, dynamic> data,
  ) {
    return remoteCall(
      () async => await client
          .from('collections')
          .update(data)
          .eq('id', id)
          .eq('user_id', _currentUserId)
          .select()
          .single(),
    );
  }

  Future<List<Map<String, dynamic>>> fetchCollections() async {
    final userId = _currentUserId;
    final all = <Map<String, dynamic>>[];

    for (var offset = 0; ; offset += _pageSize) {
      final page = await remoteCall(
        () async => await client
            .from('collections')
            .select()
            .eq('user_id', userId)
            // Names are ciphertext, so sorting by them is meaningless; id is
            // stable, which is all paging needs.
            .order('id', ascending: true)
            .range(offset, offset + _pageSize - 1),
      );

      all.addAll(page);
      if (page.length < _pageSize) break;
    }

    return all;
  }

  Future<void> deleteCollection(String id) {
    return remoteCall(
      () async => await client
          .from('collections')
          .delete()
          .eq('id', id)
          .eq('user_id', _currentUserId),
    );
  }
}
```

```dart
// lib/features/collections/data/providers/collection_remote_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../remote/collection_remote_source.dart';

final collectionRemoteSourceProvider = Provider<CollectionRemoteSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return CollectionRemoteSource(client);
});
```

- [ ] **Step 6: Add `collectionId` to `TransactionModel`**

In `lib/features/transactions/data/models/transaction_model.dart`, directly after `late int categoryId;`:

```dart
  /// The collection this transaction is grouped under, if any. Local Isar id;
  /// the server holds the collection's uuid instead.
  int? collectionId;
```

- [ ] **Step 7: Register the schema**

In `lib/core/database/isar_service.dart`, add the import
`import '../../features/collections/data/models/collection_model.dart';`
and add `CollectionModelSchema,` to the `Isar.open` list after `CategoryModelSchema,`.

In `test/support/test_isar.dart`, add
`import 'package:eco/features/collections/data/models/collection_model.dart';`
and add `CollectionModelSchema,` after `CategoryModelSchema,`.

- [ ] **Step 8: Generate code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: creates `collection_model.g.dart` and regenerates `transaction_model.g.dart` with no errors.

- [ ] **Step 9: Run the test and the full suite**

Run: `flutter test test/collection_mapper_test.dart && flutter test`
Expected: all PASS. Existing tests still pass because the new field is nullable.

- [ ] **Step 10: Commit**

```bash
git add lib/features/collections lib/features/transactions/data/models lib/core/database/isar_service.dart test/support/test_isar.dart test/collection_mapper_test.dart
git commit -m "feat: collection model, mapper and remote source"
```

---

### Task 2: CollectionRepository (offline-first) and providers

**Files:**
- Create: `lib/features/collections/data/repositories/collection_repository.dart`
- Create: `lib/features/collections/presentation/providers/collection_provider.dart`
- Modify: `test/support/fake_remote_sources.dart` (add `FakeCollectionRemoteSource`)
- Modify: `lib/core/sync/sync_backfill.dart` (include collections)
- Modify: `lib/core/sync/sync_providers.dart` (pending count, failures, syncNow order, retry)
- Test: `test/collection_repository_offline_test.dart`

**Interfaces:**
- Consumes: Task 1's `CollectionModel`, `CollectionMapper`, `CollectionRemoteSource`, `collectionRemoteSourceProvider`, `TransactionModel.collectionId`.
- Produces: `CollectionRepository(CollectionRemoteSource remote, {FieldCipher? cipher})` with `getAll()`, `add(CollectionModel)`, `update(CollectionModel)`, `delete(int id)`, `pushPendingChanges()`, `pendingCount()`, `blockedRecords()`, `retryBlockedRecords()`, `invalidateSyncWindow()`; `collectionRepositoryProvider`, `collectionsProvider` (`FutureProvider<List<CollectionModel>>`), `collectionsByIdProvider` (`FutureProvider<Map<int, CollectionModel>>`).

- [ ] **Step 1: Add the fake remote**

Append to `test/support/fake_remote_sources.dart`, and add the import `import 'package:eco/features/collections/data/remote/collection_remote_source.dart';`:

```dart
class FakeCollectionRemoteSource implements CollectionRemoteSource {
  final Map<String, Map<String, dynamic>> rows = {};

  bool isReachable = true;
  int _nextId = 1;

  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  User? get currentUser => _testUser;

  @override
  bool get isAuthenticated => true;

  void _guard() {
    if (!isReachable) throw _unreachable();
  }

  @override
  Future<Map<String, dynamic>> addCollection(Map<String, dynamic> data) async {
    _guard();

    final id = 'collection-${_nextId++}';
    final row = {...data, 'id': id};
    rows[id] = row;
    return row;
  }

  @override
  Future<Map<String, dynamic>> updateCollection(
    String id,
    Map<String, dynamic> data,
  ) async {
    _guard();

    final row = {...data, 'id': id};
    rows[id] = row;
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCollections() async {
    _guard();
    return rows.values.map((row) => {...row}).toList();
  }

  @override
  Future<void> deleteCollection(String id) async {
    _guard();
    rows.remove(id);
  }
}
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/collection_repository_offline_test.dart
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

    final tx = (await IsarService.isar.transactionModels.where().findAll())
        .single;
    expect(tx.collectionId, isNull);
    expect(tx.title, 'Hotel');
  });

  test('a collection deleted on another device disappears locally', () async {
    await repository.add(buildCollection());
    remote.rows.clear();

    repository.invalidateSyncWindow();
    expect(await repository.getAll(), isEmpty);
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

    final tx = (await IsarService.isar.transactionModels.where().findAll())
        .single;
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
```

- [ ] **Step 3: Run them and confirm they fail**

Run: `flutter test test/collection_repository_offline_test.dart`
Expected: compile error, `collection_repository.dart` not found.

- [ ] **Step 4: Implement the repository**

```dart
// lib/features/collections/data/repositories/collection_repository.dart
import 'package:isar_community/isar.dart';

import '../../../../core/crypto/field_cipher.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/network/network_monitor.dart';
import '../../../../core/network/remote_call.dart';
import '../../../../core/sync/sync_gate.dart';
import '../../../../core/sync/sync_issues.dart';
import '../../../../core/sync/sync_state.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../models/collection_mapper.dart';
import '../models/collection_model.dart';
import '../remote/collection_remote_source.dart';

/// Local-first collection storage, shaped like [CategoryRepository].
class CollectionRepository {
  final CollectionRemoteSource remote;
  final Isar _isar = IsarService.isar;
  final SyncGate _gate = SyncGate();

  /// Encrypts what leaves the device. Null until the user sets up a key.
  final FieldCipher? cipher;

  CollectionRepository(this.remote, {this.cipher});

  bool get _canSync =>
      remote.isAuthenticated && NetworkMonitor.instance.isOnline;

  Future<List<CollectionModel>> getAll() async {
    if (_canSync) {
      try {
        await _gate.run(() async {
          await _pullRemoteCollections();
          await pushPendingChanges();
        });
      } catch (_) {
        // Keep local data available when remote sync fails.
      }
    }

    return _getLocalCollections();
  }

  /// Makes the next [getAll] sync for real, skipping the recency window.
  void invalidateSyncWindow() => _gate.reset();

  Future<void> add(CollectionModel collection) async {
    collection.syncState = SyncState.pendingCreate;
    collection.localUpdatedAt = DateTime.now();
    _resetRetryBudget(collection);
    await _saveLocal(collection);

    if (_canSync) {
      await _pushCreate(collection);
    }
  }

  Future<void> update(CollectionModel collection) async {
    final isCreate = collection.remoteId == null;

    collection.syncState = isCreate
        ? SyncState.pendingCreate
        : SyncState.pendingUpdate;
    collection.localUpdatedAt = DateTime.now();
    _resetRetryBudget(collection);
    await _saveLocal(collection);

    if (_canSync) {
      if (isCreate) {
        await _pushCreate(collection);
      } else {
        await _pushUpdate(collection);
      }
    }
  }

  /// Removes the collection and un-assigns its transactions in the same write,
  /// so no transaction is ever left pointing at nothing. The transactions are
  /// not re-queued: the server's `on delete set null` clears them there.
  Future<void> delete(int id) async {
    final collection = await _isar.collectionModels.get(id);
    if (collection == null) return;

    final members = await _isar.transactionModels
        .filter()
        .collectionIdEqualTo(id)
        .findAll();
    for (final tx in members) {
      tx.collectionId = null;
    }

    if (collection.remoteId == null) {
      await _isar.writeTxn(() async {
        await _isar.transactionModels.putAll(members);
        await _isar.collectionModels.delete(collection.id);
      });
      return;
    }

    collection.syncState = SyncState.pendingDelete;
    collection.localUpdatedAt = DateTime.now();
    _resetRetryBudget(collection);
    await _isar.writeTxn(() async {
      await _isar.transactionModels.putAll(members);
      await _isar.collectionModels.put(collection);
    });

    if (_canSync) {
      await _pushDelete(collection);
    }
  }

  Future<void> pushPendingChanges() async {
    if (!_canSync) return;

    for (final local in await _pending(SyncState.pendingCreate)) {
      await _pushCreate(local);
    }
    for (final local in await _pending(SyncState.pendingUpdate)) {
      await _pushUpdate(local);
    }
    for (final local in await _pending(SyncState.pendingDelete)) {
      await _pushDelete(local);
    }
  }

  Future<int> pendingCount() {
    return _isar.collectionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.synced)
        .count();
  }

  Future<List<CollectionModel>> _pending(SyncState state) async {
    final records = await _isar.collectionModels
        .filter()
        .syncStateEqualTo(state)
        .findAll();

    return records
        .where((record) => !isSyncBlocked(record.syncAttempts))
        .toList();
  }

  /// Records the server keeps rejecting, which no longer retry on their own.
  Future<List<CollectionModel>> blockedRecords() async {
    final records = await _isar.collectionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.synced)
        .findAll();

    return records
        .where((record) => isSyncBlocked(record.syncAttempts))
        .toList();
  }

  /// Gives blocked records their retry budget back.
  Future<void> retryBlockedRecords() async {
    final records = await blockedRecords();
    if (records.isEmpty) return;

    for (final record in records) {
      _resetRetryBudget(record);
    }

    await _isar.writeTxn(() async {
      await _isar.collectionModels.putAll(records);
    });
  }

  void _resetRetryBudget(CollectionModel record) {
    record.syncAttempts = 0;
    record.lastSyncError = null;
  }

  Future<void> _recordPushFailure(CollectionModel local, Object error) async {
    if (isNetworkFailure(error)) return;

    local.syncAttempts += 1;
    local.lastSyncError = describeSyncError(error);
    await _saveLocal(local);
  }

  Future<bool> _pushCreate(CollectionModel local) async {
    try {
      final user = remote.currentUser;
      if (user == null) return false;

      final saved = CollectionMapper.fromJson(
        await remote.addCollection(local.toJson(user.id, cipher: cipher)),
        cipher: cipher,
      );
      if (saved.remoteId == null) return false;

      local.remoteId = saved.remoteId;
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);
      await _saveLocal(local);
      await _requeueMembers(local.id);
      return true;
    } catch (error) {
      // Keep the local record and retry on the next sync.
      await _recordPushFailure(local, error);
      return false;
    }
  }

  /// Transactions assigned while this collection had no uuid went up with a
  /// null `collection_remote_id`. Now there is a uuid, push them again.
  Future<void> _requeueMembers(int collectionId) async {
    final members = await _isar.transactionModels
        .filter()
        .collectionIdEqualTo(collectionId)
        .syncStateEqualTo(SyncState.synced)
        .findAll();
    if (members.isEmpty) return;

    for (final tx in members) {
      tx.syncState = SyncState.pendingUpdate;
    }
    await _isar.writeTxn(() async {
      await _isar.transactionModels.putAll(members);
    });
  }

  Future<bool> _pushUpdate(CollectionModel local) async {
    final remoteId = local.remoteId;
    if (remoteId == null) {
      return _pushCreate(local);
    }

    try {
      final user = remote.currentUser;
      if (user == null) return false;

      await remote.updateCollection(
        remoteId,
        local.toJson(user.id, cipher: cipher),
      );
      local.syncState = SyncState.synced;
      _resetRetryBudget(local);
      await _saveLocal(local);
      return true;
    } catch (error) {
      await _recordPushFailure(local, error);
      return false;
    }
  }

  Future<bool> _pushDelete(CollectionModel local) async {
    final remoteId = local.remoteId;

    if (remoteId != null) {
      try {
        await remote.deleteCollection(remoteId);
      } catch (error) {
        await _recordPushFailure(local, error);
        return false;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.collectionModels.delete(local.id);
    });
    return true;
  }

  Future<List<CollectionModel>> _getLocalCollections() async {
    final collections = await _isar.collectionModels
        .filter()
        .not()
        .syncStateEqualTo(SyncState.pendingDelete)
        .findAll();
    collections.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return collections;
  }

  Future<void> _saveLocal(CollectionModel collection) async {
    await _isar.writeTxn(() async {
      collection.id = await _isar.collectionModels.put(collection);
    });
  }

  /// Skips rows this device cannot read instead of failing the whole pull, but
  /// still counts them as present on the server so good local copies survive.
  Future<void> _pullRemoteCollections() async {
    final data = await remote.fetchCollections();
    final readable = <CollectionModel>[];
    var unreadable = 0;
    for (final json in data) {
      try {
        readable.add(CollectionMapper.fromJson(json, cipher: cipher));
      } catch (_) {
        unreadable++;
      }
    }
    SyncIssues.reportUnreadable('collections', unreadable);

    final serverIds = {
      for (final json in data)
        if (json['id'] is String) json['id'] as String,
    };

    final locals = await _isar.collectionModels.where().findAll();
    final localByRemoteId = <String, CollectionModel>{
      for (final local in locals)
        if (local.remoteId != null) local.remoteId!: local,
    };

    final merged = <CollectionModel>[];
    for (final incoming in readable) {
      final existing = localByRemoteId[incoming.remoteId];

      // Pending local changes win until the push resolves them.
      if (existing != null && existing.syncState.isPending) continue;

      incoming
        ..id = existing?.id ?? incoming.id
        ..syncState = SyncState.synced
        ..localUpdatedAt = existing?.localUpdatedAt;
      merged.add(incoming);
    }

    // Synced rows the server no longer has were deleted on another device.
    final removedIds = [
      for (final local in locals)
        if (local.syncState == SyncState.synced &&
            local.remoteId != null &&
            !serverIds.contains(local.remoteId))
          local.id,
    ];

    if (merged.isEmpty && removedIds.isEmpty) return;

    await _isar.writeTxn(() async {
      if (removedIds.isNotEmpty) {
        await _isar.collectionModels.deleteAll(removedIds);
      }
      if (merged.isNotEmpty) {
        await _isar.collectionModels.putAll(merged);
      }
    });
  }
}
```

> Check before relying on it: `SyncState.isPending` is used in `transaction_repository.dart:538`, so it exists. Confirm that it covers `pendingCreate`, `pendingUpdate` and `pendingDelete` in `lib/core/sync/sync_state.dart`.

- [ ] **Step 5: Implement the providers**

```dart
// lib/features/collections/presentation/providers/collection_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/crypto/crypto_providers.dart';
import '../../data/models/collection_model.dart';
import '../../data/providers/collection_remote_provider.dart';
import '../../data/repositories/collection_repository.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final remote = ref.read(collectionRemoteSourceProvider);

  // Watched, not read: setting up encryption has to rebuild the repository.
  return CollectionRepository(remote, cipher: ref.watch(fieldCipherProvider));
});

final collectionsProvider = FutureProvider<List<CollectionModel>>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(collectionRepositoryProvider).getAll();
});

final collectionsByIdProvider = FutureProvider<Map<int, CollectionModel>>((
  ref,
) async {
  final collections = await ref.watch(collectionsProvider.future);
  return {for (final collection in collections) collection.id: collection};
});
```

- [ ] **Step 6: Add collections to the backfill**

In `lib/core/sync/sync_backfill.dart`, import `../../features/collections/data/models/collection_model.dart`. Then add a `collections` query with `isar.collectionModels.filter().remoteIdIsNull().findAll()` and a matching `staleCollections` list. Add it to the early-return condition, add the `pendingCreate` loop, and add `await isar.collectionModels.putAll(staleCollections);` inside `writeTxn`. Use exactly the same shape as the three existing collections.

- [ ] **Step 7: Wire sync providers**

In `lib/core/sync/sync_providers.dart`, import `../../features/collections/presentation/providers/collection_provider.dart`, then:

- In both `pendingSyncCountProvider` and `syncFailuresProvider`, add `ref.watch(collectionsProvider);`.
- In `pendingSyncCountProvider`, add `ref.read(collectionRepositoryProvider).pendingCount(),` to the `Future.wait` list.
- In `syncFailuresProvider`, add:

```dart
  final collections = await ref
      .read(collectionRepositoryProvider)
      .blockedRecords();
```

  and add this to the returned list:

```dart
    for (final record in collections)
      SyncFailure(
        collection: 'Collection',
        label: record.name,
        error: record.lastSyncError,
      ),
```

- In `syncNow`, add `ref.read(collectionRepositoryProvider).invalidateSyncWindow();`. Then, **before** `await refreshTransactions(ref);`, add:

```dart
  // Collections first: their first push re-queues transactions that need the
  // new uuid, and the transaction sync below sends them.
  ref.invalidate(collectionsProvider);
  await ref.read(collectionsProvider.future);
```

- In `retryFailedSync`, add `await ref.read(collectionRepositoryProvider).retryBlockedRecords();`.

- [ ] **Step 8: Run the tests**

Run: `flutter test test/collection_repository_offline_test.dart && flutter test`
Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/collections lib/core/sync test/support/fake_remote_sources.dart test/collection_repository_offline_test.dart
git commit -m "feat: offline-first collection repository and sync wiring"
```

---

### Task 3: Transactions carry their collection through sync

**Files:**
- Modify: `lib/features/transactions/data/models/transaction_mapper.dart`
- Modify: `lib/features/transactions/data/repositories/transaction_repository.dart:464-641`
- Test: `test/transaction_collection_reference_test.dart`

**Interfaces:**
- Consumes: `TransactionModel.collectionId`, `isar.collectionModels` (Task 1).
- Produces: `const transactionCollectionRemoteIdColumn = 'collection_remote_id'`; `TransactionMapper.toJson(..., String? collectionRemoteId)`; `TransactionMapper.fromJson(..., int? collectionId)`.

- [ ] **Step 1: Write the failing tests**

This uses the same setup as `test/transaction_category_reference_test.dart`.

```dart
// test/transaction_collection_reference_test.dart
import 'package:eco/core/database/isar_service.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:eco/features/transactions/data/models/transaction_mapper.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

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

    final back = TransactionMapper.fromJson(
      {...json, 'id': 'tx-1'},
      collectionId: 5,
    );
    expect(back.collectionId, 5);
  });

  test('a synced collection travels as its uuid and resolves on pull', () async {
    final collection = await putCollection(remoteId: 'c-uuid');
    await repository.add(buildTx(collectionId: collection.id));

    expect(remote.rows.values.single[transactionCollectionRemoteIdColumn], 'c-uuid');

    repository.invalidateSyncWindow();
    final pulled = (await repository.getAll()).single;
    expect(pulled.collectionId, collection.id);
  });

  test('pull keeps the link to a collection the server has not seen yet', () async {
    final collection = await putCollection(); // pendingCreate, no uuid
    await repository.add(buildTx(collectionId: collection.id));

    expect(remote.rows.values.single[transactionCollectionRemoteIdColumn], isNull);

    repository.invalidateSyncWindow();
    final pulled = (await repository.getAll()).single;
    expect(pulled.collectionId, collection.id);
  });

  test('a uuid pointing at a locally deleted collection resolves to none', () async {
    final collection = await putCollection(remoteId: 'c-uuid');
    await repository.add(buildTx(collectionId: collection.id));

    collection.syncState = SyncState.pendingDelete;
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.collectionModels.put(collection);
    });

    repository.invalidateSyncWindow();
    expect((await repository.getAll()).single.collectionId, isNull);
  });
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/transaction_collection_reference_test.dart`
Expected: compile errors, `transactionCollectionRemoteIdColumn` and `collectionRemoteId` are undefined.

- [ ] **Step 3: Update the mapper**

In `transaction_mapper.dart`, add below `transactionCategoryRemoteIdColumn`:

```dart
/// Column holding the collection's server-side uuid. Null when unassigned, or
/// when the collection had not reached the server at push time.
const transactionCollectionRemoteIdColumn = 'collection_remote_id';
```

In `toJson`, add the named parameter `String? collectionRemoteId,` and the entry `transactionCollectionRemoteIdColumn: collectionRemoteId,` after the category column.

In `fromJson`, add the named parameter `int? collectionId,` and the line `transaction.collectionId = collectionId;` after the `categoryId` line.

- [ ] **Step 4: Update the repository**

In `transaction_repository.dart`, import `../../../collections/data/models/collection_model.dart`. Then:

1. Add helpers next to `_localCategoryIdsByRemoteId`:

```dart
  /// Only collections still visible locally. A uuid pointing at one deleted
  /// here resolves to nothing, so the transaction shows as unassigned.
  Future<Map<String, int>> _localCollectionIdsByRemoteId() async {
    final collections = await _isar.collectionModels.where().findAll();

    return {
      for (final collection in collections)
        if (collection.remoteId != null && collection.syncState.isVisible)
          collection.remoteId!: collection.id,
    };
  }

  /// Collections the server has not received yet. It cannot name them, so a
  /// null it sends for their members is not an un-assignment.
  Future<Set<int>> _unsyncedCollectionIds() async {
    final collections = await _isar.collectionModels
        .filter()
        .remoteIdIsNull()
        .findAll();

    return {
      for (final collection in collections)
        if (collection.syncState.isVisible) collection.id,
    };
  }
```

2. In `_pullRemoteTransactions`, load `final collectionIdsByRemoteId = await _localCollectionIdsByRemoteId();`, pass `collectionId: collectionIdsByRemoteId[json[transactionCollectionRemoteIdColumn]],` into `TransactionMapper.fromJson`, and pass `unsyncedCollectionIds: await _unsyncedCollectionIds(),` into `_mergeRemoteTransactions`.

3. Give `_mergeRemoteTransactions` the named parameter `Set<int> unsyncedCollectionIds = const {}`. Right after `incoming.isRecurringInstance ??= existing.isRecurringInstance;`, add:

```dart
      if (incoming.collectionId == null &&
          unsyncedCollectionIds.contains(existing.collectionId)) {
        incoming.collectionId = existing.collectionId;
      }
```

4. In `_toRemoteJson`, look up `final collection = tx.collectionId == null ? null : await _isar.collectionModels.get(tx.collectionId!);` and pass `collectionRemoteId: collection?.remoteId,`.

5. In `_fromRemoteJson`, pass `collectionId: fallback.collectionId,`.

6. In `fetchRemoteTransactions`, load the collection map and pass `collectionId: collectionIdsByRemoteId[json[transactionCollectionRemoteIdColumn]],`.

> `SyncState.isVisible` is already used at `transaction_repository.dart:503`. Confirm that it excludes `pendingDelete`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/transaction_collection_reference_test.dart && flutter test`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/transactions/data test/transaction_collection_reference_test.dart
git commit -m "feat: sync a transaction's collection by uuid"
```

---

### Task 4: Supabase migration

**Files:**
- Create: `supabase/migrations/20261024000000_create_collections.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Not yet applied. Paste into the Supabase dashboard SQL editor, then note the
-- date here. See README.md in this folder.
--
-- Collections group transactions (a trip, a renovation). A transaction belongs
-- to at most one. `name` holds ciphertext once the user has set up a key; see
-- `lib/features/collections/data/models/collection_mapper.dart`.
--
-- Deleting a collection must never delete transactions, so the reference is
-- `on delete set null`.
--
-- Idempotent.

create extension if not exists pgcrypto;

create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  -- ARGB packed into an int by the app; wider than int4 on purpose.
  color bigint not null,
  icon text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists collections_user_id_idx
  on public.collections (user_id);

alter table public.collections enable row level security;

drop policy if exists "Users can read own collections" on public.collections;
create policy "Users can read own collections"
  on public.collections for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own collections" on public.collections;
create policy "Users can insert own collections"
  on public.collections for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own collections" on public.collections;
create policy "Users can update own collections"
  on public.collections for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own collections" on public.collections;
create policy "Users can delete own collections"
  on public.collections for delete to authenticated
  using (auth.uid() = user_id);

alter table public.transactions
  add column if not exists collection_remote_id uuid
    references public.collections (id) on delete set null;

create index if not exists transactions_user_id_collection_remote_id_idx
  on public.transactions (user_id, collection_remote_id);
```

- [ ] **Step 2: Apply it**

Ask the user to paste the file into the Supabase dashboard SQL editor and run it, and then to update the header comment with the date it was applied. **It must be applied before a build containing Task 3 ships.** Otherwise every transaction push fails on the unknown column.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20261024000000_create_collections.sql
git commit -m "feat: collections table and transactions.collection_remote_id"
```

---

### Task 5: Backup and restore include collections

**Files:**
- Modify: `lib/core/backup/backup_codec.dart`
- Modify: `lib/core/backup/backup_service.dart:37-44, 97-128`
- Modify: `test/backup_round_trip_test.dart`

**Interfaces:**
- Consumes: `CollectionModel`, `TransactionModel.collectionId`.
- Produces: `BackupPayload.collections` (`List<CollectionModel>`, constructor default `const []`).

- [ ] **Step 1: Write the failing tests**

In `test/backup_round_trip_test.dart`, add the imports `dart:convert` and `package:eco/features/collections/data/models/collection_model.dart`, plus:

```dart
CollectionModel buildCollection() => CollectionModel()
  ..remoteId = 'collection-1'
  ..name = 'Lisbon trip'
  ..color = 0xFF3B82F6;
```

Add these to the `BackupCodec` group:

```dart
    test('round-trips collections and the transaction link', () {
      final codec = BackupCodec(cipherOf(1));
      final payload = BackupPayload(
        createdAt: DateTime.utc(2026, 10, 24),
        transactions: [buildTransaction()..collectionId = 3],
        categories: const [],
        collections: [buildCollection()..id = 3],
        recurring: const [],
        presets: const [],
      );

      final restored = codec.decode(codec.encode(payload));

      expect(restored.collections.single.name, 'Lisbon trip');
      expect(restored.collections.single.id, 3);
      expect(restored.transactions.single.collectionId, 3);
      expect(restored.recordCount, 2);
    });

    test('reads a backup written before collections existed', () {
      final cipher = cipherOf(1);
      final legacy = {
        'format_version': 1,
        'created_at': DateTime.utc(2026, 9, 17).toIso8601String(),
        'transactions': [
          {
            'id': 1, 'remote_id': null, 'title': 'Rent', 'amount': 10,
            'date': '2026-09-01T00:00:00.000Z', 'type': 'expense',
            'status': 'paid', 'category_id': 7, 'payment_method': null,
            'payee': null, 'note': null,
            'created_at': '2026-09-01T00:00:00.000Z', 'updated_at': null,
            'recurring_id': null, 'recurring_template_id': null,
            'is_recurring_instance': null, 'sync_state': 'synced',
            'local_updated_at': null,
          },
        ],
        'categories': [],
        'recurring': [],
        'presets': [],
      };
      final bytes = utf8.encode(cipher.encrypt(jsonEncode(legacy)));

      final restored = BackupCodec(cipher).decode(bytes);

      expect(restored.collections, isEmpty);
      expect(restored.transactions.single.collectionId, isNull);
    });
```

In the `BackupService` group's restore test, add `collections: [buildCollection()],` to the payload. Then assert:

```dart
      final collections = await IsarService.isar.collectionModels
          .where()
          .findAll();
      expect(collections.single.remoteId, isNull);
      expect(collections.single.syncState, SyncState.pendingCreate);
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/backup_round_trip_test.dart`
Expected: compile error, no `collections` parameter on `BackupPayload`.

- [ ] **Step 3: Update the codec**

In `backup_codec.dart`:

- Import `../../features/collections/data/models/collection_model.dart`.
- Keep `formatVersion = 1`. Collections are additive and optional, so older builds simply ignore the key.
- In `encode`, add `'collections': payload.collections.map(_collectionToJson).toList(),`.
- In `decode`, add:

```dart
      // Absent from backups written before collections existed.
      collections: [
        for (final item in json['collections'] as List<dynamic>? ?? const [])
          _collectionFromJson(item as Map<String, dynamic>),
      ],
```

- In `_transactionToJson`, add `'collection_id': item.collectionId,`. In `_transactionFromJson`, add `..collectionId = (json['collection_id'] as num?)?.toInt()`.
- Add:

```dart
  Map<String, dynamic> _collectionToJson(CollectionModel item) => {
    'id': item.id,
    'remote_id': item.remoteId,
    'name': item.name,
    'color': item.color,
    'icon': item.icon,
    'sync_state': item.syncState.name,
    'local_updated_at': item.localUpdatedAt?.toIso8601String(),
  };

  CollectionModel _collectionFromJson(Map<String, dynamic> json) {
    return CollectionModel()
      ..id = json['id'] as int
      ..remoteId = json['remote_id'] as String?
      ..name = json['name'] as String
      ..color = (json['color'] as num).toInt()
      ..icon = json['icon'] as String?
      ..syncState = _enumByName(SyncState.values, json['sync_state'])
      ..localUpdatedAt = _dateOrNull(json['local_updated_at']);
  }
```

- In `BackupPayload`, add `this.collections = const [],` to the constructor, the field `final List<CollectionModel> collections;`, and `collections.length +` to `recordCount`.

- [ ] **Step 4: Update the service**

In `backup_service.dart`:

- Import the collection model.
- In `create`, add `collections: await _isar.collectionModels.where().findAll(),`.
- In `restore`, add the same reset loop for `payload.collections` that the categories get (`remoteId = null`, `pendingCreate`, `syncAttempts = 0`, `lastSyncError = null`).
- In the `writeTxn`, add `await _isar.collectionModels.clear();` and `await _isar.collectionModels.putAll(payload.collections);`.

Local ids are preserved, so `transaction.collectionId` still points at the right restored collection.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/backup_round_trip_test.dart && flutter test`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/backup test/backup_round_trip_test.dart
git commit -m "feat: back up and restore collections"
```

---

### Task 6: Filter by collection and per-collection totals

**Files:**
- Modify: `lib/features/transactions/presentation/providers/transaction_filter.dart`
- Modify: `lib/features/transactions/presentation/providers/transaction_filter_provider.dart`
- Modify: `lib/features/transactions/presentation/providers/transaction_provider.dart:62-64`
- Create: `lib/features/collections/domain/collection_totals.dart`
- Test: `test/collection_totals_test.dart`

**Interfaces:**
- Produces: `TransactionFilter.collectionId` (`int?`, cleared by `copyWith(collectionId: null)`); `TransactionFilterNotifier.setCollection(int?)`; `class CollectionTotals { final double income; final double expense; double get net; }`; `Map<int, CollectionTotals> totalsByCollection(Iterable<TransactionModel>)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/collection_totals_test.dart
import 'package:eco/features/collections/domain/collection_totals.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/presentation/providers/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel tx(double amount, TransactionType type, int? collectionId) =>
    TransactionModel()
      ..title = 't'
      ..amount = amount
      ..type = type
      ..date = DateTime.utc(2026, 10, 1)
      ..categoryId = 1
      ..collectionId = collectionId
      ..createdAt = DateTime.utc(2026, 10, 1);

void main() {
  test('sums income and expense per collection, cent-rounded', () {
    final totals = totalsByCollection([
      tx(0.1, TransactionType.expense, 1),
      tx(0.2, TransactionType.expense, 1),
      tx(100, TransactionType.income, 1),
      tx(50, TransactionType.expense, 2),
      tx(999, TransactionType.expense, null),
    ]);

    expect(totals.keys, unorderedEquals([1, 2]));
    expect(totals[1]!.expense, 0.3);
    expect(totals[1]!.income, 100);
    expect(totals[1]!.net, 99.7);
    expect(totals[2]!.net, -50);
  });

  test('filter collectionId can be set and cleared', () {
    const base = TransactionFilter();
    final set = base.copyWith(collectionId: 4);
    expect(set.collectionId, 4);
    expect(set.copyWith(collectionId: null).collectionId, isNull);
    expect(set.copyWith(search: 'x').collectionId, 4);
  });
}
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `flutter test test/collection_totals_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement the totals**

```dart
// lib/features/collections/domain/collection_totals.dart
import '../../../core/utils/money.dart';
import '../../transactions/data/models/transaction_model.dart';

class CollectionTotals {
  final double income;
  final double expense;

  const CollectionTotals({required this.income, required this.expense});

  double get net => roundCents(income - expense);
}

/// Income and expense per collection. Unassigned transactions are left out;
/// collections with no transactions have no entry.
Map<int, CollectionTotals> totalsByCollection(
  Iterable<TransactionModel> transactions,
) {
  final income = <int, double>{};
  final expense = <int, double>{};

  for (final tx in transactions) {
    final id = tx.collectionId;
    if (id == null) continue;
    final bucket = tx.type == TransactionType.income ? income : expense;
    bucket[id] = (bucket[id] ?? 0) + tx.amount;
  }

  return {
    for (final id in {...income.keys, ...expense.keys})
      id: CollectionTotals(
        income: roundCents(income[id] ?? 0),
        expense: roundCents(expense[id] ?? 0),
      ),
  };
}
```

- [ ] **Step 4: Add the filter field**

In `transaction_filter.dart`, add `final int? collectionId;` after `categoryId` and `this.collectionId,` to the constructor. In `copyWith`, add `Object? collectionId = const Object(),` and:

```dart
      collectionId: collectionId == const Object()
          ? this.collectionId
          : collectionId as int?,
```

Check the rest of the file, since it's 94 lines. If there is an `isActive` / `hasAdvanced` getter or an `==`/`hashCode`, include `collectionId` there too.

In `transaction_filter_provider.dart`, add:

```dart
  void setCollection(int? id) {
    state = state.copyWith(collectionId: id);
  }
```

and add `collectionId: null,` to `clearAdvanced`.

In `transaction_provider.dart`, add this after the category check:

```dart
          if (filter.collectionId != null &&
              tx.collectionId != filter.collectionId) {
            return false;
          }
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/collection_totals_test.dart && flutter test`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/collections/domain lib/features/transactions/presentation/providers test/collection_totals_test.dart
git commit -m "feat: filter transactions by collection and total each collection"
```

---

### Task 7: Collections UI

**Files:**
- Create: `lib/features/collections/presentation/pages/collections_page.dart`
- Create: `lib/features/collections/presentation/pages/collection_detail_page.dart`
- Modify: `lib/shared/widgets/app_shell.dart:24-29, 101-121` (new tab)
- Modify: `lib/features/transactions/presentation/pages/add_transaction_page.dart` (state `_collectionId`, init at line 76, save at line 145, picker after the Category dropdown at line 585)
- Modify: `lib/features/transactions/presentation/pages/transactions_page.dart:289-411, 640-676` (filter sheet)
- Test: `test/collections_page_test.dart`

**Interfaces:**
- Consumes: `collectionsProvider`, `collectionsByIdProvider`, `collectionRepositoryProvider` (Task 2); `totalsByCollection`, `CollectionTotals` (Task 6); `visibleTransactionsProvider`, `transactionsProvider`, `transactionVisibilityProvider`, `formatMoney`, `TransactionListGrouped(transactions: ...)`.
- Produces: `CollectionsPage()`, `CollectionDetailPage(collectionId: int)`.

- [ ] **Step 1: Write the failing widget test**

Read `test/analytics_masked_test.dart` first. Override providers the same way it does (it already sets up masked visibility and transactions), and copy its override pattern.

```dart
// test/collections_page_test.dart
import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:eco/features/collections/presentation/pages/collections_page.dart';
import 'package:eco/features/collections/presentation/providers/collection_provider.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final trip = CollectionModel()
    ..id = 1
    ..name = 'Lisbon trip'
    ..color = 0xFF3B82F6;
  final hotel = TransactionModel()
    ..id = 10
    ..title = 'Hotel'
    ..amount = 120
    ..type = TransactionType.expense
    ..date = DateTime.utc(2026, 10, 1)
    ..categoryId = 1
    ..collectionId = 1
    ..createdAt = DateTime.utc(2026, 10, 1);

  Widget app({List<Override> extra = const []}) => ProviderScope(
    overrides: [
      collectionsProvider.overrideWith((ref) async => [trip]),
      transactionsProvider.overrideWith((ref) async => [hotel]),
      ...extra,
    ],
    child: const MaterialApp(home: CollectionsPage()),
  );

  testWidgets('lists collections with their net total', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Lisbon trip'), findsOneWidget);
    expect(find.textContaining('120'), findsWidgets);
  });

  testWidgets('masked mode hides the totals', (tester) async {
    await tester.pumpWidget(
      app(
        extra: [
          transactionVisibilityProvider.overrideWith(
            (ref) => TransactionVisibilityNotifier(
              const TransactionVisibilityState(
                mode: TransactionVisibilityMode.masked,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lisbon trip'), findsOneWidget);
    expect(find.textContaining('120'), findsNothing);
    expect(find.textContaining('•••'), findsWidgets);
  });
}
```

Add the import `package:eco/core/privacy/transaction_visibility.dart` to this test.

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/collections_page_test.dart`
Expected: compile error, `collections_page.dart` not found.

- [ ] **Step 3: Implement the Collections page**

```dart
// lib/features/collections/presentation/pages/collections_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/utils/money.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/models/collection_model.dart';
import '../../domain/collection_totals.dart';
import '../providers/collection_provider.dart';
import 'collection_detail_page.dart';

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsProvider);
    final transactions =
        ref.watch(visibleTransactionsProvider).valueOrNull ?? const [];
    final visibility = ref.watch(transactionVisibilityProvider);
    final totals = totalsByCollection(transactions);

    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'add-collection',
        onPressed: () => showCollectionEditor(context, ref),
        child: const Icon(Icons.create_new_folder_outlined),
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Group transactions for a trip, a renovation or anything '
                  'else. They still count in your overall totals.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: collections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final collection = collections[index];
              final total =
                  totals[collection.id] ??
                  const CollectionTotals(income: 0, expense: 0);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(collection.color),
                    child: const Icon(Icons.folder_outlined, color: Colors.white),
                  ),
                  title: Text(collection.name),
                  subtitle: Text(
                    'In ${visibility.displayAmount(formatMoney(total.income))}'
                    '  ·  Out ${visibility.displayAmount(formatMoney(total.expense))}',
                  ),
                  trailing: Text(
                    visibility.displayAmount(formatMoney(total.net)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CollectionDetailPage(collectionId: collection.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

const List<int> collectionPalette = [
  0xFFEF4444,
  0xFFF97316,
  0xFFF59E0B,
  0xFF10B981,
  0xFF06B6D4,
  0xFF3B82F6,
  0xFF8B5CF6,
  0xFFEC4899,
];

Future<void> showCollectionEditor(
  BuildContext context,
  WidgetRef ref, {
  CollectionModel? collection,
}) async {
  final controller = TextEditingController(text: collection?.name ?? '');
  var selectedColor = collection?.color ?? collectionPalette.first;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              collection == null ? 'New Collection' : 'Edit Collection',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Lisbon trip, Kitchen renovation...',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in collectionPalette)
                  Semantics(
                    label: 'Colour',
                    selected: color == selectedColor,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setModalState(() => selectedColor = color),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(color),
                          borderRadius: BorderRadius.circular(16),
                          border: color == selectedColor
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  width: 2.2,
                                )
                              : null,
                        ),
                        child: color == selectedColor
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(collection == null ? 'Create' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  final name = controller.text.trim();
  if (saved != true || name.isEmpty) return;

  final repo = ref.read(collectionRepositoryProvider);
  final target = collection ?? CollectionModel();
  target
    ..name = name
    ..color = selectedColor;

  if (collection == null) {
    await repo.add(target);
  } else {
    await repo.update(target);
  }

  ref.invalidate(collectionsProvider);
}
```

- [ ] **Step 4: Implement the detail page**

```dart
// lib/features/collections/presentation/pages/collection_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/transaction_list_grouped.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../domain/collection_totals.dart';
import '../providers/collection_provider.dart';
import 'collections_page.dart';

class CollectionDetailPage extends ConsumerWidget {
  final int collectionId;

  const CollectionDetailPage({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref
        .watch(collectionsByIdProvider)
        .valueOrNull?[collectionId];
    final visibility = ref.watch(transactionVisibilityProvider);
    final members = (ref.watch(visibleTransactionsProvider).valueOrNull ?? const [])
        .where((tx) => tx.collectionId == collectionId)
        .toList();
    final total =
        totalsByCollection(members)[collectionId] ??
        const CollectionTotals(income: 0, expense: 0);

    // Deleted here or on another device while open.
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This collection no longer exists.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                showCollectionEditor(context, ref, collection: collection),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat('In', visibility.displayAmount(formatMoney(total.income))),
                _Stat('Out', visibility.displayAmount(formatMoney(total.expense))),
                _Stat('Net', visibility.displayAmount(formatMoney(total.net))),
              ],
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? const Center(
                    child: Text('Pick this collection when adding a transaction.'),
                  )
                : TransactionListGrouped(transactions: members),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete collection?'),
        content: const Text(
          'Its transactions are kept. They just leave the collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(collectionRepositoryProvider).delete(collectionId);
    ref.invalidate(collectionsProvider);
    ref.invalidate(transactionsProvider);
    if (context.mounted) Navigator.pop(context);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
```

- [ ] **Step 5: Add the tab**

In `app_shell.dart`, import `../../features/collections/presentation/pages/collections_page.dart`. Add `CollectionsPage(),` to `pages` after `TransactionsPage(),`, and add this after the Transactions destination:

```dart
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                label: 'Collections',
              ),
```

- [ ] **Step 6: Add the form picker**

In `add_transaction_page.dart`:

- Import `../../../collections/presentation/providers/collection_provider.dart`.
- Add the state `int? _collectionId;` next to `_categoryId`.
- In `initState`, set `_collectionId = transaction.collectionId;` after the `_categoryId` line. Duplicates keep the collection too.
- In `_save`, add `..collectionId = _collectionId` after `..categoryId = _categoryId!`.
- In `build`, add `final collections = ref.watch(collectionsProvider).valueOrNull ?? const [];`. After the Category `DropdownButtonFormField` (line 585), insert:

```dart
                                        if (collections.isNotEmpty) ...[
                                          const SizedBox(height: 14),
                                          DropdownButtonFormField<int?>(
                                            // A collection deleted elsewhere
                                            // falls back to none.
                                            initialValue: collections.any(
                                                  (c) => c.id == _collectionId,
                                                )
                                                ? _collectionId
                                                : null,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Collection',
                                            ),
                                            items: [
                                              const DropdownMenuItem(
                                                value: null,
                                                child: Text('None'),
                                              ),
                                              for (final c in collections)
                                                DropdownMenuItem(
                                                  value: c.id,
                                                  child: Text(c.name),
                                                ),
                                            ],
                                            onChanged: (v) => setState(
                                              () => _collectionId = v,
                                            ),
                                          ),
                                        ],
```

- [ ] **Step 7: Add the filter sheet dropdown**

In `transactions_page.dart` `_TransactionFilterSheetState`:

- Add `late int? _collectionId;` and set `_collectionId = filter.collectionId;` in `initState`.
- In `build`, add `final collections = ref.watch(collectionsProvider).valueOrNull ?? const [];`. After the Category dropdown (line 411), add:

```dart
                    if (collections.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: _collectionId,
                        decoration: const InputDecoration(
                          labelText: 'Collection',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All collections'),
                          ),
                          for (final c in collections)
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (value) =>
                            setState(() => _collectionId = value),
                      ),
                    ],
```

- In `_clearAll`, add `_collectionId = null;`. In `_applyFilters`, add `collectionId: _collectionId,` to the `copyWith`.
- Import `../../../collections/presentation/providers/collection_provider.dart`.

- [ ] **Step 8: Run the tests and analyze**

Run: `flutter test test/collections_page_test.dart && flutter analyze lib test && flutter test`
Expected: all PASS, and the analyzer reports no issues.

- [ ] **Step 9: Manual check**

Run the app (`flutter run`). Create a collection, add two transactions to it, and check that the tab shows the totals. Check that the dashboard totals include them. Delete the collection and check that the transactions are still in the Transactions tab. Long-press Settings to switch to masked mode, and check that the collection totals show `•••`.

- [ ] **Step 10: Commit**

```bash
git add lib/features/collections/presentation lib/shared/widgets/app_shell.dart lib/features/transactions/presentation/pages test/collections_page_test.dart
git commit -m "feat: collections tab, detail page, form picker and filter"
```
