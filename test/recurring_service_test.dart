import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/recurring/data/repositories/recurring_transaction_repository.dart';
import 'package:eco/features/recurring/domain/services/recurring_transaction_service.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

void main() {
  late RecurringTransactionService service;
  late TransactionRepository transactions;
  late int categoryId;

  setUp(() async {
    await TestIsar.open();
    setNetwork(online: false); // local behaviour only

    final categoryRepository = CategoryRepository(FakeCategoryRemoteSource());
    await categoryRepository.add(
      CategoryModel()
        ..name = 'Housing'
        ..type = CategoryType.expense
        ..color = 0xFF64B5F6,
    );
    categoryId = (await categoryRepository.getAll()).single.id;

    transactions = TransactionRepository(
      FakeTransactionRemoteSource(),
      categoryRepository: categoryRepository,
    );
    service = RecurringTransactionService(
      recurringRepository: RecurringTransactionRepository(
        remote: FakeRecurringTransactionRemoteSource(),
        categoryRepository: categoryRepository,
      ),
      transactionRepository: transactions,
    );
  });

  tearDown(() async {
    setNetwork(online: true);
    await TestIsar.close();
  });

  Future<RecurringTransactionModel> template({
    required DateTime due,
    RecurringIntervalType interval = RecurringIntervalType.monthly,
  }) {
    return service.saveTemplate(
      RecurringTransactionModel()
        ..title = 'Rent'
        ..type = TransactionType.expense
        ..defaultAmount = 800
        ..amountType = RecurringAmountType.fixed
        ..categoryId = categoryId
        ..intervalType = interval
        ..intervalCount = 1
        ..nextDueDate = due
        ..isActive = true
        ..createdAt = DateTime(2026, 1, 1),
    );
  }

  test('a monthly 31st returns to the 31st after a short month', () async {
    final t = await template(due: DateTime(2026, 1, 31));

    final seen = <DateTime>[];
    for (var i = 0; i < 4; i++) {
      await service.skipRecurringTransaction(t);
      seen.add(t.nextDueDate);
    }

    expect(seen, [
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
      DateTime(2026, 4, 30),
      DateTime(2026, 5, 31),
    ]);
  });

  test('a yearly Feb 29 comes back on leap years', () async {
    final t = await template(
      due: DateTime(2028, 2, 29),
      interval: RecurringIntervalType.yearly,
    );

    final seen = <DateTime>[];
    for (var i = 0; i < 4; i++) {
      await service.skipRecurringTransaction(t);
      seen.add(t.nextDueDate);
    }

    expect(seen, [
      DateTime(2029, 2, 28),
      DateTime(2030, 2, 28),
      DateTime(2031, 2, 28),
      DateTime(2032, 2, 29),
    ]);
  });

  test(
    'a confirmed item is dated on its due date, not on confirm day',
    () async {
      final t = await template(due: DateTime(2026, 1, 5));

      final tx = await service.confirmRecurringTransaction(t);

      expect(tx.date, DateTime(2026, 1, 5));
      expect(t.nextDueDate, DateTime(2026, 2, 5));
    },
  );

  test(
    'confirming a period that is already recorded does not add it again',
    () async {
      final t = await template(due: DateTime(2026, 1, 5));
      await service.confirmRecurringTransaction(t);

      // The app died after the transaction was saved but before the template
      // advanced: the due date is still 5 Jan.
      t.nextDueDate = DateTime(2026, 1, 5);
      await service.confirmRecurringTransaction(t);

      final all = await transactions.getAll();
      expect(all, hasLength(1));
      expect(t.nextDueDate, DateTime(2026, 2, 5));
    },
  );
}
