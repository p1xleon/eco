import '../../data/models/recurring_transaction_model.dart';
import '../../data/repositories/recurring_transaction_repository.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/data/repositories/transaction_repository.dart';

enum DashboardRecurringStatus { overdue, dueToday, upcoming }

class DashboardRecurringGroup {
  final DashboardRecurringStatus status;
  final List<RecurringTransactionModel> items;
  final int totalCount;

  const DashboardRecurringGroup({
    required this.status,
    required this.items,
    required this.totalCount,
  });
}

class DashboardRecurringSnapshot {
  final DashboardRecurringGroup overdue;
  final DashboardRecurringGroup dueToday;
  final DashboardRecurringGroup upcoming;
  final RecurringTransactionModel? nextUpcomingItem;

  const DashboardRecurringSnapshot({
    required this.overdue,
    required this.dueToday,
    required this.upcoming,
    this.nextUpcomingItem,
  });

  bool get isEmpty =>
      overdue.totalCount == 0 &&
      dueToday.totalCount == 0 &&
      upcoming.totalCount == 0;
}

class RecurringTransactionService {
  final RecurringTransactionRepository recurringRepository;
  final TransactionRepository transactionRepository;

  const RecurringTransactionService({
    required this.recurringRepository,
    required this.transactionRepository,
  });

  Future<List<RecurringTransactionModel>> getDueRecurringTransactions({
    DateTime? today,
  }) async {
    final templates = await recurringRepository.getAll();
    final referenceDate = _dateOnly(today ?? DateTime.now());

    return templates.where((item) => isDue(item, referenceDate)).toList();
  }

  Future<DashboardRecurringSnapshot> getDashboardRecurring({
    DateTime? today,
    int limitPerGroup = 3,
  }) async {
    final templates = await recurringRepository.getAll();
    final referenceDate = _dateOnly(today ?? DateTime.now());
    final cutoffDate = referenceDate.add(const Duration(days: 7));
    final activeTemplates = templates
        .where((item) => item.isActive && !_isPastEndDate(item))
        .toList();

    final visibleItems = activeTemplates
        .where((item) => !_dateOnly(item.nextDueDate).isAfter(cutoffDate))
        .toList();

    final overdueItems =
        visibleItems
            .where(
              (item) =>
                  getDashboardStatus(item, referenceDate) ==
                  DashboardRecurringStatus.overdue,
            )
            .toList()
          ..sort(
            (a, b) =>
                _dateOnly(a.nextDueDate).compareTo(_dateOnly(b.nextDueDate)),
          );

    final dueTodayItems =
        visibleItems
            .where(
              (item) =>
                  getDashboardStatus(item, referenceDate) ==
                  DashboardRecurringStatus.dueToday,
            )
            .toList()
          ..sort(
            (a, b) =>
                _dateOnly(a.nextDueDate).compareTo(_dateOnly(b.nextDueDate)),
          );

    final upcomingItems =
        visibleItems
            .where(
              (item) =>
                  getDashboardStatus(item, referenceDate) ==
                  DashboardRecurringStatus.upcoming,
            )
            .toList()
          ..sort(
            (a, b) =>
                _dateOnly(a.nextDueDate).compareTo(_dateOnly(b.nextDueDate)),
          );

    final futureItems =
        activeTemplates
            .where((item) => _dateOnly(item.nextDueDate).isAfter(cutoffDate))
            .toList()
          ..sort(
            (a, b) =>
                _dateOnly(a.nextDueDate).compareTo(_dateOnly(b.nextDueDate)),
          );

    return DashboardRecurringSnapshot(
      overdue: DashboardRecurringGroup(
        status: DashboardRecurringStatus.overdue,
        items: overdueItems.take(limitPerGroup).toList(),
        totalCount: overdueItems.length,
      ),
      dueToday: DashboardRecurringGroup(
        status: DashboardRecurringStatus.dueToday,
        items: dueTodayItems.take(limitPerGroup).toList(),
        totalCount: dueTodayItems.length,
      ),
      upcoming: DashboardRecurringGroup(
        status: DashboardRecurringStatus.upcoming,
        items: upcomingItems.take(limitPerGroup).toList(),
        totalCount: upcomingItems.length,
      ),
      nextUpcomingItem: futureItems.isEmpty ? null : futureItems.first,
    );
  }

  bool isDue(RecurringTransactionModel template, [DateTime? today]) {
    final referenceDate = _dateOnly(today ?? DateTime.now());
    return template.isActive &&
        !_isPastEndDate(template) &&
        !_dateOnly(template.nextDueDate).isAfter(referenceDate);
  }

