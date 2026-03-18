import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_setting.dart';

class ThemeNotifier extends StateNotifier<ThemeModeSetting> {
  ThemeNotifier() : super(ThemeModeSetting.system);

  void setTheme(ThemeModeSetting mode) {
    state = mode;
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
