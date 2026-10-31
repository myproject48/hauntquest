import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/motion_policy.dart';
import '../theme/app_colors.dart';

/// Soft drifting fog built from a few large radial gradients. Cheap, with no
/// blur filters. Static when motion is reduced.
class FogLayer extends StatefulWidget {
  const FogLayer({
    super.key,
    this.color = AppColors.moonCyan,
    this.density = 1,
    this.speed = 1,
    this.seed = 1,
    this.verticalBias = 0.6,
  });

  final Color color;

  /// 0 to about 2. Higher is thicker.
  final double density;
  final double speed;
  final int seed;

  /// Vertical center of the fog band, 0 (top) to 1 (bottom).
  final double verticalBias;

  @override
  State<FogLayer> createState() => _FogLayerState();
}

class _FogLayerState extends State<FogLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _FogPainter(
              repaint: _controller,
              color: widget.color,
              density: widget.density,
              speed: widget.speed,
              seed: widget.seed,
              bias: widget.verticalBias,
            ),
          ),
        ),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  _FogPainter({
    required Animation<double> repaint,
    required this.color,
    required this.density,
    required this.speed,
    required this.seed,
    required this.bias,
  }) : _t = repaint,
       super(repaint: repaint);

  final Animation<double> _t;
  final Color color;
  final double density;
  final double speed;
  final int seed;
  final double bias;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = _t.value;
    const blobs = 6;
    for (var i = 0; i < blobs; i++) {
      final phase = (seed * 0.37 + i * 0.23) % 1.0;
      final drift = (phase + t * speed * (1 + (i % 3) * 0.6)) % 1.0;
      final cx = size.width * (drift * 1.5 - 0.25);
      final cy =
          size.height *
          (bias +
              0.09 * math.sin(i * 1.7 + seed) +
              0.04 * math.sin(t * 2 * math.pi + i));
      final rx = size.width * (0.45 + 0.1 * (i % 3));
      final ry = rx * 0.28;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(1, ry / rx);
      canvas.drawCircle(
        Offset.zero,
        rx,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: (0.16 * density).clamp(0, 0.5)),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FogPainter old) =>
      old.color != color ||
      old.density != density ||
      old.seed != seed ||
      old.bias != bias;
}
