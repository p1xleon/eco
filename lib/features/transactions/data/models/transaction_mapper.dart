import 'transaction_model.dart';

extension TransactionMapper on TransactionModel {
  Map<String, dynamic> toJson(String userId) {
    final json = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category_id': categoryId,
      'payment_method': paymentMethod,
      'payee': payee,
      'note': note,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };

    if (remoteId != null) {
      json['id'] = remoteId;
    }

    return json;
  }

  static TransactionModel fromJson(Map<String, dynamic> json) {
    final transaction = TransactionModel();

    transaction.remoteId = json['id'];
    transaction.title = json['title'];
    transaction.amount = (json['amount'] as num).toDouble();
    transaction.date = DateTime.parse(json['date']);
    transaction.type = json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    transaction.categoryId = json['category_id'];
    transaction.paymentMethod = json['payment_method'];
    transaction.payee = json['payee'];
    transaction.note = json['note'];
    transaction.createdAt = DateTime.parse(json['created_at']);

    return transaction;
  }
}
