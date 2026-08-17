/// Replication state of a locally stored record.
///
/// Isar is the source of truth: every write commits locally first and is
/// replicated afterwards. This enum is what lets a record remember that it
/// still owes the server a change.
///
/// `synced` is index 0 so records written before this field existed default to
/// it. [SyncBackfill] repairs the ones that were really pending creates.
enum SyncState {
  /// Local copy matches the server.
  synced,

  /// Created locally, never pushed. Has no `remoteId` yet.
  pendingCreate,

  /// Exists on the server but was edited locally since.
  pendingUpdate,

  /// Deleted locally, still present on the server. Hidden from every query
  /// and purged once the server confirms the delete.
  pendingDelete,
}

extension SyncStateX on SyncState {
  bool get isPending => this != SyncState.synced;

  /// True while the record is still visible to the user.
  bool get isVisible => this != SyncState.pendingDelete;
}

/// How many times a record may be rejected by the server before automatic
/// retries stop.
///
/// Only counts rejections — a record that could not be pushed because the
/// device was offline has not done anything wrong and keeps its budget. Without
/// this cap a permanently invalid record is retried on every read, forever.
const maxSyncAttempts = 5;

/// Whether automatic replication has given up on a record. The user can still
/// force a retry from Settings.
bool isSyncBlocked(int syncAttempts) => syncAttempts >= maxSyncAttempts;

/// Trimmed to something a snackbar or list tile can show.
String describeSyncError(Object error) {
  final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 200) return text;

  return '${text.substring(0, 199)}…';
}

