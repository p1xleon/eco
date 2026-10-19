import 'package:eco/features/recurring/data/models/recurring_transaction_mapper.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/transactions/data/models/transaction_mapper.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dates go to `timestamptz` columns, so they must carry an offset. A local
/// DateTime serialised without one is read as UTC: 22:00 IST came back as
/// 03:30 the next day.
void main() {
  final evening = DateTime(2026, 10, 19, 22, 30);

  test(
    'transaction dates are sent with an offset and keep the same instant',
    () {
      final tx = TransactionModel()
        ..title = 't'
        ..amount = 1
        ..date = evening
        ..type = TransactionType.expense
        ..categoryId = 1
        ..createdAt = evening
        ..updatedAt = evening;

      final json = tx.toJson('u');
      for (final key in ['date', 'created_at', 'updated_at']) {
        expect(json[key], endsWith('Z'), reason: key);
      }

      json['id'] = 'r1';
      final back = TransactionMapper.fromJson(json);
      expect(back.date.isAtSameMomentAs(evening), isTrue);
      expect(back.createdAt.isAtSameMomentAs(evening), isTrue);
      expect(back.updatedAt!.isAtSameMomentAs(evening), isTrue);
      expect(back.date.isUtc, isFalse);
    },
  );

  test(
    'recurring timestamptz columns carry an offset, end_date stays naive',
    () {
      final template = RecurringTransactionModel()
        ..title = 't'
        ..type = TransactionType.expense
        ..amountType = RecurringAmountType.fixed
        ..defaultAmount = 1
        ..categoryId = 1
        ..intervalType = RecurringIntervalType.monthly
        ..intervalCount = 1
        ..nextDueDate = evening
        ..endDate = evening
        ..isActive = true
        ..createdAt = evening;

      final json = template.toJson('u');
      expect(json['next_due_date'], endsWith('Z'));
      expect(json['created_at'], endsWith('Z'));
      // `timestamp without time zone` on the server: wall-clock text is right.
      expect(json['end_date'], isNot(endsWith('Z')));
    },
  );
}
