import '../../data/models/transaction_fingerprint.dart';
import '../../data/models/transaction_model.dart';
import 'bulk_schedule.dart';

/// One row in the bulk-add review: a transaction that does not exist yet.
class BulkEntry {
  /// Stable across edits and removals, so the list can keep its identity.
  final int key;
  final DateTime date;
  final double amount;
  final String title;
  final int categoryId;
  final String? payee;
  final String? paymentMethod;
  final String? note;
  final bool selected;

  /// Something equal (same day, amount and title) is already stored.
  final bool duplicate;

  const BulkEntry({
    required this.key,
    required this.date,
    required this.amount,
    required this.title,
    required this.categoryId,
    this.payee,
    this.paymentMethod,
    this.note,
    this.selected = true,
    this.duplicate = false,
  });

  String get fingerprint =>
      transactionFingerprint(date: date, amount: amount, title: title);

  BulkEntry copyWith({
    DateTime? date,
    double? amount,
    String? title,
    int? categoryId,
    String? payee,
    String? paymentMethod,
    String? note,
    bool? selected,
    bool? duplicate,
  }) {
    return BulkEntry(
      key: key,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      payee: payee ?? this.payee,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      selected: selected ?? this.selected,
      duplicate: duplicate ?? this.duplicate,
    );
  }

  /// What is wrong with this row, or null when it can be saved.
  String? error({DateTime? today}) {
    final now = today ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);

    if (title.trim().isEmpty) return 'Title is required';
    if (!amount.isFinite || amount <= 0) return 'Amount must be above zero';
    if (day.isBefore(earliestBulkDate)) return 'Date is before the year 2000';
    if (day.isAfter(DateTime(now.year, now.month, now.day))) {
      return 'Date is in the future';
    }

    return null;
  }
}

/// One entry per date, sharing the same details. Rows that match something
/// already stored start unticked, so a partly entered year only adds what is
/// missing.
List<BulkEntry> buildBulkEntries({
  required List<DateTime> dates,
  required double amount,
  required String title,
  required int categoryId,
  required Set<String> existing,
  String? payee,
  String? paymentMethod,
  String? note,
}) {
  return [
    for (var i = 0; i < dates.length; i++)
      _flagged(
        BulkEntry(
          key: i,
          date: dates[i],
          amount: amount,
          title: title,
          categoryId: categoryId,
          payee: payee,
          paymentMethod: paymentMethod,
          note: note,
        ),
        existing,
      ),
  ];
}

/// Re-checks one row against what is stored. A row that has just become a
/// duplicate is unticked; one that stopped being a duplicate keeps its tick.
BulkEntry recheckDuplicate(BulkEntry entry, Set<String> existing) {
  final isDuplicate = existing.contains(entry.fingerprint);

  return entry.copyWith(
    duplicate: isDuplicate,
    selected: isDuplicate ? false : entry.selected,
  );
}

BulkEntry _flagged(BulkEntry entry, Set<String> existing) {
  final isDuplicate = existing.contains(entry.fingerprint);

  return entry.copyWith(duplicate: isDuplicate, selected: !isDuplicate);
}

/// The transaction a row becomes. Always paid: bulk add records what already
/// happened.
TransactionModel bulkEntryToTransaction(
  BulkEntry entry, {
  required TransactionType type,
  DateTime? now,
}) {
  String? clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  return TransactionModel()
    ..title = entry.title.trim()
    ..amount = entry.amount
    ..date = entry.date
    ..type = type
    ..status = TransactionStatus.paid
    ..categoryId = entry.categoryId
    ..payee = clean(entry.payee)
    ..paymentMethod = clean(entry.paymentMethod)
    ..note = clean(entry.note)
    ..createdAt = (now ?? DateTime.now()).toUtc();
}
