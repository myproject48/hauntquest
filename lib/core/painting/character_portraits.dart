import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'paint_kit.dart';

/// Framed bust portrait of a story voice, drawn in code.
///
/// [characterId] matches `story.json` (`tallow`, `ottoline`, `wren`, `maul`,
/// `echo`). With [unknown] true only a mysterious silhouette is shown.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({
    super.key,
    required this.characterId,
    this.size = 96,
    this.unknown = false,
    this.animation,
  });

  final String characterId;
  final double size;
  final bool unknown;

  /// Optional 0 to 1 looping value for subtle life (eye glow, ripples).
  final Animation<double>? animation;

  static const Set<String> supported = {
    'tallow',
    'ottoline',
    'wren',
    'maul',
    'echo',
  };

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PortraitPainter(characterId, unknown, animation),
        ),
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.id, this.unknown, this.anim) : super(repaint: anim);

  final String id;
  final bool unknown;
  final Animation<double>? anim;

  Color get _accent => switch (id) {
    'tallow' => AppColors.moonCyan,
    'ottoline' => AppColors.antiqueGold,
    'wren' => AppColors.ghostGreen,
    'maul' => const Color(0xFFB48CFF),
    _ => AppColors.moonCyan,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final t = anim?.value ?? 0.25;
    final accent = unknown ? AppColors.fog : _accent;

    // Medallion background.
    final disc = Rect.fromCircle(center: c, radius: s * 0.48);
    canvas.drawCircle(
      c,
      s * 0.48,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          colors: [
            Color.lerp(AppColors.deepPurple, accent, 0.28)!,
            AppColors.midnight,
          ],
        ).createShader(disc),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    canvas.translate(c.dx - s / 2, c.dy - s / 2);
    canvas.scale(s);
    if (unknown) {
      _silhouette(canvas);
    } else {
      switch (id) {
        case 'tallow':
          _tallow(canvas, t);
        case 'ottoline':
          _ottoline(canvas);
        case 'wren':
          _wren(canvas);
        case 'maul':
          _maul(canvas, t);
        default:
          _echo(canvas, t);
      }
    }
    canvas.restore();

    // Gold ring.
    canvas.drawCircle(
      c,
      s * 0.48,
      Kit.stroke(AppColors.antiqueGold, s * 0.025),
    );
    canvas.drawCircle(
      c,
      s * 0.445,
      Kit.stroke(accent.withValues(alpha: 0.5), s * 0.008),
    );
  }

  void _silhouette(Canvas c) {
    final p = Kit.fill(AppColors.stoneLight);
    c.drawOval(const Rect.fromLTWH(0.36, 0.2, 0.28, 0.32), p);
    c.drawPath(
      Path()
        ..moveTo(0.14, 0.95)
        ..quadraticBezierTo(0.18, 0.6, 0.5, 0.58)
        ..quadraticBezierTo(0.82, 0.6, 0.86, 0.95)
        ..close(),
      p,
    );
    Kit.text(c, '?', const Offset(0.5, 0.38), 0.18, AppColors.fog);
  }

  void _tallow(Canvas c, double t) {
    // Coat and collar.
    c.drawPath(
      Path()
        ..moveTo(0.1, 0.98)
        ..quadraticBezierTo(0.14, 0.66, 0.5, 0.64)
        ..quadraticBezierTo(0.86, 0.66, 0.9, 0.98)
        ..close(),
      Kit.fill(const Color(0xFF3A3F66)),
    );
    c.drawPath(
      Path()
        ..moveTo(0.42, 0.64)
        ..lineTo(0.5, 0.82)
        ..lineTo(0.58, 0.64)
        ..close(),
      Kit.fill(AppColors.paper),
    );
    c.drawCircle(const Offset(0.5, 0.88), 0.022, Kit.fill(AppColors.brass));
    // Head: brushed brass.
    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0.3, 0.2, 0.4, 0.44),
      const Radius.circular(0.1),
    );
    c.drawRRect(head, Kit.brassPaint(const Rect.fromLTWH(0.3, 0.2, 0.4, 0.44)));
    c.drawRRect(head, Kit.stroke(AppColors.brassDark, 0.012));
    // Porter's cap.
    c.drawPath(
      Path()
        ..moveTo(0.28, 0.26)
        ..quadraticBezierTo(0.5, 0.06, 0.72, 0.26)
        ..lineTo(0.76, 0.3)
        ..lineTo(0.24, 0.3)
        ..close(),
      Kit.fill(const Color(0xFF232A55)),
    );
    c.drawLine(
      const Offset(0.26, 0.285),
      const Offset(0.74, 0.285),
      Kit.stroke(AppColors.antiqueGold, 0.012),
    );
    // Eyes glow gently.
    final glow = 0.75 + 0.25 * math.sin(t * 2 * math.pi);
    for (final dx in [0.41, 0.59]) {
      Kit.glow(c, Offset(dx, 0.43), 0.1, AppColors.moonCyan, 0.55 * glow);
      c.drawCircle(Offset(dx, 0.43), 0.045, Kit.fill(const Color(0xFFE9FFFF)));
      c.drawCircle(Offset(dx, 0.43), 0.022, Kit.fill(AppColors.cyanDeep));
    }
    // Speaker grille mouth and rivets.
    for (var i = 0; i < 4; i++) {
      c.drawLine(
        Offset(0.42 + i * 0.05, 0.54),
        Offset(0.42 + i * 0.05, 0.6),
        Kit.stroke(AppColors.brassDark, 0.012),
      );
    }
    c.drawCircle(
      const Offset(0.34, 0.25),
      0.012,
      Kit.fill(AppColors.goldLight),
    );
    c.drawCircle(
      const Offset(0.66, 0.25),
      0.012,
      Kit.fill(AppColors.goldLight),
    );
    c.drawPath(
      Kit.gear(const Offset(0.66, 0.56), 0.05, 8),
      Kit.fill(AppColors.brassDark),
    );
  }

  void _ottoline(Canvas c) {
    const skin = Color(0xFFE2B99A);
    // Scarf and shoulders.
    c.drawPath(
      Path()
        ..moveTo(0.08, 0.98)
        ..quadraticBezierTo(0.12, 0.68, 0.5, 0.66)
        ..quadraticBezierTo(0.88, 0.68, 0.92, 0.98)
        ..close(),
      Kit.fill(const Color(0xFF5C3A2A)),
    );
    c.drawPath(
      Path()
        ..moveTo(0.36, 0.66)
        ..quadraticBezierTo(0.5, 0.78, 0.64, 0.66)
        ..lineTo(0.62, 0.76)
        ..quadraticBezierTo(0.5, 0.86, 0.38, 0.76)
        ..close(),
      Kit.fill(AppColors.deepPurple),
    );
    c.drawLine(
      const Offset(0.42, 0.76),
      const Offset(0.4, 0.88),
      Kit.stroke(AppColors.goldLight, 0.01),
    );
    // Neck, face.
    c.drawRect(
      const Rect.fromLTWH(0.44, 0.56, 0.12, 0.12),
      Kit.fill(skin.withValues(alpha: 0.85)),
    );
    c.drawOval(const Rect.fromLTWH(0.33, 0.22, 0.34, 0.44), Kit.fill(skin));
    // Hair with bun.
    c.drawCircle(
      const Offset(0.5, 0.15),
      0.1,
      Kit.fill(const Color(0xFF3B2418)),
    );
    c.drawPath(
      Path()
        ..moveTo(0.3, 0.46)
        ..quadraticBezierTo(0.26, 0.18, 0.5, 0.17)
        ..quadraticBezierTo(0.74, 0.18, 0.7, 0.46)
        ..quadraticBezierTo(0.66, 0.3, 0.5, 0.29)
        ..quadraticBezierTo(0.34, 0.3, 0.3, 0.46)
        ..close(),
      Kit.fill(const Color(0xFF3B2418)),
    );
    // Goggles pushed up on the forehead.
    for (final dx in [0.43, 0.57]) {
      c.drawCircle(
        Offset(dx, 0.3),
        0.055,
        Kit.fill(AppColors.moonCyan.withValues(alpha: 0.5)),
      );
      c.drawCircle(Offset(dx, 0.3), 0.055, Kit.stroke(AppColors.brass, 0.018));
    }
    c.drawLine(
      const Offset(0.485, 0.3),
      const Offset(0.515, 0.3),
      Kit.stroke(AppColors.brass, 0.014),
    );
    // Face details: warm, amused.
    for (final dx in [0.43, 0.57]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(dx, 0.43), width: 0.05, height: 0.03),
        Kit.fill(AppColors.wood),
      );
    }
    c.drawPath(
      Path()
        ..moveTo(0.44, 0.54)
        ..quadraticBezierTo(0.5, 0.59, 0.57, 0.53),
      Kit.stroke(const Color(0xFF9B4B4B), 0.014),
    );
    // Ink smudge on the cheek.
    c.drawCircle(
      const Offset(0.61, 0.5),
      0.018,
      Kit.fill(AppColors.deepPurple.withValues(alpha: 0.7)),
    );
  }

  void _wren(Canvas c) {
    // Hooded cloak.
    c.drawPath(
      Path()
        ..moveTo(0.06, 0.98)
        ..quadraticBezierTo(0.1, 0.56, 0.5, 0.5)
        ..quadraticBezierTo(0.9, 0.56, 0.94, 0.98)
        ..close(),
      Kit.fill(const Color(0xFF1F4A44)),
    );
    c.drawPath(
      Path()
        ..moveTo(0.22, 0.6)
        ..quadraticBezierTo(0.18, 0.12, 0.5, 0.1)
        ..quadraticBezierTo(0.82, 0.12, 0.78, 0.6)
        ..quadraticBezierTo(0.5, 0.5, 0.22, 0.6)
        ..close(),
      Kit.fill(const Color(0xFF2B6159)),
    );
    // Shadowed face.
    c.drawOval(
      const Rect.fromLTWH(0.33, 0.24, 0.34, 0.38),
      Kit.fill(const Color(0xFF16322F)),
    );
    c.drawOval(
      const Rect.fromLTWH(0.36, 0.3, 0.28, 0.3),
      Kit.fill(const Color(0xFFC9A28A)),
    );
    // Wide, worried eyes.
    for (final dx in [0.44, 0.56]) {
      c.drawCircle(Offset(dx, 0.43), 0.035, Kit.fill(Colors.white));
      c.drawCircle(Offset(dx + 0.004, 0.435), 0.017, Kit.fill(AppColors.wood));
    }
    c.drawLine(
      const Offset(0.4, 0.37),
      const Offset(0.46, 0.385),
      Kit.stroke(AppColors.wood, 0.012),
    );
    c.drawLine(
      const Offset(0.6, 0.37),
      const Offset(0.54, 0.385),
      Kit.stroke(AppColors.wood, 0.012),
    );
    c.drawLine(
      const Offset(0.46, 0.55),
      const Offset(0.54, 0.555),
      Kit.stroke(const Color(0xFF8A5A4A), 0.012),
    );
    // Little lantern glow held low.
    Kit.glow(c, const Offset(0.8, 0.82), 0.2, AppColors.ghostGreen, 0.55);
    c.drawCircle(
      const Offset(0.8, 0.82),
      0.04,
      Kit.fill(const Color(0xFFEFFFF6)),
    );
  }

  void _maul(Canvas c, double t) {
    // Tall dark coat with high collar.
    c.drawPath(
      Path()
        ..moveTo(0.06, 0.98)
        ..lineTo(0.16, 0.66)
        ..lineTo(0.34, 0.56)
        ..lineTo(0.5, 0.74)
        ..lineTo(0.66, 0.56)
        ..lineTo(0.84, 0.66)
        ..lineTo(0.94, 0.98)
        ..close(),
      Kit.fill(const Color(0xFF14102B)),
    );
    c.drawPath(
      Path()
        ..moveTo(0.44, 0.62)
        ..lineTo(0.5, 0.96)
        ..lineTo(0.56, 0.62)
        ..close(),
      Kit.fill(AppColors.antiqueGold.withValues(alpha: 0.8)),
    );
    // Top hat.
    c.drawRect(
      const Rect.fromLTWH(0.34, 0.02, 0.32, 0.26),
      Kit.fill(const Color(0xFF0B0A1A)),
    );
    c.drawRect(
      const Rect.fromLTWH(0.34, 0.2, 0.32, 0.04),
      Kit.fill(AppColors.violetMist),
    );
    c.drawOval(
      const Rect.fromLTWH(0.24, 0.24, 0.52, 0.07),
      Kit.fill(const Color(0xFF0B0A1A)),
    );
    // Pale, narrow face.
    c.drawPath(
      Path()
        ..moveTo(0.37, 0.3)
        ..quadraticBezierTo(0.5, 0.28, 0.63, 0.3)
        ..quadraticBezierTo(0.62, 0.58, 0.5, 0.66)
        ..quadraticBezierTo(0.38, 0.58, 0.37, 0.3)
        ..close(),
      Kit.fill(const Color(0xFFCFC6D8)),
    );
    // Glinting violet eyes and a thin smile.
    final flick = 0.7 + 0.3 * math.sin(t * 2 * math.pi * 2);
    for (final dx in [0.44, 0.56]) {
      Kit.glow(c, Offset(dx, 0.4), 0.07, const Color(0xFFB48CFF), 0.6 * flick);
      c.drawOval(
        Rect.fromCenter(center: Offset(dx, 0.4), width: 0.055, height: 0.026),
        Kit.fill(const Color(0xFF3B1B72)),
      );
    }
    c.drawLine(
      const Offset(0.4, 0.36),
      const Offset(0.47, 0.375),
      Kit.stroke(const Color(0xFF14102B), 0.012),
    );
    c.drawLine(
      const Offset(0.6, 0.36),
      const Offset(0.53, 0.375),
      Kit.stroke(const Color(0xFF14102B), 0.012),
    );
    c.drawPath(
      Path()
        ..moveTo(0.43, 0.53)
        ..quadraticBezierTo(0.5, 0.57, 0.58, 0.52),
      Kit.stroke(const Color(0xFF6B3B5B), 0.012),
    );
  }

  void _echo(Canvas c, double t) {
    const ctr = Offset(0.5, 0.5);
    for (var i = 0; i < 5; i++) {
      final phase = (t + i / 5) % 1.0;
      c.drawCircle(
        ctr,
        0.08 + phase * 0.42,
        Kit.stroke(
          AppColors.moonCyan.withValues(alpha: (1 - phase) * 0.55),
          0.012,
        ),
      );
    }
    Kit.glow(c, ctr, 0.4, AppColors.moonCyan, 0.5);
    // A face that is almost there.
    c.drawPath(
      Path()
        ..moveTo(0.38, 0.3)
        ..quadraticBezierTo(0.5, 0.2, 0.62, 0.3)
        ..quadraticBezierTo(0.66, 0.55, 0.5, 0.74)
        ..quadraticBezierTo(0.34, 0.55, 0.38, 0.3)
        ..close(),
      Kit.fill(const Color(0xFFE9FFFF).withValues(alpha: 0.22)),
    );
    for (final dx in [0.44, 0.56]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(dx, 0.43), width: 0.05, height: 0.07),
        Kit.fill(AppColors.midnight.withValues(alpha: 0.7)),
      );
    }
    c.drawOval(
      Rect.fromCenter(
        center: const Offset(0.5, 0.6),
        width: 0.07,
        height: 0.05,
      ),
      Kit.fill(AppColors.midnight.withValues(alpha: 0.6)),
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.id != id || old.unknown != unknown;
}
