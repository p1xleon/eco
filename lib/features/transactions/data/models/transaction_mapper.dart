import 'transaction_model.dart';

/// Column holding the category's server-side uuid.
///
/// The legacy `category_id` column holds the *device-local* Isar id, which only
/// means anything on the device that wrote it. Both are sent so a client
/// running the old code keeps working; readers prefer this one.
const transactionCategoryRemoteIdColumn = 'category_remote_id';

extension TransactionMapper on TransactionModel {
  Map<String, dynamic> toJson(
    String userId, {
    bool includeId = false,
    String? categoryRemoteId,
  }) {
    final json = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category_id': categoryId,
      transactionCategoryRemoteIdColumn: categoryRemoteId,
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

  /// Builds the local record from a server row.
  ///
  /// [categoryId] is resolved by the caller, which is the only place that can
  /// map the server's category uuid onto a local category. It falls back to the
  /// legacy integer column, so rows written before the uuid column existed keep
  /// working exactly as they did.
  static TransactionModel fromJson(Map<String, dynamic> json, {int? categoryId}) {
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
    transaction.categoryId = categoryId ?? (json['category_id'] as num).toInt();
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
