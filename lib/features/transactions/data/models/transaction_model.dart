import 'package:isar_community/isar.dart';

import '../../../../core/sync/sync_state.dart';

part 'transaction_model.g.dart';

enum TransactionType { income, expense }

enum TransactionStatus { paid, pending }

@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  String? remoteId;
  String? recurringId;
  int? recurringTemplateId;
  bool? isRecurringInstance;

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

  /// What this record still owes the server. See [SyncState].
  @enumerated
  SyncState syncState = SyncState.synced;

  /// When the record was last written locally. Used to decide who wins when
  /// the same record changed on both sides.
  DateTime? localUpdatedAt;

  /// Consecutive times the server rejected this record. Offline failures do
  /// not count. See [maxSyncAttempts].
  int syncAttempts = 0;

  /// Why the last push failed, kept so the user can see what is stuck.
  String? lastSyncError;
}
