import 'package:isar_community/isar.dart';

part 'transaction_model.g.dart';

enum TransactionType { income, expense }

@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late String title;

  late double amount;

  late DateTime date;

  @enumerated
  late TransactionType type;

  late int categoryId;

  String? paymentMethod;

  String? payee;

  String? note;

  late DateTime createdAt;
}
