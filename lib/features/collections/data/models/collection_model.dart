import 'package:isar_community/isar.dart';

import '../../../../core/sync/sync_state.dart';

part 'collection_model.g.dart';

/// A user-named group of transactions, such as a trip or a renovation. A
/// grouping only: its transactions still count everywhere else.
@collection
class CollectionModel {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late String name;

  late int color;

  String? icon;

  /// When true, its transactions are tracked only here, not in the main
  /// transactions list, dashboard or analytics.
  bool separate = false;

  /// What this record still owes the server. See [SyncState].
  @enumerated
  SyncState syncState = SyncState.synced;

  DateTime? localUpdatedAt;

  /// Consecutive times the server rejected this record. See [maxSyncAttempts].
  int syncAttempts = 0;

  String? lastSyncError;
}
