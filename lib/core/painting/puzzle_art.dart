import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'paint_kit.dart';

/// Symbols used by sequence puzzles: four moon phases and four elemental
/// pillars. Unknown ids fall back to a plain diamond.
abstract final class Sigils {
  static const Set<String> supported = {
    'crescent',
    'half',
    'full',
    'waning',
    'tide',
    'ember',
    'gale',
    'stone',
  };

  static void paint(Canvas canvas, String id, Rect r, Color color) {
    final c = r.center;
    final u = r.shortestSide / 2;
    final fill = Kit.fill(color);
    switch (id) {
      case 'crescent':
        _crescent(canvas, c, u, color, flip: false);
      case 'waning':
        _crescent(canvas, c, u, color, flip: true);
      case 'half':
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: u * 0.85),
          -math.pi / 2,
          math.pi,
          true,
          fill,
        );
        canvas.drawCircle(c, u * 0.85, Kit.stroke(color, u * 0.08));
      case 'full':
        Kit.glow(canvas, c, u * 1.4, color, 0.4);
        canvas.drawCircle(c, u * 0.8, fill);
        canvas.drawCircle(
          c.translate(-u * 0.2, -u * 0.15),
          u * 0.14,
          Kit.fill(Colors.black.withValues(alpha: 0.15)),
        );
        canvas.drawCircle(
          c.translate(u * 0.25, u * 0.2),
          u * 0.18,
          Kit.fill(Colors.black.withValues(alpha: 0.12)),
        );
      case 'tide':
        for (var i = 0; i < 3; i++) {
          final y = c.dy + (i - 1) * u * 0.5;
          final p = Path()..moveTo(c.dx - u * 0.85, y);
          for (var k = 0; k < 2; k++) {
            final x0 = c.dx - u * 0.85 + k * u * 0.85;
            p.quadraticBezierTo(x0 + u * 0.21, y - u * 0.32, x0 + u * 0.425, y);
            p.quadraticBezierTo(x0 + u * 0.64, y + u * 0.32, x0 + u * 0.85, y);
          }
          canvas.drawPath(p, Kit.stroke(color, u * 0.14));
        }
      case 'ember':
        final flame = Path()
          ..moveTo(c.dx, c.dy - u * 0.95)
          ..quadraticBezierTo(
            c.dx + u * 0.2,
            c.dy - u * 0.4,
            c.dx + u * 0.6,
            c.dy + u * 0.1,
          )
          ..quadraticBezierTo(
            c.dx + u * 0.8,
            c.dy + u * 0.9,
            c.dx,
            c.dy + u * 0.9,
          )
          ..quadraticBezierTo(
            c.dx - u * 0.8,
            c.dy + u * 0.9,
            c.dx - u * 0.6,
            c.dy + u * 0.1,
          )
          ..quadraticBezierTo(
            c.dx - u * 0.35,
            c.dy - u * 0.2,
            c.dx,
            c.dy - u * 0.95,
          )
          ..close();
        canvas.drawPath(flame, fill);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..quadraticBezierTo(
              c.dx + u * 0.3,
              c.dy + u * 0.35,
              c.dx,
              c.dy + u * 0.75,
            )
            ..quadraticBezierTo(c.dx - u * 0.3, c.dy + u * 0.35, c.dx, c.dy)
            ..close(),
          Kit.fill(Colors.white.withValues(alpha: 0.55)),
        );
      case 'gale':
        final p = Path();
        for (var i = 0; i <= 40; i++) {
          final a = i * 0.28;
          final rr = u * 0.1 + i * u * 0.02;
          final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(p, Kit.stroke(color, u * 0.13));
      case 'stone':
        final p = Kit.ngon(c, u * 0.9, 6, rotation: math.pi / 6);
        canvas.drawPath(p, fill);
        canvas.drawPath(
          p,
          Kit.stroke(Colors.black.withValues(alpha: 0.3), u * 0.06),
        );
        canvas.drawLine(
          c,
          c.translate(0, -u * 0.9),
          Kit.stroke(Colors.black.withValues(alpha: 0.3), u * 0.06),
        );
        canvas.drawLine(
          c,
          c.translate(u * 0.78, u * 0.45),
          Kit.stroke(Colors.black.withValues(alpha: 0.3), u * 0.06),
        );
        canvas.drawLine(
          c,
          c.translate(-u * 0.78, u * 0.45),
          Kit.stroke(Colors.black.withValues(alpha: 0.3), u * 0.06),
        );
      default:
        canvas.drawPath(Kit.ngon(c, u * 0.8, 4, rotation: math.pi / 4), fill);
    }
  }

  static void _crescent(
    Canvas canvas,
    Offset c,
    double u,
    Color color, {
    required bool flip,
  }) {
    final dir = flip ? -1.0 : 1.0;
    final outer = Path()..addOval(Rect.fromCircle(center: c, radius: u * 0.85));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: c.translate(dir * u * 0.42, 0),
          radius: u * 0.78,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, cut),
      Kit.fill(color),
    );
  }
}

