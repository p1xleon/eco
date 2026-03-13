import '../../data/models/transaction_model.dart';

class TransactionFilter {
  final String search;
  final TransactionType? type;
  final int? categoryId;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilter({
    this.search = '',
    this.type,
    this.categoryId,
    this.startDate,
    this.endDate,
  });

  // Use an explicit sentinel so we can pass `null` to clear the filter.
  TransactionFilter copyWith({
    String? search,
    Object? type = const Object(),
    Object? categoryId = const Object(),
    Object? startDate = const Object(),
    Object? endDate = const Object(),
  }) {
    return TransactionFilter(
      search: search ?? this.search,
      type: type == const Object() ? this.type : type as TransactionType?,
      categoryId: categoryId == const Object() ? this.categoryId : categoryId as int?,
      startDate: startDate == const Object() ? this.startDate : startDate as DateTime?,
      endDate: endDate == const Object() ? this.endDate : endDate as DateTime?,
    );
  }
}
