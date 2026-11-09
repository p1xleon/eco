import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:eco/features/collections/presentation/providers/collection_provider.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel tx(int id, int? collectionId) => TransactionModel()
  ..id = id
  ..title = 't$id'
  ..amount = 10
  ..type = TransactionType.expense
  ..date = DateTime.utc(2026, 10, 1)
  ..categoryId = 1
  ..collectionId = collectionId
  ..createdAt = DateTime.utc(2026, 10, 1);

CollectionModel collection(int id, {required bool separate}) =>
    CollectionModel()
      ..id = id
      ..name = 'c$id'
      ..color = 0
      ..separate = separate;

void main() {
  test('main transactions drop separate collections only', () async {
    final container = ProviderContainer(
      overrides: [
        // 3 has no collection, 9 points at a deleted one.
        transactionsProvider.overrideWith(
          (ref) async => [tx(1, 1), tx(2, 2), tx(3, null), tx(4, 9)],
        ),
        collectionsProvider.overrideWith(
          (ref) async => [
            collection(1, separate: true),
            collection(2, separate: false),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(transactionsProvider.future);
    await container.read(collectionsByIdProvider.future);

    expect(
      container.read(mainTransactionsProvider).requireValue.map((t) => t.id),
      [2, 3, 4],
    );
    // Collection pages still see everything.
    expect(container.read(visibleTransactionsProvider).requireValue.length, 4);
  });
}
