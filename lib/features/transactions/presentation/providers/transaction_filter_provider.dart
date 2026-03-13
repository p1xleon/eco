import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction_model.dart';
import 'transaction_filter.dart';

class TransactionFilterNotifier extends StateNotifier<TransactionFilter> {
  TransactionFilterNotifier() : super(const TransactionFilter());

  void setSearch(String value) {
    state = state.copyWith(search: value);
  }

  void setType(TransactionType? type) {
    state = state.copyWith(type: type);
  }

  void setCategory(int? id) {
    state = state.copyWith(categoryId: id);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDate: start, endDate: end);
  }

  void clear() {
    state = const TransactionFilter();
  }
}

final transactionFilterProvider =
    StateNotifierProvider<TransactionFilterNotifier, TransactionFilter>(
      (ref) => TransactionFilterNotifier(),
    );
