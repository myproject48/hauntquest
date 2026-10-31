import 'package:flutter/material.dart';

import '../design/manor_tokens.dart';
import 'app_colors.dart';

/// Builds the custom dark-fantasy [ThemeData] used across the game.
///
/// Typography: a bundled-free serif stack (Georgia, falling back to the
/// platform serif) for a storybook feel. Small text never drops below 14 sp.
abstract final class AppTheme {
  static const String _serif = 'Georgia';
  static const List<String> _serifFallback = ['Times New Roman', 'serif'];

  /// Standard dark theme.
  static ThemeData dark() => build();

  /// [highContrast] raises text and border contrast; [spacedText] adds letter
  /// and line spacing for easier reading.
  static ThemeData build({bool highContrast = false, bool spacedText = false}) {
    final tokens = highContrast
        ? ManorTokens.highContrast()
        : ManorTokens.standard();

    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: highContrast ? Colors.white : AppColors.moonCyan,
      onPrimary: AppColors.midnight,
      secondary: AppColors.ghostGreen,
      onSecondary: AppColors.midnight,
      tertiary: highContrast ? AppColors.goldLight : AppColors.antiqueGold,
      onTertiary: AppColors.midnight,
      error: AppColors.danger,
      onError: AppColors.midnight,
      surface: highContrast ? Colors.black : AppColors.navy,
      onSurface: tokens.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.midnight,
      fontFamily: _serif,
      fontFamilyFallback: _serifFallback,
    );

    final extraLetter = spacedText ? 0.6 : 0.0;
    final lineHeight = spacedText ? 1.75 : 1.5;

    TextStyle style(
      double size,
      FontWeight weight, {
      double letter = 0,
      double? height,
      Color? color,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letter + extraLetter,
      height: height ?? lineHeight,
      color: color ?? tokens.textPrimary,
    );

    final text = base.textTheme
        .apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary)
        .copyWith(
          // Title wordmark.
          displayLarge: style(44, FontWeight.w700, letter: 3, height: 1.1),
          // Screen titles.
          headlineMedium: style(28, FontWeight.w700, letter: 1.2, height: 1.2),
          headlineSmall: style(22, FontWeight.w600, letter: 0.8, height: 1.25),
          titleLarge: style(20, FontWeight.w600, letter: 0.8, height: 1.3),
          titleMedium: style(17, FontWeight.w600, letter: 0.4, height: 1.35),
          // Reading text.
          bodyLarge: style(17, FontWeight.w400),
          bodyMedium: style(16, FontWeight.w400),
          // Small text: never below 14 sp.
          bodySmall: style(14, FontWeight.w400, color: tokens.textMuted),
          labelLarge: style(16, FontWeight.w700, letter: 2),
          labelMedium: style(14, FontWeight.w600, letter: 1.2),
          labelSmall: style(
            14,
            FontWeight.w600,
            letter: 1.0,
            color: tokens.textMuted,
          ),
        )
        // The replacement styles above start without a font, so the serif
        // stack must be applied to every style again.
        .apply(fontFamily: _serif, fontFamilyFallback: _serifFallback);

    return base.copyWith(
      textTheme: text,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: tokens.textPrimary,
      ),
      dividerColor: tokens.panelBorder.withValues(alpha: 0.5),
      focusColor: tokens.focus.withValues(alpha: 0.35),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.antiqueGold,
        inactiveTrackColor: AppColors.deepNavy,
        thumbColor: AppColors.goldLight,
        overlayColor: AppColors.antiqueGold.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.goldLight
              : tokens.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.goldDeep
              : AppColors.deepNavy,
        ),
        trackOutlineColor: WidgetStateProperty.all(tokens.panelBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.deepNavy,
        contentTextStyle: TextStyle(color: tokens.textPrimary, fontSize: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.panelBorder),
        ),
      ),
    );
  }
}
