import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/definitions/room_def.dart';
import '../theme/app_colors.dart';

/// Shared helpers for the code-drawn art.
abstract final class Kit {
  static Paint fill(Color c) => Paint()..color = c;

  static Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Soft radial light.
  static void glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, [
    double opacity = 0.5,
  ]) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  static void vGradient(
    Canvas canvas,
    Rect r,
    List<Color> colors, [
    List<double>? stops,
  ]) {
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(r),
    );
  }

  static void rrect(Canvas canvas, Rect r, double radius, Paint paint) => canvas
      .drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), paint);

  static Rect rectOf(HotspotArea a, Size s) => Rect.fromLTWH(
    a.x * s.width,
    a.y * s.height,
    a.w * s.width,
    a.h * s.height,
  );

  /// A translucent shaft of light from a narrow top edge to a wider bottom.
  static void lightShaft(
    Canvas canvas,
    Offset top,
    double topWidth,
    Offset bottom,
    double bottomWidth,
    Color color,
    double opacity,
  ) {
    final path = Path()
      ..moveTo(top.dx - topWidth / 2, top.dy)
      ..lineTo(top.dx + topWidth / 2, top.dy)
      ..lineTo(bottom.dx + bottomWidth / 2, bottom.dy)
      ..lineTo(bottom.dx - bottomWidth / 2, bottom.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromPoints(top, bottom)),
    );
  }

  /// Draws centered text, used for engraved letters and numerals.
  static void text(
    Canvas canvas,
    String s,
    Offset center,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontFamilyFallback: const ['Times New Roman', 'serif'],
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Regular polygon or star path.
  static Path ngon(
    Offset c,
    double r,
    int n, {
    double rotation = 0,
    double inner = 1,
  }) {
    final path = Path();
    final points = inner == 1 ? n : n * 2;
    for (var i = 0; i < points; i++) {
      final radius = inner == 1 ? r : (i.isEven ? r : r * inner);
      final a = rotation + i * 2 * math.pi / points;
      final p = Offset(
        c.dx + radius * math.cos(a),
        c.dy + radius * math.sin(a),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// A toothed gear outline.
  static Path gear(
    Offset c,
    double r,
    int teeth, {
    double rotation = 0,
    double depth = 0.18,
  }) {
    final path = Path();
    final step = 2 * math.pi / teeth;
    for (var i = 0; i < teeth; i++) {
      final a = rotation + i * step;
      final o = r;
      final inn = r * (1 - depth);
      Offset at(double ang, double rad) =>
          Offset(c.dx + rad * math.cos(ang), c.dy + rad * math.sin(ang));
      final pts = [
        at(a - step * 0.30, inn),
        at(a - step * 0.18, o),
        at(a + step * 0.18, o),
        at(a + step * 0.30, inn),
      ];
      if (i == 0) {
        path.moveTo(pts[0].dx, pts[0].dy);
      } else {
        path.lineTo(pts[0].dx, pts[0].dy);
      }
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  /// Deterministic pseudo-random value in [0, 1).
  static double rand(int seed) {
    final x = math.sin(seed * 12.9898) * 43758.5453;
    return x - x.floor();
  }

  /// Brass-like vertical gradient shader.
  static Paint brassPaint(Rect r) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [AppColors.goldLight, AppColors.brass, AppColors.brassDark],
    ).createShader(r);

  static Paint woodPaint(Rect r) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [AppColors.woodLight, AppColors.wood],
    ).createShader(r);
}
