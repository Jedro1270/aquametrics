import 'package:flutter/material.dart';

/// Design tokens for AquaMetrics.
///
/// Direction: bright field-work. A near-white shell keeps the screen legible in
/// direct sun, deep teal carries structure, and a single safety-orange accent is
/// reserved for the one action that matters so it stays findable with wet hands.
class AppColors {
  const AppColors._();

  static const shell = Color(0xFFF1F4F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunk = Color(0xFFE7ECEA);
  static const line = Color(0xFFD8E0DE);

  static const ink = Color(0xFF0A1A18);
  static const inkSoft = Color(0xFF5A6D6A);
  static const inkFaint = Color(0xFF8A9997);

  static const teal = Color(0xFF0D5C55);
  static const tealDeep = Color(0xFF08403B);
  static const tealSoft = Color(0xFFDCEFEB);

  /// Reserved for the primary action only. Never decorative.
  static const hiVis = Color(0xFFFF7A1A);
  static const hiVisEdge = Color(0xFFC85B00);
  static const hiVisInk = Color(0xFF241000);

  static const good = Color(0xFF157F52);
  static const warn = Color(0xFFB4470E);

  static const water = Color(0xFF0B1614);
}

class AppRadius {
  const AppRadius._();

  static const card = 18.0;
  static const button = 16.0;
  static const thumb = 12.0;
}

class AppTheme {
  const AppTheme._();

  static const _figures = <FontFeature>[FontFeature.tabularFigures()];

  static const _text = TextTheme(
    displayLarge: TextStyle(
      fontSize: 62,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: -2.6,
      fontFeatures: _figures,
    ),
    displayMedium: TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: -1.6,
      fontFeatures: _figures,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: -0.8,
      fontFeatures: _figures,
    ),
    headlineMedium: TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 15, height: 1.42),
    bodyMedium: TextStyle(fontSize: 13.5, height: 1.4),
    bodySmall: TextStyle(fontSize: 12.5, height: 1.35),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    // Small all-caps eyebrow label used above sections and stats.
    labelMedium: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
    ),
  );

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      primaryContainer: AppColors.tealSoft,
      onPrimaryContainer: AppColors.tealDeep,
      secondary: AppColors.hiVis,
      onSecondary: Color(0xFF241000),
      error: AppColors.warn,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.shell,
      textTheme: _text.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.tealSoft,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.inkFaint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.inkFaint,
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.teal,
        inactiveTrackColor: AppColors.surfaceSunk,
        thumbColor: AppColors.teal,
        overlayColor: Color(0x1A0D5C55),
        trackHeight: 6,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
