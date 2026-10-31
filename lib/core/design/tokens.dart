import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Spacing scale (multiples of 4 dp).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
}

/// Durations and curves shared by all animation.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration page = Duration(milliseconds: 420);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// Soft colored light used for discoveries and focus.
abstract final class AppGlow {
  static List<BoxShadow> gold([double strength = 1]) => [
    BoxShadow(
      color: AppColors.antiqueGold.withValues(alpha: 0.32 * strength),
      blurRadius: 18,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> cyan([double strength = 1]) => [
    BoxShadow(
      color: AppColors.moonCyan.withValues(alpha: 0.28 * strength),
      blurRadius: 20,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> depth() => const [
    BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

/// Layout limits.
abstract final class AppLayout {
  /// Maximum width of reading panels and forms on large screens.
  static const double contentMaxWidth = 560;

  /// Width of the side panel in landscape/tablet room view.
  static const double sidePanelWidth = 360;

  /// Minimum touch target.
  static const double minTouch = 48;
}
