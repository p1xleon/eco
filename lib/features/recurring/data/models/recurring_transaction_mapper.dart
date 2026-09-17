import '../../../../core/crypto/field_cipher.dart';
import '../../../transactions/data/models/transaction_model.dart';
import 'recurring_transaction_model.dart';

/// Column holding the encrypted default amount. See
/// [transactionAmountEncryptedColumn] for why amounts need their own column.
const recurringDefaultAmountEncryptedColumn = 'default_amount_enc';

extension RecurringTransactionMapper on RecurringTransactionModel {
  /// Builds the server row. See [TransactionMapper.toJson] for why [cipher] is
  /// optional.
  ///
  /// The schedule itself — interval, due dates, active flag — stays readable.
  /// It reveals that something recurs, not what it is or what it costs.
  Map<String, dynamic> toJson(
    String userId, {
    String? categoryRemoteId,
    FieldCipher? cipher,
  }) {
    return <String, dynamic>{
      'user_id': userId,
      'title': cipher == null ? title : cipher.encrypt(title),
      'type': type.name,
      'default_amount': cipher == null ? defaultAmount : null,
      recurringDefaultAmountEncryptedColumn:
          cipher?.encryptNumber(defaultAmount),
      'amount_type': amountType.name,
      'category_id': categoryRemoteId,
      'account_id': cipher == null ? accountId : cipher.encryptNullable(accountId),
      'interval_type': intervalType.name,
      'interval_count': intervalCount,
      'next_due_date': nextDueDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'note': cipher == null ? note : cipher.encryptNullable(note),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static RecurringTransactionModel fromJson(
    Map<String, dynamic> json, {
    required int categoryId,
    FieldCipher? cipher,
  }) {
    final model = RecurringTransactionModel();

    model.remoteId = json['id'] as String?;
    model.title = FieldCipher.readString(cipher, json['title'])!;
    model.type = json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    model.defaultAmount = FieldCipher.readNumber(
      cipher,
      json[recurringDefaultAmountEncryptedColumn] ?? json['default_amount'],
    );
    model.amountType = switch (json['amount_type']) {
      'variable' => RecurringAmountType.variable,
      _ => RecurringAmountType.fixed,
    };
    model.categoryId = categoryId;
    model.accountId = FieldCipher.readString(cipher, json['account_id']);
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
    model.note = FieldCipher.readString(cipher, json['note']);
    model.createdAt = DateTime.parse(json['created_at'] as String);
    model.updatedAt = json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String);

    return model;
  }
}
