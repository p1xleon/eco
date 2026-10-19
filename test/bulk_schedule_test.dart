import 'package:eco/features/transactions/bulk/domain/bulk_entry.dart';
import 'package:eco/features/transactions/bulk/domain/bulk_schedule.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 19);

BulkSchedule schedule(
  BulkFrequency frequency,
  DateTime from,
  DateTime to, {
  int every = 1,
  BulkUnit unit = BulkUnit.months,
}) => BulkSchedule(
  frequency: frequency,
  from: from,
  to: to,
  customEvery: every,
  customUnit: unit,
);

List<DateTime> datesOf(BulkSchedule s) => s.generate(today: today).dates;

void main() {
  group('frequencies', () {
    test('monthly includes both ends of the range', () {
      expect(
        datesOf(
          schedule(
            BulkFrequency.monthly,
            DateTime(2026, 1, 5),
            DateTime(2026, 4, 5),
          ),
        ),
        [
          DateTime(2026, 1, 5),
          DateTime(2026, 2, 5),
          DateTime(2026, 3, 5),
          DateTime(2026, 4, 5),
        ],
      );
    });

    test('quarterly steps 3 months and half-yearly 6', () {
      expect(
        datesOf(
          schedule(
            BulkFrequency.quarterly,
            DateTime(2025, 1, 10),
            DateTime(2025, 12, 31),
          ),
        ),
        [
          DateTime(2025, 1, 10),
          DateTime(2025, 4, 10),
          DateTime(2025, 7, 10),
          DateTime(2025, 10, 10),
        ],
      );
      expect(
        datesOf(
          schedule(
            BulkFrequency.halfYearly,
            DateTime(2024, 3, 1),
            DateTime(2026, 3, 1),
          ),
        ),
        [
          DateTime(2024, 3, 1),
          DateTime(2024, 9, 1),
          DateTime(2025, 3, 1),
          DateTime(2025, 9, 1),
          DateTime(2026, 3, 1),
        ],
      );
    });

    test('yearly and a leap day that clamps then returns', () {
      expect(
        datesOf(
          schedule(
            BulkFrequency.yearly,
            DateTime(2020, 2, 29),
            DateTime(2024, 3, 1),
          ),
        ),
        [
          DateTime(2020, 2, 29),
          DateTime(2021, 2, 28),
          DateTime(2022, 2, 28),
          DateTime(2023, 2, 28),
          DateTime(2024, 2, 29),
        ],
      );
    });

    test('a monthly 31st clamps in short months without drifting', () {
      expect(
        datesOf(
          schedule(
            BulkFrequency.monthly,
            DateTime(2026, 1, 31),
            DateTime(2026, 5, 31),
          ),
        ),
        [
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 31),
          DateTime(2026, 4, 30),
          DateTime(2026, 5, 31),
        ],
      );
    });

    test('daily and weekly', () {
      expect(
        datesOf(
          schedule(
            BulkFrequency.daily,
            DateTime(2026, 2, 27),
            DateTime(2026, 3, 2),
          ),
        ),
        hasLength(4), // 27, 28 Feb, 1, 2 Mar
      );
      expect(
        datesOf(
          schedule(
            BulkFrequency.weekly,
            DateTime(2026, 3, 1),
            DateTime(2026, 3, 22),
          ),
        ),
        [
          DateTime(2026, 3, 1),
          DateTime(2026, 3, 8),
          DateTime(2026, 3, 15),
          DateTime(2026, 3, 22),
        ],
      );
    });

    test('custom: every 2 months', () {
      expect(
        datesOf(
          schedule(
            BulkFrequency.custom,
            DateTime(2026, 1, 15),
            DateTime(2026, 7, 15),
            every: 2,
          ),
        ),
        [
          DateTime(2026, 1, 15),
          DateTime(2026, 3, 15),
          DateTime(2026, 5, 15),
          DateTime(2026, 7, 15),
        ],
      );
    });

    test('a single date when from equals to', () {
      expect(
        datesOf(
          schedule(
            BulkFrequency.monthly,
            DateTime(2026, 5, 5),
            DateTime(2026, 5, 5),
          ),
        ),
        [DateTime(2026, 5, 5)],
      );
    });
  });

  group('limits', () {
    test(
      'rejects future end, reversed range, pre-2000 start, bad custom step',
      () {
        expect(
          schedule(
            BulkFrequency.monthly,
            DateTime(2026, 1, 1),
            DateTime(2026, 12, 1),
          ).validate(today: today),
          contains('future'),
        );
        expect(
          schedule(
            BulkFrequency.monthly,
            DateTime(2026, 5, 1),
            DateTime(2026, 4, 1),
          ).validate(today: today),
          contains('on or after'),
        );
        expect(
          schedule(
            BulkFrequency.monthly,
            DateTime(1999, 1, 1),
            DateTime(2026, 4, 1),
          ).validate(today: today),
          contains('2000'),
        );
        expect(
          schedule(
            BulkFrequency.custom,
            DateTime(2026, 1, 1),
            DateTime(2026, 4, 1),
            every: 0,
          ).validate(today: today),
          contains('at least 1'),
        );
      },
    );

    test('an invalid schedule generates nothing', () {
      expect(
        datesOf(
          schedule(
            BulkFrequency.monthly,
            DateTime(2026, 5, 1),
            DateTime(2026, 4, 1),
          ),
        ),
        isEmpty,
      );
    });

    test('daily over years is cut at the row cap and says so', () {
      final result = schedule(
        BulkFrequency.daily,
        DateTime(2020, 1, 1),
        DateTime(2026, 10, 1),
      ).generate(today: today);

      expect(result.dates, hasLength(maxBulkRows));
      expect(result.truncated, isTrue);
    });
  });

  group('entries', () {
    final dates = [
      DateTime(2026, 1, 5),
      DateTime(2026, 2, 5),
      DateTime(2026, 3, 5),
    ];

    BulkEntry entry(
      DateTime date, {
      double amount = 100,
      String title = 'Rent',
    }) => BulkEntry(
      key: 0,
      date: date,
      amount: amount,
      title: title,
      categoryId: 1,
    );

    test('rows matching stored transactions start unticked and flagged', () {
      final existing = {entry(DateTime(2026, 2, 5)).fingerprint};

      final rows = buildBulkEntries(
        dates: dates,
        amount: 100,
        title: 'Rent',
        categoryId: 1,
        existing: existing,
      );

      expect(rows.map((r) => r.duplicate), [false, true, false]);
      expect(rows.map((r) => r.selected), [true, false, true]);
    });

    test('the fingerprint ignores case and spacing in the title', () {
      expect(
        entry(DateTime(2026, 2, 5), title: ' rent ').fingerprint,
        entry(DateTime(2026, 2, 5), title: 'RENT').fingerprint,
      );
    });

    test(
      'editing a row into a duplicate unticks it, out of one keeps the tick',
      () {
        final stored = {entry(DateTime(2026, 2, 5)).fingerprint};

        final becomes = recheckDuplicate(entry(DateTime(2026, 2, 5)), stored);
        expect(becomes.duplicate, isTrue);
        expect(becomes.selected, isFalse);

        final leaves = recheckDuplicate(
          entry(DateTime(2026, 2, 6)).copyWith(selected: true),
          stored,
        );
        expect(leaves.duplicate, isFalse);
        expect(leaves.selected, isTrue);
      },
    );

    test('row errors: title, amount, date range', () {
      expect(
        entry(DateTime(2026, 1, 1), title: ' ').error(today: today),
        isNotNull,
      );
      expect(
        entry(DateTime(2026, 1, 1), amount: 0).error(today: today),
        isNotNull,
      );
      expect(
        entry(DateTime(2026, 12, 1)).error(today: today),
        contains('future'),
      );
      expect(entry(DateTime(1999, 1, 1)).error(today: today), contains('2000'));
      expect(entry(DateTime(2026, 1, 1)).error(today: today), isNull);
    });

    test('a row becomes a paid transaction of the chosen type', () {
      final tx = bulkEntryToTransaction(
        entry(DateTime(2026, 1, 5)).copyWith(payee: ' Landlord ', note: ''),
        type: TransactionType.expense,
      );

      expect(tx.status, TransactionStatus.paid);
      expect(tx.type, TransactionType.expense);
      expect(tx.date, DateTime(2026, 1, 5));
      expect(tx.payee, 'Landlord');
      expect(tx.note, isNull);
      expect(tx.remoteId, isNull);
    });
  });
}
