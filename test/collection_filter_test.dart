import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:eco/features/collections/presentation/providers/collection_provider.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/presentation/providers/transaction_filter_provider.dart';
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

void main() {
  final one = CollectionModel()
    ..id = 1
    ..name = 'Trip'
    ..color = 0;
  final two = CollectionModel()
    ..id = 2
    ..name = 'Reno'
    ..color = 0;

  Future<List<int>> filtered(int collectionId) async {
    final container = ProviderContainer(
      overrides: [
        transactionsProvider.overrideWith((ref) async => [tx(1, 1), tx(2, 2)]),
        collectionsProvider.overrideWith((ref) async => [one, two]),
      ],
    );
    addTearDown(container.dispose);

    await container.read(transactionsProvider.future);
    await container.read(collectionsByIdProvider.future);
    container
        .read(transactionFilterProvider.notifier)
        .setCollection(collectionId);

    return container
        .read(filteredTransactionsProvider)
        .requireValue
        .map((t) => t.id)
        .toList();
  }

  test('keeps only transactions in the chosen collection', () async {
    expect(await filtered(1), [1]);
  });

  test(
    'a filter on a deleted collection is ignored, not an empty list',
    () async {
      expect(await filtered(9), [1, 2]);
    },
  );
}
