import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Spreads [children] over the full height (first at the top, last at the
/// bottom) when they fit, and scrolls when they do not, for example on short
/// phones or with very large text.
///
/// Uses normal layout only (no intrinsic sizing), so wrapped text is measured
/// at its real width.
class FillOrScroll extends StatelessWidget {
  const FillOrScroll({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        controller: controller,
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, box.maxHeight - padding.vertical),
          ),
          child: Column(
            // With a minimum height, `min` lets the column grow to fill it,
            // and `spaceBetween` spreads the children over that space.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}