/// A sigil as a widget.
class SigilIcon extends StatelessWidget {
  const SigilIcon({
    super.key,
    required this.id,
    this.size = 40,
    this.color = AppColors.goldLight,
  });

  final String id;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _SigilPainter(id, color),
    ),
  );
}

class _SigilPainter extends CustomPainter {
  _SigilPainter(this.id, this.color);
  final String id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      Sigils.paint(canvas, id, Offset.zero & size, color);

  @override
  bool shouldRepaint(_SigilPainter old) => old.id != id || old.color != color;
}

/// Brass tuning dial with a numbered scale and a needle.
class DialFace extends StatelessWidget {
  const DialFace({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.size = 220,
  });

  final int value;
  final int min;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _DialPainter(v, min, max),
      ),
    ),
  );
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.value, this.min, this.max);
  final double value;
  final int min;
  final int max;

  static const _sweep = math.pi * 1.5;
  static const _start = math.pi * 0.75;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    Kit.glow(canvas, c, r * 1.2, AppColors.antiqueGold, 0.25);
    canvas.drawCircle(c, r * 0.96, Kit.brassPaint(Offset.zero & size));
    canvas.drawCircle(c, r * 0.86, Kit.fill(const Color(0xFF0E1230)));
    canvas.drawCircle(c, r * 0.86, Kit.stroke(AppColors.brassDark, 3));

    final scaleSpan = (max - min) == 0 ? 1 : (max - min);
    // Ticks every 5 units, labels on round tens, so the scale reads cleanly.
    for (var v = min; v <= max; v++) {
      if (v % 5 != 0) continue;
      final a = _start + _sweep * (v - min) / scaleSpan;
      final major = v % 10 == 0;
      final p1 =
          c + Offset(math.cos(a), math.sin(a)) * r * (major ? 0.68 : 0.74);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * r * 0.8;
      canvas.drawLine(
        p1,
        p2,
        Kit.stroke(AppColors.goldLight, major ? 2.6 : 1.4),
      );
      if (major) {
        Kit.text(
          canvas,
          '$v',
          c + Offset(math.cos(a), math.sin(a)) * r * 0.55,
          r * 0.11,
          AppColors.parchment,
          weight: FontWeight.w600,
        );
      }
    }
    final span = (max - min) == 0 ? 1 : (max - min);
    final frac = ((value - min) / span).clamp(0.0, 1.0);
    final a = _start + _sweep * frac;
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * r * 0.72,
      Kit.stroke(AppColors.moonCyan, 4),
    );
    Kit.glow(
      canvas,
      c + Offset(math.cos(a), math.sin(a)) * r * 0.72,
      r * 0.12,
      AppColors.moonCyan,
      0.8,
    );
    canvas.drawCircle(c, r * 0.09, Kit.fill(AppColors.brass));
    canvas.drawCircle(c, r * 0.09, Kit.stroke(AppColors.goldLight, 1.5));
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.value != value;
}

