import 'dart:io';

import 'package:eco/core/database/isar_service.dart';
import 'package:eco/core/network/network_monitor.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/settings/data/models/transaction_preset_model.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:isar_community/isar.dart';

/// Opens a throwaway Isar instance and points [IsarService] at it, so
/// repositories under test hit real storage instead of a mock.
class TestIsar {
  static var _counter = 0;

  static Directory? _directory;
  static Isar? _isar;

  static Future<void> open() async {
    await Isar.initializeIsarCore(download: true);

    final directory = await Directory.systemTemp.createTemp('eco_test');
    final isar = await Isar.open(
      [
        RecurringTransactionModelSchema,
        TransactionModelSchema,
        CategoryModelSchema,
        TransactionPresetModelSchema,
      ],
      directory: directory.path,
      name: 'test_${_counter++}',
    );

    _directory = directory;
    _isar = isar;
    IsarService.isar = isar;
  }

  static Future<void> close() async {
    await _isar?.close(deleteFromDisk: true);
    _isar = null;

    if (_directory != null && await _directory!.exists()) {
      await _directory!.delete(recursive: true);
    }
    _directory = null;
  }
}

/// Puts the shared [NetworkMonitor] into a known state. Repositories consult it
/// to decide whether replication is worth attempting.
void setNetwork({required bool online}) {
  if (online) {
    NetworkMonitor.instance.resetBackoff();
  } else {
    NetworkMonitor.instance.reportFailure();
  }
}

/// Models what the app does when the connection returns: the network comes
/// back *and* the recency window is dropped, so the next read really syncs.
///
/// Pass the repository's `invalidateSyncWindow`, exactly as `syncNow` does.
void reconnect(void Function() invalidateSyncWindow) {
  setNetwork(online: true);
  invalidateSyncWindow();
}
