import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup_service.dart';

/// Decides when an automatic backup is due, and makes sure only one runs.
///
/// There is no background scheduler in this app, so backups ride the app
/// lifecycle: launch and resume, at most once a day. On a local-first database
/// that is enough — nothing is lost between runs, because the device itself is
/// still holding every record.
///
/// The in-flight guard is the same idea as [SyncGate], but the "already done
/// recently" part has to survive a process restart, so the timestamp goes to a
/// file rather than memory. Persisted the same way as `theme_storage.dart`.
class BackupSchedule {
  BackupSchedule(this._service, {this.interval = const Duration(days: 1)});

  static const _fileName = 'last_backup.json';

  final BackupService _service;
  final Duration interval;

  Future<void>? _inFlight;

  /// Backs up if enough time has passed. Returns the file when one was written.
  ///
  /// Never throws: a failed backup must not take the app down with it, and the
  /// next launch will try again. The timestamp is only recorded on success, so
  /// a failure does not count as a backup having happened.
  Future<File?> runIfDue() async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      await inFlight;
      return null;
    }

    if (!await isDue()) return null;

    File? written;
    final future = () async {
      written = await _service.writeSnapshot();
      await _markRun(DateTime.now());
    }();

    _inFlight = future;

    try {
      await future;
    } catch (_) {
      // Swallowed deliberately; see above.
    } finally {
      _inFlight = null;
    }

    return written;
  }

  Future<bool> isDue() async {
    final last = await lastRun();
    if (last == null) return true;

    return DateTime.now().difference(last) >= interval;
  }

  Future<DateTime?> lastRun() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;

      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;

      final value = data['lastBackupAt'];
      return value is String ? DateTime.tryParse(value) : null;
    } catch (_) {
      // An unreadable timestamp means "back up now", which is the safe way to
      // be wrong.
      return null;
    }
  }

  Future<void> _markRun(DateTime at) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({'lastBackupAt': at.toIso8601String()}),
        flush: true,
      );
    } catch (_) {
      // Worst case the next launch backs up again.
    }
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }
}
