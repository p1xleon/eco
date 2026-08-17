import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/features/transactions/data/models/transaction_mapper.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/remote/transaction_remote_source.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

TransactionModel buildTransaction({required int categoryId}) {
  final now = DateTime.utc(2026, 8, 17);

  return TransactionModel()
    ..title = 'Coffee'
    ..amount = 4.5
    ..date = now
    ..type = TransactionType.expense
    ..categoryId = categoryId
    ..createdAt = now;
}

Map<String, dynamic> serverRow({
  required String id,
  required int legacyCategoryId,
  String? categoryRemoteId,
}) {
  return {
    'id': id,
    'user_id': 'user-1',
    'title': 'From another device',
    'amount': 12.0,
    'type': 'expense',
    'category_id': legacyCategoryId,
    // Omitted entirely when null, the way a row written before the column
    // existed comes back.
    transactionCategoryRemoteIdColumn: ?categoryRemoteId,
    'status': 'paid',
    'date': DateTime.utc(2026, 8, 17).toIso8601String(),
    'created_at': DateTime.utc(2026, 8, 17).toIso8601String(),
  };
}

void main() {
  group('category references', () {
    late FakeTransactionRemoteSource remote;
    late FakeCategoryRemoteSource categoryRemote;
    late CategoryRepository categoryRepository;
    late TransactionRepository repository;

    setUp(() async {
      await TestIsar.open();
      setNetwork(online: true);

      remote = FakeTransactionRemoteSource();
      categoryRemote = FakeCategoryRemoteSource();
      categoryRepository = CategoryRepository(categoryRemote);
      repository = TransactionRepository(
        remote,
        categoryRepository: categoryRepository,
      );
    });

    tearDown(() async {
      setNetwork(online: true);
      await TestIsar.close();
    });

    Future<CategoryModel> addCategory(String name) async {
      await categoryRepository.add(
        CategoryModel()
          ..name = name
          ..type = CategoryType.expense
          ..color = 0xFF64B5F6,
      );

      return (await categoryRepository.getAll()).firstWhere(
        (category) => category.name == name,
      );
    }

    test('a pushed transaction carries the category uuid', () async {
      final category = await addCategory('Food');

      await repository.add(buildTransaction(categoryId: category.id));

      final row = remote.rows.values.single;
      expect(row[transactionCategoryRemoteIdColumn], category.remoteId);
      // The legacy column is still written, so an older client keeps working.
      expect(row['category_id'], category.id);
    });

    test('a pulled row follows the uuid, not this device\'s local id', () async {
      final food = await addCategory('Food');
      final travel = await addCategory('Travel');

      // The row was written by a device where the *local* id of Travel was
      // whatever Food happens to be here. Only the uuid is trustworthy.
      remote.rows['remote-x'] = serverRow(
        id: 'remote-x',
        legacyCategoryId: food.id,
        categoryRemoteId: travel.remoteId,
      );

      repository.invalidateSyncWindow();
      final transactions = await repository.getAll();

      expect(transactions.single.categoryId, travel.id);
      expect(transactions.single.categoryId, isNot(food.id));
    });

    test('a row written before the uuid column keeps the legacy reference',
        () async {
      final food = await addCategory('Food');

      remote.rows['remote-legacy'] = serverRow(
        id: 'remote-legacy',
        legacyCategoryId: food.id,
      );

      repository.invalidateSyncWindow();
      final transactions = await repository.getAll();

      expect(transactions.single.categoryId, food.id);
    });

    test('a legacy row is upgraded when the user edits it', () async {
      final food = await addCategory('Food');

      remote.rows['remote-legacy'] = serverRow(
        id: 'remote-legacy',
        legacyCategoryId: food.id,
      );

      repository.invalidateSyncWindow();
      final pulled = (await repository.getAll()).single;

      // A pull on its own leaves the row alone: this device cannot know what
      // another device's integer meant.
      expect(
        remote.rows['remote-legacy']!.containsKey(
          transactionCategoryRemoteIdColumn,
        ),
        isFalse,
      );

      pulled.title = 'Edited by the user';
      await repository.update(pulled);

      expect(
        remote.rows['remote-legacy']![transactionCategoryRemoteIdColumn],
        food.remoteId,
      );
    });

    test('an unresolvable uuid does not lose the row', () async {
      final food = await addCategory('Food');

      remote.rows['remote-orphan'] = serverRow(
        id: 'remote-orphan',
        legacyCategoryId: food.id,
        categoryRemoteId: 'category-from-a-device-we-have-not-synced',
      );

      repository.invalidateSyncWindow();
      final transactions = await repository.getAll();

      expect(transactions, hasLength(1));
      expect(transactions.single.remoteId, 'remote-orphan');
      // Falls back to the legacy reference rather than dropping the record.
      expect(transactions.single.categoryId, food.id);
    });

    test('pulling legacy rows queues nothing for the user', () async {
      final food = await addCategory('Food');

      remote.rows['remote-legacy'] = serverRow(
        id: 'remote-legacy',
        legacyCategoryId: food.id,
      );

      repository.invalidateSyncWindow();
      await repository.getAll();

      expect(await repository.pendingCount(), 0);
      final stored = await IsarService.isar.transactionModels.where().findAll();
      expect(stored.single.syncState.isPending, isFalse);
    });
  });

  group('pre-migration schema fallback', () {
    PostgrestException missingColumn() {
      return PostgrestException(
        message:
            "Could not find the '$transactionCategoryRemoteIdColumn' column of "
            "'transactions' in the schema cache",
        code: 'PGRST204',
      );
    }

    test('retries without the column and remembers the answer', () async {
      final fallback = CategoryRemoteIdFallback();
      final payloads = <Map<String, dynamic>>[];

      Future<Map<String, dynamic>> send(Map<String, dynamic> payload) async {
        payloads.add(payload);
        if (payload.containsKey(transactionCategoryRemoteIdColumn)) {
          throw missingColumn();
        }
        return payload;
      }

      await fallback.send({
        'title': 'Coffee',
        transactionCategoryRemoteIdColumn: 'category-1',
      }, send);

      expect(payloads, hasLength(2));
      expect(payloads.first.containsKey(transactionCategoryRemoteIdColumn),
          isTrue);
      expect(payloads.last.containsKey(transactionCategoryRemoteIdColumn),
          isFalse);
      expect(fallback.serverHasColumn, isFalse);

      // The doomed attempt is not repeated.
      await fallback.send({
        'title': 'Tea',
        transactionCategoryRemoteIdColumn: 'category-1',
      }, send);

      expect(payloads, hasLength(3));
      expect(payloads.last.containsKey(transactionCategoryRemoteIdColumn),
          isFalse);
    });

    test('a real rejection is not mistaken for a missing column', () async {
      final fallback = CategoryRemoteIdFallback();
      final rejection = PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );

      await expectLater(
        fallback.send({'title': 'Coffee'}, (_) async => throw rejection),
        throwsA(same(rejection)),
      );
      expect(fallback.serverHasColumn, isTrue);
    });
  });
}
