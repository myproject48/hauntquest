import 'package:flutter/widgets.dart';

/// Screen size classes used to adapt layouts.
enum ScreenSize { compact, medium, expanded }

/// Helpers for adapting the UI to different screen sizes.
abstract final class Responsive {
  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return ScreenSize.compact;
    if (width < 1024) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  /// Maximum width for readable content on large screens.
  static const double maxContentWidth = 520;
}
