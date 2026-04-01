import 'package:isar_community/isar.dart';

import '../../../transactions/data/models/transaction_model.dart';

part 'recurring_transaction_model.g.dart';

enum RecurringAmountType { fixed, variable }

enum RecurringIntervalType { daily, weekly, monthly, yearly }

@collection
class RecurringTransactionModel {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late String title;

  @enumerated
  late TransactionType type;

  double? defaultAmount;

  @enumerated
  late RecurringAmountType amountType;

  late int categoryId;

  String? accountId;

  @enumerated
  late RecurringIntervalType intervalType;

  late int intervalCount;

  late DateTime nextDueDate;

  DateTime? endDate;

  late bool isActive;

  String? note;

  late DateTime createdAt;

  DateTime? updatedAt;
}
