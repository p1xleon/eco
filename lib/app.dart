import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'core/auth/auth_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class Eco extends ConsumerWidget {
  const Eco({super.key});

  static const _fallbackSeed = Color.fromARGB(255, 255, 255, 255);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSetting = ref.watch(themeProvider);
    final themeMode = ref
        .read(themeProvider.notifier)
        .themeModeFor(themeSetting);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = AppTheme.subdued(
          lightDynamic ?? ColorScheme.fromSeed(seedColor: _fallbackSeed),
        );

        final darkScheme = AppTheme.subdued(
          darkDynamic ??
              ColorScheme.fromSeed(
                seedColor: _fallbackSeed,
                brightness: Brightness.dark,
              ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Finance Tracker",
          theme: AppTheme.light(lightScheme),
          darkTheme: AppTheme.dark(darkScheme),
          themeMode: themeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}
