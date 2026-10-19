import '../../transactions/data/models/transaction_model.dart';

/// Half-open range: [start, end).
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}

class BucketTotal {
  final DateTime start;
  final double income;
  final double expense;

  const BucketTotal(this.start, {this.income = 0, this.expense = 0});
}

/// Calendar-month based periods, so "previous period" is always a clean month span.
enum AnalyticsPeriod {
  thisMonth('This month', 0, 1),
  lastMonth('Last month', -1, 1),
  threeMonths('3 months', -2, 3),
  sixMonths('6 months', -5, 6),
  year('12 months', -11, 12),
  all('All time', 0, 0);

  final String label;
  final int _startOffset;
  final int months;

  const AnalyticsPeriod(this.label, this._startOffset, this.months);

  bool get isDaily => months == 1;

  DateRange? range(DateTime now) {
    if (this == all) return null;
    return DateRange(
      DateTime(now.year, now.month + _startOffset),
      DateTime(now.year, now.month + _startOffset + months),
    );
  }

  DateRange? previousRange(DateTime now) {
    final current = range(now);
    if (current == null) return null;
    return DateRange(
      DateTime(current.start.year, current.start.month - months),
      current.start,
    );
  }
}

List<TransactionModel> inRange(List<TransactionModel> txs, DateRange? range) =>
    range == null ? txs : txs.where((tx) => range.contains(tx.date)).toList();

double sumAmounts(Iterable<TransactionModel> txs) =>
    txs.fold(0.0, (total, tx) => total + tx.amount);

/// Percent change from [previous] to [current]; null when there is no baseline.
double? percentChange(double current, double previous) =>
    previous == 0 ? null : (current - previous) / previous * 100;

/// Income/expense totals per day (single-month periods) or per month, zero-filled.
List<BucketTotal> buildBuckets(
  List<TransactionModel> txs,
  AnalyticsPeriod period,
  DateTime now,
) {
  final range = period.range(now);
  final DateTime start;
  final DateTime end;
  if (range != null) {
    start = range.start;
    end = range.end;
  } else {
    if (txs.isEmpty) return const [];
    final earliest = txs
        .map((tx) => tx.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    start = DateTime(earliest.year, earliest.month);
    end = DateTime(now.year, now.month + 1);
  }

  final daily = period.isDaily;
  DateTime bucketOf(DateTime d) =>
      daily ? DateTime(d.year, d.month, d.day) : DateTime(d.year, d.month);

  final income = <DateTime, double>{};
  final expense = <DateTime, double>{};
  for (final tx in txs) {
    if (tx.date.isBefore(start) || !tx.date.isBefore(end)) continue;
    final target = tx.type == TransactionType.income ? income : expense;
    final key = bucketOf(tx.date);
    target[key] = (target[key] ?? 0) + tx.amount;
  }

  final buckets = <BucketTotal>[];
  for (
    var cursor = start;
    cursor.isBefore(end);
    cursor = daily
        ? DateTime(cursor.year, cursor.month, cursor.day + 1)
        : DateTime(cursor.year, cursor.month + 1)
  ) {
    buckets.add(
      BucketTotal(
        cursor,
        income: income[cursor] ?? 0,
        expense: expense[cursor] ?? 0,
      ),
    );
  }
  return buckets;
}

/// Totals indexed Monday (0) to Sunday (6).
List<double> weekdayTotals(List<TransactionModel> txs) {
  final totals = List.filled(7, 0.0);
  for (final tx in txs) {
    totals[tx.date.weekday - 1] += tx.amount;
  }
  return totals;
}
