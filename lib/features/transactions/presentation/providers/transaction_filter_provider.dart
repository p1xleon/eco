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

  void setPaymentMethod(String? value) {
    state = state.copyWith(paymentMethod: value);
  }

  void setPayee(String? value) {
    state = state.copyWith(payee: value);
  }

  void setAmountRange(double? min, double? max) {
    state = state.copyWith(minAmount: min, maxAmount: max);
  }

  void setRecurring(RecurringFilter value) {
    state = state.copyWith(recurring: value);
  }

  void setSyncStatus(SyncStatusFilter value) {
    state = state.copyWith(syncStatus: value);
  }

  void setNotes(NotesFilter value) {
    state = state.copyWith(notes: value);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDate: start, endDate: end);
  }

  void setFilter(TransactionFilter filter) {
    state = filter;
  }

  void clearAdvanced() {
    state = state.copyWith(
      type: null,
      categoryId: null,
      paymentMethod: null,
      payee: null,
      minAmount: null,
      maxAmount: null,
      recurring: RecurringFilter.all,
      syncStatus: SyncStatusFilter.all,
      notes: NotesFilter.all,
      startDate: null,
      endDate: null,
    );
  }

  void clear() {
    state = const TransactionFilter();
  }
}

final transactionFilterProvider =
    StateNotifierProvider<TransactionFilterNotifier, TransactionFilter>(
      (ref) => TransactionFilterNotifier(),
    );