  bool isOverdue(RecurringTransactionModel template, [DateTime? today]) {
    final referenceDate = _dateOnly(today ?? DateTime.now());
    return template.isActive &&
        !_isPastEndDate(template) &&
        _dateOnly(template.nextDueDate).isBefore(referenceDate);
  }

  DashboardRecurringStatus getDashboardStatus(
    RecurringTransactionModel template, [
    DateTime? today,
  ]) {
    final referenceDate = _dateOnly(today ?? DateTime.now());
    final dueDate = _dateOnly(template.nextDueDate);

    if (dueDate.isBefore(referenceDate)) {
      return DashboardRecurringStatus.overdue;
    }

    if (dueDate == referenceDate) {
      return DashboardRecurringStatus.dueToday;
    }

    return DashboardRecurringStatus.upcoming;
  }

  DateTime calculateNextDueDate(
    RecurringTransactionModel template, {
    DateTime? fromDate,
  }) {
    final base = _dateOnly(fromDate ?? template.nextDueDate);

    switch (template.intervalType) {
      case RecurringIntervalType.daily:
        return base.add(Duration(days: template.intervalCount));
      case RecurringIntervalType.weekly:
        return base.add(Duration(days: 7 * template.intervalCount));
      case RecurringIntervalType.monthly:
        return _addMonthsClamped(base, template.intervalCount);
      case RecurringIntervalType.yearly:
        return _addYearsClamped(base, template.intervalCount);
    }
  }

  Future<TransactionModel> confirmRecurringTransaction(
    RecurringTransactionModel template, {
    double? amount,
    DateTime? transactionDate,
  }) async {
    final resolvedAmount = _resolveAmount(template, amount);
    final now = DateTime.now();
    final transaction = TransactionModel()
      ..title = template.title
      ..amount = resolvedAmount
      ..date = transactionDate ?? now
      ..type = template.type
      ..categoryId = template.categoryId
      ..note = template.note
      ..createdAt = now
      ..updatedAt = now
      ..recurringId = template.id.toString()
      ..recurringTemplateId = template.id
      ..isRecurringInstance = true;

    final savedTransaction = await transactionRepository.add(transaction);

    template.nextDueDate = calculateNextDueDate(template);
    if (_isPastEndDate(template)) {
      template.isActive = false;
    }
    template.updatedAt = now;
    await recurringRepository.save(template);

    return savedTransaction;
  }

  Future<void> skipRecurringTransaction(
    RecurringTransactionModel template,
  ) async {
    template.nextDueDate = calculateNextDueDate(template);
    if (_isPastEndDate(template)) {
      template.isActive = false;
    }
    template.updatedAt = DateTime.now();
    await recurringRepository.save(template);
  }

  Future<RecurringTransactionModel> saveTemplate(
    RecurringTransactionModel template,
  ) {
    template.updatedAt = DateTime.now();
    return recurringRepository.save(template);
  }

  Future<void> deleteTemplate(int id) {
    return recurringRepository.delete(id);
  }

  double _resolveAmount(RecurringTransactionModel template, double? amount) {
    if (amount != null && amount > 0) {
      return amount;
    }

    if (template.amountType == RecurringAmountType.fixed) {
      final fixedAmount = template.defaultAmount;
      if (fixedAmount == null) {
        throw StateError(
          'Fixed recurring transactions require a default amount.',
        );
      }

      return fixedAmount;
    }

    if (amount == null || amount <= 0) {
      throw StateError(
        'Variable recurring transactions require a valid amount.',
      );
    }

    return amount;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isPastEndDate(RecurringTransactionModel template) {
    final endDate = template.endDate;
    if (endDate == null) {
      return false;
    }

    return _dateOnly(template.nextDueDate).isAfter(_dateOnly(endDate));
  }

  DateTime _addMonthsClamped(DateTime value, int months) {
    final targetMonth = value.month + months;
    final firstDayOfTargetMonth = DateTime(value.year, targetMonth, 1);
    final lastDay = DateTime(
      firstDayOfTargetMonth.year,
      firstDayOfTargetMonth.month + 1,
      0,
    ).day;

    return DateTime(
      firstDayOfTargetMonth.year,
      firstDayOfTargetMonth.month,
      value.day > lastDay ? lastDay : value.day,
    );
  }

  DateTime _addYearsClamped(DateTime value, int years) {
    final targetYear = value.year + years;
    final lastDay = DateTime(targetYear, value.month + 1, 0).day;

    return DateTime(
      targetYear,
      value.month,
      value.day > lastDay ? lastDay : value.day,
    );
  }
}
