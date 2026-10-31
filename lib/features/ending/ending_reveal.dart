import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/motion_policy.dart';
import '../../core/theme/app_colors.dart';

/// A finite, skippable ceremony. Reduced motion renders the settled scene
/// immediately; the reveal never changes or awards narrative state.
class EndingReveal extends StatefulWidget {
  const EndingReveal({super.key, required this.style, required this.child});
  final String style;
  final Widget child;
  @override
  State<EndingReveal> createState() => EndingRevealState();
}

class EndingRevealState extends State<EndingReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  bool get isComplete => _reveal.isCompleted;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceOf(context)) {
      _reveal.value = 1;
    } else if (_reveal.isDismissed) {
      _reveal.forward();
    }
  }

  void complete() => _reveal.value = 1;
  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _reveal,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: ExcludeSemantics(
            child: CustomPaint(
              key: ValueKey('ending-reveal-${widget.style}'),
              painter: _RevealPainter(widget.style, _reveal.value),
            ),
          ),
        ),
        if (!isComplete)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.tonalIcon(
                  onPressed: complete,
                  icon: const Icon(Icons.fast_forward),
                  label: const Text('Skip reveal'),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _RevealPainter extends CustomPainter {
  const _RevealPainter(this.style, this.progress);
  final String style;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress >= 1) return;
    final p = Curves.easeInOutCubic.transform(progress);
    final center = Offset(size.width * .5, size.height * .36);
    final unit = math.min(size.width, size.height) * .28;
    final fade = math.sin(math.pi * progress);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.midnight.withValues(alpha: .85 * (1 - p)),
    );
    final gold = Paint()
      ..color = AppColors.goldLight.withValues(alpha: fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (style == 'release') {
      // The final ring opens, then remembered voices rise into the dawn.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: unit * (.4 + p * 1.8)),
        -math.pi / 2,
        math.pi * 2 * (1 - p),
        false,
        gold,
      );
      for (var i = 0; i < 42; i++) {
        final a = i * 2.3999632297 + p * 2;
        final distance = unit * (.2 + (i % 7) / 7);
        final point =
            center +
            Offset(
              math.cos(a) * distance * (1 + p),
              math.sin(a) * distance - p * size.height * .65,
            );
        canvas.drawCircle(
          point,
          1.5 + (i % 3),
          Paint()..color = AppColors.paper.withValues(alpha: fade * .85),
        );
      }
    } else if (style == 'seal') {
      // Five rings draw inward and close their gaps around a quiet core.
      for (var i = 0; i < 5; i++) {
        final r = unit * (1.7 - p + i * .12);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          i * .7 + (i.isEven ? 1 : -1) * (1 - p) * math.pi,
          math.pi * 2 * (.15 + .85 * p),
          false,
          gold,
        );
      }
      canvas.drawCircle(
        center,
        unit * .12,
        Paint()..color = AppColors.moonCyan.withValues(alpha: fade),
      );
    } else {
      // Two independent lights approach, keeping their own orbits inside a
      // shared arch: guardianship by mutual consent rather than a binding.
      final arch = Path()
        ..moveTo(center.dx - unit, center.dy + unit)
        ..lineTo(center.dx - unit, center.dy)
        ..cubicTo(
          center.dx - unit,
          center.dy - unit * 1.4,
          center.dx + unit,
          center.dy - unit * 1.4,
          center.dx + unit,
          center.dy,
        )
        ..lineTo(center.dx + unit, center.dy + unit);
      final metric = arch.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * p), gold);
      for (var side = -1; side <= 1; side += 2) {
        final point =
            center +
            Offset(
              side * unit * (1 - .6 * p),
              math.sin(p * math.pi * 2) * unit * .3 * side,
            );
        canvas.drawCircle(
          point,
          unit * .12,
          Paint()
            ..color = (side == 1 ? AppColors.goldLight : AppColors.moonCyan)
                .withValues(alpha: fade),
        );
        canvas.drawCircle(point, unit * (.18 + .08 * p), gold);
      }
    }
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.style != style || old.progress != progress;
}
