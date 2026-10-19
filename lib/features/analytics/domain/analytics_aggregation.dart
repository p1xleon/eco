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
    final latest = txs
        .map((tx) => tx.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    start = DateTime(earliest.year, earliest.month);
    // Cover future-dated rows too, or they vanish from the charts.
    final lastMonth = latest.isAfter(now) ? latest : now;
    end = DateTime(lastMonth.year, lastMonth.month + 1);
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
  return daily ? buckets : capBuckets(buckets);
}

/// Totals indexed Monday (0) to Sunday (6).
List<double> weekdayTotals(List<TransactionModel> txs) {
  final totals = List.filled(7, 0.0);
  for (final tx in txs) {
    totals[tx.date.weekday - 1] += tx.amount;
  }
  return totals;
}

/// Collapses daily buckets into 7-day weeks (W1 = days 1-7, ...).
List<BucketTotal> toWeeklyBuckets(List<BucketTotal> daily) {
  final weeks = <BucketTotal>[];
  for (var i = 0; i < daily.length; i += 7) {
    final chunk = daily.skip(i).take(7);
    weeks.add(
      BucketTotal(
        chunk.first.start,
        income: chunk.fold(0.0, (s, b) => s + b.income),
        expense: chunk.fold(0.0, (s, b) => s + b.expense),
      ),
    );
  }
  return weeks;
}

/// Short Indian-style amount for chart axes: 950, 1.2k, 45k, 1.2L, 2.5Cr.
String compactAmount(double value) {
  final v = value.abs();
  String fmt(double n, String unit) {
    final s = n >= 10 ? n.round().toString() : n.toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}$unit';
  }

  final sign = value < 0 ? '-' : '';
  if (v >= 10000000) return '$sign₹${fmt(v / 10000000, 'Cr')}';
  if (v >= 100000) return '$sign₹${fmt(v / 100000, 'L')}';
  if (v >= 1000) return '$sign₹${fmt(v / 1000, 'k')}';
  return '$sign₹${v.round()}';
}

/// Past [maxMonthly] monthly buckets the axis is unreadable (an old or mistyped
/// date can span decades), so they collapse into one bucket per year.
List<BucketTotal> capBuckets(List<BucketTotal> monthly, {int maxMonthly = 24}) {
  if (monthly.length <= maxMonthly) return monthly;

  final years = <int, BucketTotal>{};
  for (final b in monthly) {
    final prev = years[b.start.year];
    years[b.start.year] = BucketTotal(
      DateTime(b.start.year),
      income: (prev?.income ?? 0) + b.income,
      expense: (prev?.expense ?? 0) + b.expense,
    );
  }
  return years.values.toList();
}
