import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/recurring/domain/services/recurring_recovery_service.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_isar.dart';

TransactionModel tx({String? recurringId, int? templateId}) =>
    TransactionModel()
      ..title = 'Rent'
      ..amount = 800
      ..type = TransactionType.expense
      ..date = DateTime.utc(2026, 9, 1)
      ..categoryId = 1
      ..createdAt = DateTime.utc(2026, 9, 1)
      ..recurringId = recurringId
      ..recurringTemplateId = templateId
      ..syncState = SyncState.synced;

void main() {
  setUp(() async => TestIsar.open());
  tearDown(() async => TestIsar.close());

  test(
    'relink points both link fields at the template and queues a sync',
    () async {
      final isar = IsarService.isar;
      final kept = RecurringTransactionModel()
        ..title = 'Rent'
        ..type = TransactionType.expense
        ..amountType = RecurringAmountType.fixed
        ..categoryId = 1
        ..intervalType = RecurringIntervalType.monthly
        ..intervalCount = 1
        ..nextDueDate = DateTime.utc(2026, 10, 1)
        ..isActive = true
        ..createdAt = DateTime.utc(2026, 9, 1)
        ..remoteId = 'new-uuid'
        ..syncState = SyncState.synced;
      final unlinked = tx();
      final other = tx(recurringId: 'old-uuid', templateId: 7);
      await isar.writeTxn(() async {
        await isar.recurringTransactionModels.put(kept);
        await isar.transactionModels.putAll([unlinked, other]);
      });

      final ids = [unlinked.id, other.id];
      expect(await const RecurringRecoveryService().relink(ids, kept), 2);

      for (final t in await isar.transactionModels.getAll(ids)) {
        expect(t!.recurringId, 'new-uuid');
        expect(t.recurringTemplateId, kept.id);
        expect(t.isRecurringInstance, isTrue);
        expect(t.syncState, SyncState.pendingUpdate);
      }
    },
  );
}
