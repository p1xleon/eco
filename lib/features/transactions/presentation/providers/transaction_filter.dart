import '../../data/models/transaction_model.dart';

enum RecurringFilter { all, recurringOnly, nonRecurringOnly }

enum SyncStatusFilter { all, syncedOnly, localOnly }

enum NotesFilter { all, withNotes, withoutNotes }

class TransactionFilter {
  final String search;
  final TransactionType? type;
  final int? categoryId;
  final String? paymentMethod;
  final String? payee;
  final double? minAmount;
  final double? maxAmount;
  final RecurringFilter recurring;
  final SyncStatusFilter syncStatus;
  final NotesFilter notes;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilter({
    this.search = '',
    this.type,
    this.categoryId,
    this.paymentMethod,
    this.payee,
    this.minAmount,
    this.maxAmount,
    this.recurring = RecurringFilter.all,
    this.syncStatus = SyncStatusFilter.all,
    this.notes = NotesFilter.all,
    this.startDate,
    this.endDate,
  });

  // Use an explicit sentinel so we can pass `null` to clear the filter.
  TransactionFilter copyWith({
    String? search,
    Object? type = const Object(),
    Object? categoryId = const Object(),
    Object? paymentMethod = const Object(),
    Object? payee = const Object(),
    Object? minAmount = const Object(),
    Object? maxAmount = const Object(),
    RecurringFilter? recurring,
    SyncStatusFilter? syncStatus,
    NotesFilter? notes,
    Object? startDate = const Object(),
    Object? endDate = const Object(),
  }) {
    return TransactionFilter(
      search: search ?? this.search,
      type: type == const Object() ? this.type : type as TransactionType?,
      categoryId: categoryId == const Object() ? this.categoryId : categoryId as int?,
      paymentMethod: paymentMethod == const Object()
          ? this.paymentMethod
          : paymentMethod as String?,
      payee: payee == const Object() ? this.payee : payee as String?,
      minAmount: minAmount == const Object() ? this.minAmount : minAmount as double?,
      maxAmount: maxAmount == const Object() ? this.maxAmount : maxAmount as double?,
      recurring: recurring ?? this.recurring,
      syncStatus: syncStatus ?? this.syncStatus,
      notes: notes ?? this.notes,
      startDate: startDate == const Object() ? this.startDate : startDate as DateTime?,
      endDate: endDate == const Object() ? this.endDate : endDate as DateTime?,
    );
  }

  int get activeCount {
    var count = 0;
    if (type != null) count++;
    if (categoryId != null) count++;
    if (paymentMethod != null) count++;
    if (payee != null) count++;
    if (minAmount != null) count++;
    if (maxAmount != null) count++;
    if (recurring != RecurringFilter.all) count++;
    if (syncStatus != SyncStatusFilter.all) count++;
    if (notes != NotesFilter.all) count++;
    if (startDate != null) count++;
    if (endDate != null) count++;
    return count;
  }
}
