import 'package:cryptography/cryptography.dart';
import 'package:eco/core/crypto/encryption_migration.dart';
import 'package:eco/core/crypto/field_cipher.dart';
import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/models/category_mapper.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_mapper.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/transactions/data/models/transaction_mapper.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'support/test_isar.dart';

FieldCipher cipherOf(int seed) =>
    FieldCipher(SecretKeyData(List<int>.generate(32, (i) => (i + seed) & 0xFF)));

TransactionModel buildTransaction() {
  return TransactionModel()
    ..remoteId = 'remote-1'
    ..title = 'Water bill'
    ..amount = 42.5
    ..date = DateTime.utc(2026, 3, 12)
    ..type = TransactionType.expense
    ..status = TransactionStatus.paid
    ..categoryId = 7
    ..payee = 'Local Store'
    ..paymentMethod = 'Google Pay'
    ..note = 'quarterly'
    ..createdAt = DateTime.utc(2026, 3, 11);
}

void main() {
  group('TransactionMapper', () {
    test('encrypts the sensitive fields and leaves sync fields readable', () {
      final cipher = cipherOf(1);
      final json = buildTransaction().toJson('user-1', cipher: cipher);

      expect(json['title'], startsWith(FieldCipher.versionPrefix));
      expect(json['payee'], startsWith(FieldCipher.versionPrefix));
      expect(json['note'], startsWith(FieldCipher.versionPrefix));
      expect(json['payment_method'], startsWith(FieldCipher.versionPrefix));
      expect(json['amount_enc'], startsWith(FieldCipher.versionPrefix));

      // Null so the numeric column carries nothing readable.
      expect(json['amount'], isNull);

      // The sync engine pages on these, so they must stay plaintext.
      expect(json['date'], '2026-03-12T00:00:00.000Z');
      expect(json['type'], 'expense');
      expect(json['status'], 'paid');
      expect(json['user_id'], 'user-1');
    });

    test('round-trips through the server shape', () {
      final cipher = cipherOf(1);
      final json = buildTransaction().toJson('user-1', cipher: cipher);
      json['id'] = 'remote-1';

      final restored = TransactionMapper.fromJson(json, cipher: cipher);

      expect(restored.title, 'Water bill');
      expect(restored.amount, 42.5);
      expect(restored.payee, 'Local Store');
      expect(restored.paymentMethod, 'Google Pay');
      expect(restored.note, 'quarterly');
    });

    test('still reads a row written before encryption was set up', () {
      final legacy = buildTransaction().toJson('user-1');
      legacy['id'] = 'remote-1';

      expect(legacy['title'], 'Water bill');
      expect(legacy['amount'], 42.5);
      expect(legacy['amount_enc'], isNull);

      // Both with a key and without one: this is the state during migration.
      for (final cipher in [cipherOf(1), null]) {
        final restored = TransactionMapper.fromJson(legacy, cipher: cipher);
        expect(restored.title, 'Water bill');
        expect(restored.amount, 42.5);
      }
    });

    test('writes plaintext when no key is set up, so sync keeps working', () {
      final json = buildTransaction().toJson('user-1');

      expect(json['title'], 'Water bill');
      expect(json['amount'], 42.5);
      expect(json['amount_enc'], isNull);
    });

    test('refuses to store ciphertext it cannot read', () {
      final json = buildTransaction().toJson('user-1', cipher: cipherOf(1));
      json['id'] = 'remote-1';

      expect(
        () => TransactionMapper.fromJson(json, cipher: null),
        throwsStateError,
      );
    });
  });

  group('CategoryMapper', () {
    test('encrypts the name and leaves the rest alone', () {
      final cipher = cipherOf(1);
      final category = CategoryModel()
        ..name = 'Groceries'
        ..type = CategoryType.expense
        ..color = 42
        ..icon = 'cart';

      final json = category.toJson('user-1', cipher: cipher);

      expect(json['name'], startsWith(FieldCipher.versionPrefix));
      expect(json['color'], 42);
      expect(json['icon'], 'cart');
      expect(json['type'], 'expense');

      expect(CategoryMapper.fromJson(json, cipher: cipher).name, 'Groceries');
    });
  });

  group('RecurringTransactionMapper', () {
    test('encrypts title, amount, note and account', () {
      final cipher = cipherOf(1);
      final template = RecurringTransactionModel()
        ..title = 'Rent'
        ..type = TransactionType.expense
        ..defaultAmount = 1200
        ..amountType = RecurringAmountType.fixed
        ..categoryId = 7
        ..accountId = 'account-1'
        ..intervalType = RecurringIntervalType.monthly
        ..intervalCount = 1
        ..nextDueDate = DateTime.utc(2026, 4, 1)
        ..isActive = true
        ..note = 'landlord'
        ..createdAt = DateTime.utc(2026, 1, 1);

      final json = template.toJson('user-1', cipher: cipher);

      expect(json['title'], startsWith(FieldCipher.versionPrefix));
      expect(json['default_amount_enc'], startsWith(FieldCipher.versionPrefix));
      expect(json['default_amount'], isNull);
      expect(json['account_id'], startsWith(FieldCipher.versionPrefix));
      expect(json['note'], startsWith(FieldCipher.versionPrefix));

      // Schedule stays readable.
      expect(json['interval_type'], 'monthly');
      expect(json['next_due_date'], '2026-04-01T00:00:00.000Z');
      expect(json['is_active'], true);

      final restored =
          RecurringTransactionMapper.fromJson(json, categoryId: 7, cipher: cipher);

      expect(restored.title, 'Rent');
      expect(restored.defaultAmount, 1200);
      expect(restored.accountId, 'account-1');
      expect(restored.note, 'landlord');
    });
  });

  group('EncryptionMigration', () {
    setUp(TestIsar.open);
    tearDown(TestIsar.close);

    test('queues synced records and leaves pending creates alone', () async {
      final isar = IsarService.isar;

      await isar.writeTxn(() async {
        await isar.transactionModels.put(buildTransaction());
        await isar.transactionModels.put(
          buildTransaction()
            ..remoteId = null
            ..syncState = SyncState.pendingCreate,
        );
        await isar.categoryModels.put(
          CategoryModel()
            ..remoteId = 'category-1'
            ..name = 'Groceries'
            ..type = CategoryType.expense
            ..color = 42,
        );
      });

      final queued = await EncryptionMigration.queueAll(isar);

      expect(queued, 2);

      final transactions = await isar.transactionModels.where().findAll();
      final synced = transactions.firstWhere((t) => t.remoteId != null);
      final created = transactions.firstWhere((t) => t.remoteId == null);

      expect(synced.syncState, SyncState.pendingUpdate);
      expect(created.syncState, SyncState.pendingCreate);
      expect(
        (await isar.categoryModels.where().findAll()).single.syncState,
        SyncState.pendingUpdate,
      );
    });
  });
}
