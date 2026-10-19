import 'package:eco/features/analytics/domain/analytics_aggregation.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel tx(DateTime date, double amount, TransactionType type) =>
    TransactionModel()
      ..title = 't'
      ..amount = amount
      ..date = date
      ..type = type
      ..categoryId = 1
      ..createdAt = date;

void main() {
  final now = DateTime(2026, 3, 15);

  test('ranges are calendar months and previous range precedes them', () {
    final r = AnalyticsPeriod.threeMonths.range(now)!;
    expect(r.start, DateTime(2026, 1));
    expect(r.end, DateTime(2026, 4));
    final p = AnalyticsPeriod.threeMonths.previousRange(now)!;
    expect(p.start, DateTime(2025, 10));
    expect(p.end, DateTime(2026, 1));
    expect(AnalyticsPeriod.all.range(now), isNull);
  });

  test('inRange is half-open', () {
    final r = AnalyticsPeriod.thisMonth.range(now);
    final txs = [
      tx(DateTime(2026, 3), 1, TransactionType.expense),
      tx(DateTime(2026, 4), 1, TransactionType.expense),
    ];
    expect(inRange(txs, r), hasLength(1));
  });

  test('percentChange has no baseline for zero', () {
    expect(percentChange(50, 0), isNull);
    expect(percentChange(150, 100), 50);
  });

  test('daily buckets are zero-filled and split by type', () {
    final b = buildBuckets(
      [
        tx(DateTime(2026, 3, 2), 10, TransactionType.expense),
        tx(DateTime(2026, 3, 2), 5, TransactionType.income),
      ],
      AnalyticsPeriod.thisMonth,
      now,
    );
    expect(b, hasLength(31));
    expect(b[1].expense, 10);
    expect(b[1].income, 5);
    expect(b[0].expense, 0);
  });

  test('monthly buckets cover the whole span; all-time starts at earliest', () {
    expect(buildBuckets([], AnalyticsPeriod.sixMonths, now), hasLength(6));
    final b = buildBuckets(
      [tx(DateTime(2025, 12, 5), 1, TransactionType.expense)],
      AnalyticsPeriod.all,
      now,
    );
    expect(b.first.start, DateTime(2025, 12));
    expect(b, hasLength(4));
    expect(buildBuckets([], AnalyticsPeriod.all, now), isEmpty);
  });

  test('weekdayTotals is Monday-first', () {
    // 2026-03-16 is a Monday
    final t = weekdayTotals([
      tx(DateTime(2026, 3, 16), 7, TransactionType.expense),
    ]);
    expect(t[0], 7);
    expect(t.skip(1).every((v) => v == 0), isTrue);
  });
}
