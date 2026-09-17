import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/crypto_providers.dart';
import '../database/isar_service.dart';
import 'backup_codec.dart';
import 'backup_schedule.dart';
import 'backup_service.dart';

/// Null until encryption is set up: a backup is written with the data key, so
/// there is nothing to write before one exists.
final backupServiceProvider = Provider<BackupService?>((ref) {
  final cipher = ref.watch(fieldCipherProvider);
  if (cipher == null) return null;

  return BackupService(
    isar: IsarService.isar,
    codec: BackupCodec(cipher),
  );
});

/// Kept alive for the life of the app so its in-flight guard actually guards
/// anything — launch and resume can otherwise race.
final backupScheduleProvider = Provider<BackupSchedule?>((ref) {
  final service = ref.watch(backupServiceProvider);
  if (service == null) return null;

  return BackupSchedule(service);
});

/// The newest snapshot on disk and how many there are, for display in Settings.
///
/// Read from the files rather than the schedule's timestamp so a manual backup
/// counts too — the schedule only records its own automatic runs.
final backupStatusProvider = FutureProvider<BackupStatus>((ref) async {
  final service = ref.watch(backupServiceProvider);
  if (service == null) return const BackupStatus(count: 0, newest: null);

  final snapshots = await service.listSnapshots();

  return BackupStatus(
    count: snapshots.length,
    newest: snapshots.isEmpty ? null : await snapshots.first.lastModified(),
  );
});

class BackupStatus {
  const BackupStatus({required this.count, required this.newest});

  final int count;
  final DateTime? newest;
}
