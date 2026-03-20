import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_setting.dart';
import 'theme_storage.dart';

class ThemeNotifier extends StateNotifier<ThemeModeSetting> {
  ThemeNotifier([super.state = ThemeModeSetting.system]);

  void setTheme(ThemeModeSetting mode) {
    if (state == mode) return;
    state = mode;
    ThemeStorage.save(mode);
  }

  ThemeMode themeModeFor(ThemeModeSetting setting) {
    switch (setting) {
      case ThemeModeSetting.light:
        return ThemeMode.light;
      case ThemeModeSetting.dark:
        return ThemeMode.dark;
      case ThemeModeSetting.system:
        return ThemeMode.system;
    }
  }

  ThemeMode get themeMode => themeModeFor(state);
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeModeSetting>(
  (ref) => ThemeNotifier(),
);
