import 'package:isar_community/isar.dart';

import '../../../../core/sync/sync_state.dart';
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

  /// What this record still owes the server. See [SyncState].
  @enumerated
  SyncState syncState = SyncState.synced;

  DateTime? localUpdatedAt;

  /// Consecutive times the server rejected this record. See [maxSyncAttempts].
  int syncAttempts = 0;

  String? lastSyncError;
}
