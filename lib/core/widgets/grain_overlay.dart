import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Film-grain texture plus an edge vignette. Painted once and cached by the
/// repaint boundary, so it costs almost nothing per frame.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, this.vignette = 0.55, this.grain = 1});

  /// 0 to 1 darkness at the edges.
  final double vignette;

  /// 0 disables grain.
  final double grain;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _GrainPainter(vignette: vignette, grain: grain),
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.vignette, required this.grain});

  final double vignette;
  final double grain;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    if (vignette > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.95,
            colors: [
              Colors.transparent,
              AppColors.midnight.withValues(alpha: vignette),
            ],
            stops: const [0.55, 1],
          ).createShader(rect),
      );
    }

    if (grain > 0) {
      final rng = math.Random(11);
      final count = ((size.width * size.height) / 900).clamp(200, 1600).toInt();
      final pts = Float32List(count * 2);
      for (var i = 0; i < count; i++) {
        pts[i * 2] = rng.nextDouble() * size.width;
        pts[i * 2 + 1] = rng.nextDouble() * size.height;
      }
      canvas.drawRawPoints(
        PointMode.points,
        pts,
        Paint()
          ..color = AppColors.parchment.withValues(alpha: 0.05 * grain)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.vignette != vignette || old.grain != grain;
}
