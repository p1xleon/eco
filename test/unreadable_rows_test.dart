import 'package:eco/core/sync/sync_issues.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/features/transactions/data/models/transaction_mapper.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

TransactionModel buildTransaction(String title) {
  final now = DateTime.utc(2026, 8, 17);

  return TransactionModel()
    ..title = title
    ..amount = 4.5
    ..date = now
    ..type = TransactionType.expense
    ..categoryId = 1
    ..createdAt = now;
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

  tearDown(() async {
    SyncIssues.reportUnreadable('transactions', 0);
    await TestIsar.close();
  });

  test(
    'one unreadable server row does not stop the rest or delete good copies',
    () async {
      final saved = await repository.add(buildTransaction('Kept'));
      expect(saved.remoteId, isNotNull);

      // A row this device cannot parse (stand-in for wrong key / corrupt data).
      remote.rows['bad-1'] = {'id': 'bad-1', 'title': 'v1:garbage'};
      // A readable row from another device.
      final other = buildTransaction('Other').toJson('user-1')
        ..['id'] = 'other-1';
      remote.rows['other-1'] = other;

      repository.invalidateSyncWindow();
      final titles = (await repository.getAll()).map((t) => t.title).toSet();

      expect(titles, containsAll(['Kept', 'Other']));
      expect(SyncIssues.unreadable.value, 1);
    },
  );

  test(
    'a good local copy survives when its server row becomes unreadable',
    () async {
      final saved = await repository.add(buildTransaction('Kept'));

      // Same server row, now unreadable (e.g. key changed).
      remote.rows[saved.remoteId!] = {
        'id': saved.remoteId,
        'title': 'v1:garbage',
      };

      repository.invalidateSyncWindow();
      final titles = (await repository.getAll()).map((t) => t.title);

      expect(titles, ['Kept']);
      expect(SyncIssues.unreadable.value, 1);
    },
  );
}
