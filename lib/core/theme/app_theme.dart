import 'package:flutter/material.dart';

class AppTheme {
  static ColorScheme subdued(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final neutralSurface = isDark ? const Color(0xFF0E1013) : Colors.white;
    final neutralSurfaceLow = isDark
        ? const Color(0xFF13161A)
        : const Color(0xFFF7F7F8);
    final neutralSurfaceMid = isDark
        ? const Color(0xFF191D22)
        : const Color(0xFFF1F2F4);
    final neutralSurfaceHigh = isDark
        ? const Color(0xFF20252B)
        : const Color(0xFFE9EBEE);
    final onNeutralSurface = isDark
        ? const Color(0xFFF5F7FA)
        : const Color(0xFF111418);
    final onNeutralVariant = isDark
        ? const Color(0xFFB8C0CC)
        : const Color(0xFF5E6875);
    final outline = isDark
        ? const Color(0xFF39424D)
        : const Color(0xFFD6DBE1);
    final outlineVariant = isDark
        ? const Color(0xFF2A313A)
        : const Color(0xFFE6E9ED);

    Color mute(
      Color color, {
      required double saturationFactor,
      required double surfaceBlend,
      double lightnessShift = 0,
    }) {
      final hsl = HSLColor.fromColor(color);
      final toned = hsl
          .withSaturation((hsl.saturation * saturationFactor).clamp(0.0, 1.0))
          .withLightness((hsl.lightness + lightnessShift).clamp(0.0, 1.0))
          .toColor();
      return Color.lerp(toned, neutralSurface, surfaceBlend) ?? toned;
    }

    Color onColorFor(Color background) {
      final brightness = ThemeData.estimateBrightnessForColor(background);
      return brightness == Brightness.dark ? Colors.white : scheme.onSurface;
    }

    final primary = mute(
      scheme.primary,
      saturationFactor: isDark ? 0.42 : 0.28,
      surfaceBlend: isDark ? 0.22 : 0.30,
      lightnessShift: isDark ? 0.04 : -0.02,
    );
    final secondary = mute(
      scheme.secondary,
      saturationFactor: isDark ? 0.34 : 0.22,
      surfaceBlend: isDark ? 0.28 : 0.38,
    );
    final tertiary = mute(
      scheme.tertiary,
      saturationFactor: isDark ? 0.34 : 0.20,
      surfaceBlend: isDark ? 0.30 : 0.40,
    );
    final error = mute(
      scheme.error,
      saturationFactor: isDark ? 0.62 : 0.46,
      surfaceBlend: isDark ? 0.12 : 0.18,
    );

    final primaryContainer = mute(
      scheme.primaryContainer,
      saturationFactor: isDark ? 0.28 : 0.16,
      surfaceBlend: isDark ? 0.58 : 0.78,
    );
    final secondaryContainer = mute(
      scheme.secondaryContainer,
      saturationFactor: isDark ? 0.24 : 0.14,
      surfaceBlend: isDark ? 0.62 : 0.82,
    );
    final tertiaryContainer = mute(
      scheme.tertiaryContainer,
      saturationFactor: isDark ? 0.22 : 0.12,
      surfaceBlend: isDark ? 0.64 : 0.84,
    );
    final errorContainer = mute(
      scheme.errorContainer,
      saturationFactor: isDark ? 0.42 : 0.28,
      surfaceBlend: isDark ? 0.48 : 0.62,
    );

    return scheme.copyWith(
      primary: primary,
      onPrimary: onColorFor(primary),
      secondary: secondary,
      onSecondary: onColorFor(secondary),
      tertiary: tertiary,
      onTertiary: onColorFor(tertiary),
      error: error,
      onError: onColorFor(error),
      primaryContainer: primaryContainer,
      onPrimaryContainer: onColorFor(primaryContainer),
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onColorFor(secondaryContainer),
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onColorFor(tertiaryContainer),
      errorContainer: errorContainer,
      onErrorContainer: onColorFor(errorContainer),
      inversePrimary: mute(
        scheme.inversePrimary,
        saturationFactor: isDark ? 0.44 : 0.28,
        surfaceBlend: isDark ? 0.18 : 0.26,
      ),
      surface: neutralSurface,
      onSurface: onNeutralSurface,
      surfaceDim: neutralSurfaceLow,
      surfaceBright: neutralSurface,
      surfaceContainerLowest: neutralSurface,
      surfaceContainerLow: neutralSurfaceLow,
      surfaceContainer: neutralSurfaceMid,
      surfaceContainerHigh: neutralSurfaceMid,
      surfaceContainerHighest: neutralSurfaceHigh,
      onSurfaceVariant: onNeutralVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      inverseSurface: isDark ? const Color(0xFFF3F5F7) : const Color(0xFF1C2128),
      onInverseSurface: isDark
          ? const Color(0xFF171B20)
          : const Color(0xFFF5F7FA),
    );
  }

  static ThemeData light(ColorScheme scheme) {
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.65);
    final subtleBorderColor = scheme.outlineVariant.withValues(alpha: 0.5);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: subtleBorderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: subtleBorderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.60),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey, width: 1.05),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          side: BorderSide(color: subtleBorderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.surfaceContainerHigh,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark(ColorScheme scheme) {
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.9);
    final subtleBorderColor = scheme.outlineVariant.withValues(alpha: 0.72);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: subtleBorderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.15),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.15),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: borderColor, width: 1.05),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: subtleBorderColor, width: 1.05),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.55),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.15),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.55),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          side: BorderSide(color: subtleBorderColor, width: 1.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.surfaceContainerHigh,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
