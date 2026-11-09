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
