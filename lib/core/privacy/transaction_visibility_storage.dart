import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'transaction_visibility.dart';

class TransactionVisibilityStorage {
  static const _fileName = 'transaction_visibility.json';
  static const _defaultState = TransactionVisibilityState();

  static Future<TransactionVisibilityState> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return _defaultState;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return _defaultState;
      }

      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) {
        return _defaultState;
      }

      final modeName = data['mode']?.toString() ?? _defaultState.mode.name;
      final invisibleSinceRaw = data['invisibleSince']?.toString();

      return TransactionVisibilityState(
        mode: TransactionVisibilityMode.values.byName(modeName),
        invisibleSince: invisibleSinceRaw == null || invisibleSinceRaw.isEmpty
            ? null
            : DateTime.tryParse(invisibleSinceRaw)?.toUtc(),
        hiddenTransactionKeys:
            (data['hiddenTransactionKeys'] as List<dynamic>? ?? const [])
                .map((value) => value.toString())
                .toSet(),
      );
    } catch (_) {
      return _defaultState;
    }
  }

  static Future<void> save(TransactionVisibilityState state) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          'mode': state.mode.name,
          'invisibleSince': state.invisibleSince?.toIso8601String(),
          'hiddenTransactionKeys': state.hiddenTransactionKeys.toList(),
        }),
        flush: true,
      );
    } catch (_) {
      // Ignore persistence errors and keep the in-memory setting.
    }
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }
}
