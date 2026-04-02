import 'transaction_model.dart';

extension TransactionMapper on TransactionModel {
  Map<String, dynamic> toJson(String userId, {bool includeId = false}) {
    final json = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category_id': categoryId,
      'status': status.name,
      'payment_method': paymentMethod,
      'payee': payee,
      'note': note,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'recurring_id': recurringId,
      'recurring_template_id': recurringTemplateId,
      'is_recurring_instance': isRecurringInstance,
    };

    if (includeId && remoteId != null) {
      json['id'] = remoteId;
    }

    return json;
  }

  static TransactionModel fromJson(Map<String, dynamic> json) {
    final transaction = TransactionModel();

    transaction.remoteId = json['id'];
    transaction.recurringId = json['recurring_id'];
    transaction.recurringTemplateId = (json['recurring_template_id'] as num?)
        ?.toInt();
    transaction.isRecurringInstance = json['is_recurring_instance'] as bool?;
    transaction.title = json['title'];
    transaction.amount = (json['amount'] as num).toDouble();
    transaction.date = DateTime.parse(json['date']);
    transaction.type = json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    transaction.status = switch (json['status']) {
      'pending' => TransactionStatus.pending,
      _ => TransactionStatus.paid,
    };
    transaction.categoryId = json['category_id'];
    transaction.paymentMethod = json['payment_method'];
    transaction.payee = json['payee'];
    transaction.note = json['note'];
    transaction.createdAt = DateTime.parse(json['created_at']);
    transaction.updatedAt = json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : null;

    return transaction;
  }
}
