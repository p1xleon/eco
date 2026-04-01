import 'recurring_transaction_model.dart';
import '../../../transactions/data/models/transaction_model.dart';

extension RecurringTransactionMapper on RecurringTransactionModel {
  Map<String, dynamic> toJson(String userId, {String? categoryRemoteId}) {
    return <String, dynamic>{
      'user_id': userId,
      'title': title,
      'type': type.name,
      'default_amount': defaultAmount,
      'amount_type': amountType.name,
      'category_id': categoryRemoteId,
      'account_id': accountId,
      'interval_type': intervalType.name,
      'interval_count': intervalCount,
      'next_due_date': nextDueDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static RecurringTransactionModel fromJson(
    Map<String, dynamic> json, {
    required int categoryId,
  }) {
    final model = RecurringTransactionModel();

    model.remoteId = json['id'] as String?;
    model.title = json['title'] as String;
    model.type = json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    model.defaultAmount = (json['default_amount'] as num?)?.toDouble();
    model.amountType = switch (json['amount_type']) {
      'variable' => RecurringAmountType.variable,
      _ => RecurringAmountType.fixed,
    };
    model.categoryId = categoryId;
    model.accountId = json['account_id'] as String?;
    model.intervalType = switch (json['interval_type']) {
      'daily' => RecurringIntervalType.daily,
      'weekly' => RecurringIntervalType.weekly,
      'yearly' => RecurringIntervalType.yearly,
      _ => RecurringIntervalType.monthly,
    };
    model.intervalCount = (json['interval_count'] as num?)?.toInt() ?? 1;
    model.nextDueDate = DateTime.parse(json['next_due_date'] as String);
    model.endDate = json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'] as String);
    model.isActive = json['is_active'] as bool? ?? true;
    model.note = json['note'] as String?;
    model.createdAt = DateTime.parse(json['created_at'] as String);
    model.updatedAt = json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String);

    return model;
  }
}
