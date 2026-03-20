import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'theme_mode_setting.dart';

class ThemeStorage {
  static const _fileName = 'theme_mode.json';
  static const _defaultMode = ThemeModeSetting.system;

  static Future<ThemeModeSetting> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return _defaultMode;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return _defaultMode;

      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return _defaultMode;

      return ThemeModeSetting.values.byName(
        data['themeMode']?.toString() ?? _defaultMode.name,
      );
    } catch (_) {
      return _defaultMode;
    }
  }

  static Future<void> save(ThemeModeSetting mode) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({'themeMode': mode.name}),
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