/// A clock face with hour and minute hands.
class ClockFace extends StatelessWidget {
  const ClockFace({
    super.key,
    required this.hour,
    required this.minute,
    this.size = 220,
  });

  final int hour;
  final int minute;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _ClockPainter(hour, minute),
    ),
  );
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.hour, this.minute);
  final int hour;
  final int minute;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    Kit.glow(canvas, c, r * 1.2, AppColors.antiqueGold, 0.28);
    canvas.drawCircle(c, r * 0.97, Kit.brassPaint(Offset.zero & size));
    canvas.drawCircle(c, r * 0.86, Kit.fill(const Color(0xFF14122E)));
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30 - math.pi / 2;
      final major = i % 5 == 0;
      final p1 =
          c + Offset(math.cos(a), math.sin(a)) * r * (major ? 0.72 : 0.78);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * r * 0.82;
      canvas.drawLine(
        p1,
        p2,
        Kit.stroke(
          AppColors.goldLight.withValues(alpha: major ? 1 : 0.5),
          major ? 2.6 : 1,
        ),
      );
    }
    for (final n in [12, 3, 6, 9]) {
      final a = n * math.pi / 6 - math.pi / 2;
      Kit.text(
        canvas,
        '$n',
        c + Offset(math.cos(a), math.sin(a)) * r * 0.6,
        r * 0.16,
        AppColors.parchment,
      );
    }
    final ha = ((hour % 12) + minute / 60) * math.pi / 6 - math.pi / 2;
    final ma = minute * math.pi / 30 - math.pi / 2;
    canvas.drawLine(
      c,
      c + Offset(math.cos(ha), math.sin(ha)) * r * 0.45,
      Kit.stroke(AppColors.goldLight, 6),
    );
    canvas.drawLine(
      c,
      c + Offset(math.cos(ma), math.sin(ma)) * r * 0.7,
      Kit.stroke(AppColors.moonCyan, 4),
    );
    canvas.drawCircle(c, r * 0.06, Kit.fill(AppColors.brass));
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.hour != hour || old.minute != minute;
}

/// One drive gear that turns a notch at a time.
class GearDial extends StatelessWidget {
  const GearDial({
    super.key,
    required this.position,
    required this.positions,
    this.size = 96,
    this.teeth = 12,
  });

  final int position;
  final int positions;
  final double size;
  final int teeth;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: position.toDouble()),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _GearPainter(v, positions, teeth),
      ),
    ),
  );
}

class _GearPainter extends CustomPainter {
  _GearPainter(this.position, this.positions, this.teeth);
  final double position;
  final int positions;
  final int teeth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rot = position * 2 * math.pi / positions;
    final gear = Kit.gear(c, r * 0.8, teeth, rotation: rot);
    canvas.drawPath(gear, Kit.brassPaint(Offset.zero & size));
    canvas.drawPath(gear, Kit.stroke(AppColors.goldLight, 1.5));
    canvas.drawCircle(c, r * 0.5, Kit.fill(const Color(0xFF14122E)));
    canvas.drawCircle(c, r * 0.5, Kit.stroke(AppColors.brassDark, 2));
    // Pointer showing the current notch.
    final a = rot - math.pi / 2;
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * r * 0.46,
      Kit.stroke(AppColors.moonCyan, 3.5),
    );
    canvas.drawCircle(c, r * 0.08, Kit.fill(AppColors.brass));
    // Notch pips around the outside.
    for (var i = 0; i < positions; i++) {
      final pa = i * 2 * math.pi / positions - math.pi / 2;
      canvas.drawCircle(
        c + Offset(math.cos(pa), math.sin(pa)) * r * 0.97,
        2.4,
        Kit.fill(AppColors.fog.withValues(alpha: 0.7)),
      );
    }
  }

  @override
  bool shouldRepaint(_GearPainter old) => old.position != position;
}
