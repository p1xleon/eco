import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:eco/core/backup/backup_codec.dart';
import 'package:eco/core/backup/backup_service.dart';
import 'package:eco/core/crypto/field_cipher.dart';
import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/settings/data/models/transaction_preset_model.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'support/test_isar.dart';

FieldCipher cipherOf(int seed) => FieldCipher(
  SecretKeyData(List<int>.generate(32, (i) => (i + seed) & 0xFF)),
);

TransactionModel buildTransaction({
  String title = 'Water bill',
  String? remoteId = 'remote-1',
  SyncState syncState = SyncState.synced,
}) {
  return TransactionModel()
    ..remoteId = remoteId
    ..title = title
    ..amount = 42.5
    ..date = DateTime.utc(2026, 3, 12)
    ..type = TransactionType.expense
    ..status = TransactionStatus.pending
    ..categoryId = 7
    ..payee = 'Local Store'
    ..paymentMethod = 'Google Pay'
    ..note = 'note'
    ..createdAt = DateTime.utc(2026, 3, 11)
    ..updatedAt = DateTime.utc(2026, 3, 13)
    ..syncState = syncState
    ..syncAttempts = 3
    ..lastSyncError = 'boom';
}

CategoryModel buildCategory() {
  return CategoryModel()
    ..remoteId = 'category-1'
    ..name = 'Groceries'
    ..type = CategoryType.expense
    ..color = 4283215696
    ..icon = 'cart';
}

CollectionModel buildCollection() => CollectionModel()
  ..remoteId = 'collection-1'
  ..name = 'Lisbon trip'
  ..color = 0xFF3B82F6;

RecurringTransactionModel buildRecurring() {
  return RecurringTransactionModel()
    ..remoteId = 'recurring-1'
    ..title = 'Rent'
    ..type = TransactionType.expense
    ..defaultAmount = 1200
    ..amountType = RecurringAmountType.fixed
    ..categoryId = 7
    ..accountId = 'account-1'
    ..intervalType = RecurringIntervalType.monthly
    ..intervalCount = 1
    ..nextDueDate = DateTime.utc(2026, 4, 1)
    ..endDate = DateTime.utc(2027, 4, 1)
    ..isActive = true
    ..createdAt = DateTime.utc(2026, 1, 1);
}

void main() {
  setUp(TestIsar.open);
  tearDown(TestIsar.close);

  group('BackupCodec', () {
    test('round-trips every collection', () {
      final codec = BackupCodec(cipherOf(1));

      final payload = BackupPayload(
        createdAt: DateTime.utc(2026, 9, 17),
        transactions: [buildTransaction()],
        categories: [buildCategory()],
        recurring: [buildRecurring()],
        presets: [
          TransactionPresetModel()
            ..type = TransactionPresetType.payee
            ..value = 'Amazon',
        ],
      );

      final restored = codec.decode(codec.encode(payload));

      expect(restored.createdAt, payload.createdAt);
      expect(restored.recordCount, 4);

      final transaction = restored.transactions.single;
      expect(transaction.title, 'Water bill');
      expect(transaction.amount, 42.5);
      expect(transaction.status, TransactionStatus.pending);
      expect(transaction.type, TransactionType.expense);
      expect(transaction.remoteId, 'remote-1');
      expect(transaction.date, DateTime.utc(2026, 3, 12));

      expect(restored.categories.single.name, 'Groceries');
      expect(
        restored.recurring.single.intervalType,
        RecurringIntervalType.monthly,
      );
      expect(restored.recurring.single.endDate, DateTime.utc(2027, 4, 1));
      expect(restored.presets.single.value, 'Amazon');
    });

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
            'id': 1,
            'remote_id': null,
            'title': 'Rent',
            'amount': 10,
            'date': '2026-09-01T00:00:00.000Z',
            'type': 'expense',
            'status': 'paid',
            'category_id': 7,
            'payment_method': null,
            'payee': null,
            'note': null,
            'created_at': '2026-09-01T00:00:00.000Z',
            'updated_at': null,
            'recurring_id': null,
            'recurring_template_id': null,
            'is_recurring_instance': null,
            'sync_state': 'synced',
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

    test('writes a file the server key cannot read', () {
      final codec = BackupCodec(cipherOf(1));
      final bytes = codec.encode(
        BackupPayload(
          createdAt: DateTime.utc(2026, 9, 17),
          transactions: [buildTransaction()],
          categories: const [],
          recurring: const [],
          presets: const [],
        ),
      );

      expect(String.fromCharCodes(bytes), isNot(contains('Water bill')));
      expect(
        () => BackupCodec(cipherOf(2)).decode(bytes),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('BackupService', () {
    late BackupService service;

    setUp(() {
      service = BackupService(
        isar: IsarService.isar,
        codec: BackupCodec(cipherOf(1)),
      );
    });

    test('restore replaces local data and queues it all for upload', () async {
      // Something stale that must not survive the restore.
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.transactionModels.put(
          buildTransaction(title: 'Stale', remoteId: 'old'),
        );
      });

      final payload = await service.read(
        BackupCodec(cipherOf(1)).encode(
          BackupPayload(
            createdAt: DateTime.utc(2026, 9, 17),
            transactions: [buildTransaction(title: 'Rent')],
            categories: [buildCategory()],
            collections: [buildCollection()],
            recurring: [buildRecurring()],
            presets: const [],
          ),
        ),
      );

      await service.restore(payload);

      final transactions = await IsarService.isar.transactionModels
          .where()
          .findAll();
      final categories = await IsarService.isar.categoryModels
          .where()
          .findAll();

      expect(transactions.map((t) => t.title), ['Rent']);
      expect(transactions.single.remoteId, isNull);
      expect(transactions.single.syncState, SyncState.pendingCreate);
      expect(transactions.single.syncAttempts, 0);
      expect(transactions.single.lastSyncError, isNull);
      expect(categories.single.syncState, SyncState.pendingCreate);
      expect(categories.single.remoteId, isNull);

      final collections = await IsarService.isar.collectionModels
          .where()
          .findAll();
      expect(collections.single.remoteId, isNull);
      expect(collections.single.syncState, SyncState.pendingCreate);
    });

    test('create captures what is in the database', () async {
      await IsarService.isar.writeTxn(() async {
        await IsarService.isar.transactionModels.put(buildTransaction());
        await IsarService.isar.categoryModels.put(buildCategory());
      });

      final payload = await service.read(await service.create());

      expect(payload.transactions.single.title, 'Water bill');
      expect(payload.categories.single.name, 'Groceries');
    });
  });
}
