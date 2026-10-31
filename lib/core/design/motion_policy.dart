import 'package:flutter/widgets.dart';

/// Tells widgets whether to reduce motion. Combines the in-app setting with
/// the operating system accessibility flag.
class MotionPolicy extends InheritedWidget {
  const MotionPolicy({
    super.key,
    required this.reduceMotion,
    required super.child,
  });

  /// The in-app "reduced motion" setting.
  final bool reduceMotion;

  /// True when motion should be minimal: continuous animation off, transitions
  /// instant or very short.
  static bool reduceOf(BuildContext context) {
    final policy = context.dependOnInheritedWidgetOfExactType<MotionPolicy>();
    return (policy?.reduceMotion ?? false) ||
        MediaQuery.disableAnimationsOf(context);
  }

  @override
  bool updateShouldNotify(MotionPolicy oldWidget) =>
      oldWidget.reduceMotion != reduceMotion;
}
