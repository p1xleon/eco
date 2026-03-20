import 'package:isar_community/isar.dart';

part 'transaction_model.g.dart';

enum TransactionType { income, expense }

enum TransactionStatus { paid, pending }

@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  String? remoteId;
  String? recurringId;

  late String title;

  late double amount;

  late DateTime date;

  @enumerated
  late TransactionType type;

  @enumerated
  TransactionStatus status = TransactionStatus.paid;

  late int categoryId;

  String? paymentMethod;

  String? payee;

  String? note;

  late DateTime createdAt;

  DateTime? updatedAt;
}
