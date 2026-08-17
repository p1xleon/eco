import 'package:isar_community/isar.dart';

import '../../../../core/sync/sync_state.dart';

part 'category_model.g.dart';

enum CategoryType { income, expense }

@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late String name;

  @enumerated
  late CategoryType type;

  late int color;

  String? icon;

  /// What this record still owes the server. See [SyncState].
  @enumerated
  SyncState syncState = SyncState.synced;

  DateTime? localUpdatedAt;

  /// Consecutive times the server rejected this record. See [maxSyncAttempts].
  int syncAttempts = 0;

  String? lastSyncError;
}
