import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Theme-level surface tokens that change with high-contrast mode.
@immutable
class ManorTokens extends ThemeExtension<ManorTokens> {
  const ManorTokens({
    required this.highContrast,
    required this.panelFill,
    required this.panelFillStrong,
    required this.panelBorder,
    required this.textPrimary,
    required this.textMuted,
    required this.focus,
  });

  factory ManorTokens.standard() => ManorTokens(
    highContrast: false,
    panelFill: AppColors.navy.withValues(alpha: 0.88),
    panelFillStrong: AppColors.midnight.withValues(alpha: 0.94),
    panelBorder: AppColors.antiqueGold.withValues(alpha: 0.75),
    textPrimary: AppColors.parchment,
    textMuted: AppColors.fog,
    focus: AppColors.moonCyan,
  );

  factory ManorTokens.highContrast() => const ManorTokens(
    highContrast: true,
    panelFill: Color(0xFF000000),
    panelFillStrong: Color(0xFF000000),
    panelBorder: AppColors.goldLight,
    textPrimary: Color(0xFFFFFFFF),
    textMuted: Color(0xFFE6E9FF),
    focus: Color(0xFFFFFFFF),
  );

  final bool highContrast;
  final Color panelFill;
  final Color panelFillStrong;
  final Color panelBorder;
  final Color textPrimary;
  final Color textMuted;
  final Color focus;

  static ManorTokens of(BuildContext context) =>
      Theme.of(context).extension<ManorTokens>() ?? ManorTokens.standard();

  @override
  ManorTokens copyWith({
    bool? highContrast,
    Color? panelFill,
    Color? panelFillStrong,
    Color? panelBorder,
    Color? textPrimary,
    Color? textMuted,
    Color? focus,
  }) => ManorTokens(
    highContrast: highContrast ?? this.highContrast,
    panelFill: panelFill ?? this.panelFill,
    panelFillStrong: panelFillStrong ?? this.panelFillStrong,
    panelBorder: panelBorder ?? this.panelBorder,
    textPrimary: textPrimary ?? this.textPrimary,
    textMuted: textMuted ?? this.textMuted,
    focus: focus ?? this.focus,
  );

  @override
  ManorTokens lerp(ThemeExtension<ManorTokens>? other, double t) {
    if (other is! ManorTokens) return this;
    return ManorTokens(
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      panelFill: Color.lerp(panelFill, other.panelFill, t)!,
      panelFillStrong: Color.lerp(panelFillStrong, other.panelFillStrong, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}
