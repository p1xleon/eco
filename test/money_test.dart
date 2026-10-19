import 'package:eco/core/utils/group_transactions.dart';
import 'package:eco/core/utils/money.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel income(double amount) => TransactionModel()
  ..title = 't'
  ..amount = amount
  ..date = DateTime(2026, 3, 5)
  ..type = TransactionType.income
  ..categoryId = 1
  ..createdAt = DateTime(2026, 3, 5);

void main() {
  group('parseAmount', () {
    test('accepts normal amounts and rounds to cents', () {
      expect(parseAmount('12.5'), 12.5);
      expect(parseAmount(' 7 '), 7);
      expect(parseAmount('1.239'), 1.24);
    });

    test('rejects zero, negatives, NaN, infinity, huge and junk', () {
      for (final raw in [
        '0',
        '-50',
        'NaN',
        'Infinity',
        '1e308',
        'abc',
        '',
        '0.004',
      ]) {
        expect(parseAmount(raw), isNull, reason: raw);
      }
      expect(parseAmount(null), isNull);
    });
  });

  test('formatMoney groups thousands with two decimals', () {
    expect(formatMoney(1234.5), '₹1,234.50');
    expect(formatMoney(0), '₹0.00');
  });

  test('monthly totals do not carry floating point noise', () {
    final groups = groupTransactionsByMonth([
      for (var i = 0; i < 10; i++) income(0.1),
    ]);

    expect(groups.single.income, 1.0);
  });
}
