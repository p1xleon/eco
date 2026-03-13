import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_setting.dart';

class ThemeNotifier extends StateNotifier<ThemeModeSetting> {
  ThemeNotifier() : super(ThemeModeSetting.system);

  void setTheme(ThemeModeSetting mode) {
    state = mode;
  }

  ThemeMode get themeMode {
    switch (state) {
      case ThemeModeSetting.light:
        return ThemeMode.light;
      case ThemeModeSetting.dark:
        return ThemeMode.dark;
      case ThemeModeSetting.system:
        return ThemeMode.system;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeModeSetting>(
  (ref) => ThemeNotifier(),
);
