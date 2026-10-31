import 'package:flutter/material.dart';

import '../design/motion_policy.dart';
import '../design/tokens.dart';

/// Page transition: the new screen fades in out of the dark with a slight
/// settle. Instant when motion is reduced.
class MistPageRoute<T> extends PageRouteBuilder<T> {
  MistPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: AppMotion.page,
        reverseTransitionDuration: AppMotion.medium,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          if (MotionPolicy.reduceOf(context)) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.emphasized,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.985, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Convenience navigation helpers using [MistPageRoute].
extension MistNavigation on BuildContext {
  Future<T?> pushMist<T>(Widget screen) =>
      Navigator.of(this).push<T>(MistPageRoute<T>(builder: (_) => screen));

  Future<T?> pushReplacementMist<T>(Widget screen) =>
      Navigator.of(this)
          .pushReplacement<T, void>(MistPageRoute<T>(builder: (_) => screen));
}
