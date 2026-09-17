import 'dart:io';
import 'dart:typed_data';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/categories/data/models/category_model.dart';
import '../../features/recurring/data/models/recurring_transaction_model.dart';
import '../../features/settings/data/models/transaction_preset_model.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../sync/sync_state.dart';
import 'backup_codec.dart';

/// Writes and restores encrypted snapshots of the local database.
///
/// Automatic backups live inside the app's own documents directory. That is
/// deliberate: no storage permission, no picker, and they are readable over
/// `adb run-as` on a debuggable build — the route that recovered this app's
/// data once already. They do not survive an uninstall, which is why the manual
/// backup goes through the share sheet instead.
class BackupService {
  BackupService({required Isar isar, required BackupCodec codec})
      : _isar = isar,
        _codec = codec;

  static const fileExtension = '.ecobak';
  static const directoryName = 'backups';

  /// How many automatic backups to keep. Enough to outlast a bad change that
  /// goes unnoticed for a few days, without unbounded growth.
  static const keepCount = 7;

  final Isar _isar;
  final BackupCodec _codec;

  /// The current database, encrypted and ready to write or share.
  Future<Uint8List> create() async {
    final payload = BackupPayload(
      createdAt: DateTime.now(),
      transactions: await _isar.transactionModels.where().findAll(),
      categories: await _isar.categoryModels.where().findAll(),
      recurring: await _isar.recurringTransactionModels.where().findAll(),
      presets: await _isar.transactionPresetModels.where().findAll(),
    );

    return _codec.encode(payload);
  }

  /// Writes a dated snapshot and prunes older ones.
  Future<File> writeSnapshot() async {
    final directory = await _directory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);

    final file = File('${directory.path}/eco-$stamp$fileExtension');
    await file.writeAsBytes(await create(), flush: true);

    await _prune();

    return file;
  }

  /// Existing snapshots, newest first.
  Future<List<File>> listSnapshots() async {
    final directory = await _directory();

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith(fileExtension))
        .toList();

    // The timestamp is in the name and sorts lexicographically, so this needs
    // no stat call per file.
    files.sort((a, b) => b.path.compareTo(a.path));

    return files;
  }

  Future<BackupPayload> read(List<int> bytes) async => _codec.decode(bytes);

  /// Replaces the local database with [payload] and queues all of it for
  /// upload.
  ///
  /// Every record comes back as a pending create with no `remoteId`: a restore
  /// is for the case where the server copy is gone, and re-uploading as new
  /// rows is exactly the recovery that had to be done by hand when this
  /// project's backend was deleted. The caller is expected to have confirmed
  /// with the user first — against a server that still holds the data, this
  /// produces duplicates rather than merging.
  ///
  /// Retry budgets are not restored. A record that was blocked when the backup
  /// was taken gets a fresh start, which is what the user would want after
  /// rebuilding a backend.
  Future<void> restore(BackupPayload payload) async {
    for (final item in payload.transactions) {
      item.remoteId = null;
      item.syncState = SyncState.pendingCreate;
      item.syncAttempts = 0;
      item.lastSyncError = null;
    }
    for (final item in payload.categories) {
      item.remoteId = null;
      item.syncState = SyncState.pendingCreate;
      item.syncAttempts = 0;
      item.lastSyncError = null;
    }
    for (final item in payload.recurring) {
      item.remoteId = null;
      item.syncState = SyncState.pendingCreate;
      item.syncAttempts = 0;
      item.lastSyncError = null;
    }

    await _isar.writeTxn(() async {
      await _isar.transactionModels.clear();
      await _isar.categoryModels.clear();
      await _isar.recurringTransactionModels.clear();
      await _isar.transactionPresetModels.clear();

      await _isar.transactionModels.putAll(payload.transactions);
      await _isar.categoryModels.putAll(payload.categories);
      await _isar.recurringTransactionModels.putAll(payload.recurring);
      await _isar.transactionPresetModels.putAll(payload.presets);
    });
  }

  Future<void> _prune() async {
    final snapshots = await listSnapshots();

    for (final file in snapshots.skip(keepCount)) {
      try {
        await file.delete();
      } catch (_) {
        // A snapshot that cannot be deleted is not worth failing a backup over.
      }
    }
  }

  Future<Directory> _directory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/$directoryName');

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }
}
