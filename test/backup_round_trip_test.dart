import 'package:cryptography/cryptography.dart';
import 'package:eco/core/backup/backup_codec.dart';
import 'package:eco/core/backup/backup_service.dart';
import 'package:eco/core/crypto/field_cipher.dart';
import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/settings/data/models/transaction_preset_model.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'support/test_isar.dart';

FieldCipher cipherOf(int seed) =>
    FieldCipher(SecretKeyData(List<int>.generate(32, (i) => (i + seed) & 0xFF)));

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
      expect(restored.recurring.single.intervalType,
          RecurringIntervalType.monthly);
      expect(restored.recurring.single.endDate, DateTime.utc(2027, 4, 1));
      expect(restored.presets.single.value, 'Amazon');
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
        await IsarService.isar.transactionModels
            .put(buildTransaction(title: 'Stale', remoteId: 'old'));
      });

      final payload = await service.read(
        BackupCodec(cipherOf(1)).encode(
          BackupPayload(
            createdAt: DateTime.utc(2026, 9, 17),
            transactions: [buildTransaction(title: 'Rent')],
            categories: [buildCategory()],
            recurring: [buildRecurring()],
            presets: const [],
          ),
        ),
      );

      await service.restore(payload);

      final transactions =
          await IsarService.isar.transactionModels.where().findAll();
      final categories =
          await IsarService.isar.categoryModels.where().findAll();

      expect(transactions.map((t) => t.title), ['Rent']);
      expect(transactions.single.remoteId, isNull);
      expect(transactions.single.syncState, SyncState.pendingCreate);
      expect(transactions.single.syncAttempts, 0);
      expect(transactions.single.lastSyncError, isNull);
      expect(categories.single.syncState, SyncState.pendingCreate);
      expect(categories.single.remoteId, isNull);
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
