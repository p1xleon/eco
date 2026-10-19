/// How often a bulk-added transaction repeats.
enum BulkFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  quarterly('Quarterly'),
  halfYearly('Half-yearly'),
  yearly('Yearly'),
  custom('Custom');

  final String label;

  const BulkFrequency(this.label);
}

enum BulkUnit { days, weeks, months, years }

/// One batch never goes past this many rows, so a mistyped start year cannot
/// create thousands of transactions.
const maxBulkRows = 366;

/// Bulk add is for entries that should already exist, so dates stop at today and
/// do not go earlier than import allows.
final earliestBulkDate = DateTime(2000);

class BulkDates {
  final List<DateTime> dates;

  /// True when the range held more than [maxBulkRows] dates and was cut short.
  final bool truncated;

  const BulkDates(this.dates, {this.truncated = false});
}

/// A repeat pattern over a closed date range, generated as calendar dates.
class BulkSchedule {
  final BulkFrequency frequency;
  final int customEvery;
  final BulkUnit customUnit;
  final DateTime from;
  final DateTime to;

  const BulkSchedule({
    required this.frequency,
    required this.from,
    required this.to,
    this.customEvery = 1,
    this.customUnit = BulkUnit.months,
  });

  (BulkUnit, int) get _step => switch (frequency) {
    BulkFrequency.daily => (BulkUnit.days, 1),
    BulkFrequency.weekly => (BulkUnit.weeks, 1),
    BulkFrequency.monthly => (BulkUnit.months, 1),
    BulkFrequency.quarterly => (BulkUnit.months, 3),
    BulkFrequency.halfYearly => (BulkUnit.months, 6),
    BulkFrequency.yearly => (BulkUnit.years, 1),
    BulkFrequency.custom => (customUnit, customEvery),
  };

  /// What is wrong with the schedule, or null when it can be generated.
  String? validate({DateTime? today}) {
    final now = _day(today ?? DateTime.now());

    if (frequency == BulkFrequency.custom && customEvery < 1) {
      return 'Repeat every must be at least 1.';
    }
    if (_day(from).isBefore(earliestBulkDate)) {
      return 'Start date cannot be before the year 2000.';
    }
    if (_day(to).isAfter(now)) {
      return 'End date cannot be in the future.';
    }
    if (_day(to).isBefore(_day(from))) {
      return 'End date must be on or after the start date.';
    }

    return null;
  }

  /// Every date from [from] to [to] inclusive. A monthly pattern started on the
  /// 31st stays on the 31st where the month allows it and clamps to the last day
  /// otherwise, so one short month does not drag the rest down.
  BulkDates generate({DateTime? today}) {
    if (validate(today: today) != null) return const BulkDates([]);

    final start = _day(from);
    final end = _day(to);
    final (unit, step) = _step;

    final dates = <DateTime>[];
    for (var k = 0; ; k++) {
      final date = _nth(start, unit, step, k);
      if (date.isAfter(end)) break;
      if (dates.length == maxBulkRows) {
        return BulkDates(dates, truncated: true);
      }
      dates.add(date);
    }

    return BulkDates(dates);
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _nth(DateTime start, BulkUnit unit, int step, int k) {
    return switch (unit) {
      BulkUnit.days => DateTime(start.year, start.month, start.day + k * step),
      BulkUnit.weeks => DateTime(
        start.year,
        start.month,
        start.day + 7 * k * step,
      ),
      BulkUnit.months => _addMonths(start, k * step),
      BulkUnit.years => _addMonths(start, 12 * k * step),
    };
  }

  static DateTime _addMonths(DateTime start, int months) {
    final firstOfTarget = DateTime(start.year, start.month + months);
    final lastDay = DateTime(
      firstOfTarget.year,
      firstOfTarget.month + 1,
      0,
    ).day;

    return DateTime(
      firstOfTarget.year,
      firstOfTarget.month,
      start.day > lastDay ? lastDay : start.day,
    );
  }
}
