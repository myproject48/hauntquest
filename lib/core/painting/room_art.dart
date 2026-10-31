import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'paint_kit.dart';

/// Code-drawn backdrop for one room, split into depth layers so the room view
/// can shift them for parallax. `t` loops from 0 to 1 and every animated value
/// uses whole cycles, so the loop is seamless.
abstract class RoomArt {
  const RoomArt();

  /// Looks up the art for a `sceneId` from `rooms.json`.
  static RoomArt forScene(String sceneId) => switch (sceneId) {
    'moonlit_hall' => const HallArt(),
    'forgotten_library' => const LibraryArt(),
    'alchemist_workshop' => const WorkshopArt(),
    'clocktower_chamber' => const ClocktowerArt(),
    'echo_vault' => const VaultArt(),
    _ => throw ArgumentError('No room art for scene "$sceneId".'),
  };

  /// Scene ids that have art. A content test checks every room uses one.
  static const Set<String> supported = {
    'moonlit_hall',
    'forgotten_library',
    'alchemist_workshop',
    'clocktower_chamber',
    'echo_vault',
  };

  /// Dominant light color, also used for fog and highlights.
  Color get accent;

  /// Colors at the very top and bottom of the scene. Used to extend the
  /// backdrop seamlessly past the stage on tall or wide screens.
  Color get topColor;
  Color get bottomColor;

  /// Walls, windows, distant architecture.
  void paintBack(Canvas canvas, Size size, double t);

  /// Set dressing behind the interactive objects.
  void paintMid(Canvas canvas, Size size, double t);

  /// Foreground silhouettes, light, and drifting particles.
  void paintFront(Canvas canvas, Size size, double t);
}

// ---------------------------------------------------------------- helpers

void _motes(
  Canvas c,
  Size s,
  double t,
  Color color, {
  int count = 18,
  double maxY = 1,
  int seed = 0,
}) {
  final p = Paint();
  for (var i = 0; i < count; i++) {
    final speed = 1 + (i % 3);
    final x =
        Kit.rand(i + seed) * s.width +
        math.sin((t * speed + Kit.rand(i)) * 2 * math.pi) * 8;
    final y = ((Kit.rand(i + seed + 40) - t * speed) % 1.0) * s.height * maxY;
    final tw =
        0.4 + 0.6 * math.sin((t * 2 + Kit.rand(i + 9)) * 2 * math.pi).abs();
    p.color = color.withValues(alpha: 0.3 * tw);
    c.drawCircle(Offset(x, y), 0.8 + Kit.rand(i + 70) * 1.4, p);
  }
}

void _floorTiles(
  Canvas c,
  Size s,
  double top,
  Color a,
  Color b, {
  int rows = 6,
}) {
  final h = s.height * (1 - top);
  var y = s.height * top;
  for (var r = 0; r < rows; r++) {
    final rh = h * (0.08 + 0.2 * (r / rows)) / (rows * 0.22);
    final cols = 6 + r * 2;
    final cw = s.width * 1.4 / cols;
    for (var i = -2; i < cols; i++) {
      final x = -s.width * 0.2 + i * cw;
      final rect = Rect.fromLTWH(x, y, cw + 1, math.min(rh, s.height - y + 2));
      c.drawRect(rect, Kit.fill((i + r).isEven ? a : b));
    }
    y += rh;
    if (y > s.height) break;
  }
}

void _vignetteFill(Canvas c, Size s, Color color, double alpha) {
  final rect = Offset.zero & s;
  c.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.9,
        colors: [
          Colors.transparent,
          color.withValues(alpha: alpha),
        ],
        stops: const [0.5, 1],
      ).createShader(rect),
  );
}

// ================================================================== HALL

class HallArt extends RoomArt {
  const HallArt();

  @override
  Color get accent => AppColors.moonCyan;
  @override
  Color get topColor => AppColors.midnight;
  @override
  Color get bottomColor => AppColors.stone;

  @override
  void paintBack(Canvas c, Size s, double t) {
    Kit.vGradient(
      c,
      Offset.zero & s,
      const [AppColors.midnight, AppColors.navy, AppColors.deepNavy],
      const [0, 0.55, 0.8],
    );

    // Arched moon window.
    final w = s.width;
    final h = s.height;
    final arch = Path()
      ..moveTo(w * 0.32, h * 0.32)
      ..lineTo(w * 0.32, h * 0.12)
      ..quadraticBezierTo(w * 0.5, -h * 0.04, w * 0.68, h * 0.12)
      ..lineTo(w * 0.68, h * 0.32)
      ..close();
    c.drawPath(arch, Kit.fill(const Color(0xFF0B3447)));
    Kit.glow(c, Offset(w * 0.55, h * 0.14), w * 0.22, AppColors.moonCyan, 0.5);
    c.drawCircle(
      Offset(w * 0.55, h * 0.14),
      w * 0.05,
      Kit.fill(const Color(0xFFE9FFFF)),
    );
    c.save();
    c.clipPath(arch);
    Kit.vGradient(c, Rect.fromLTWH(w * 0.32, 0, w * 0.36, h * 0.32), [
      AppColors.moonCyan.withValues(alpha: 0.0),
      AppColors.moonCyan.withValues(alpha: 0.28),
    ]);
    c.restore();
    final frame = Kit.stroke(AppColors.stoneLight, w * 0.014);
    c.drawPath(arch, frame);
    c.drawLine(
      Offset(w * 0.5, h * 0.02),
      Offset(w * 0.5, h * 0.32),
      Kit.stroke(AppColors.stoneLight, w * 0.008),
    );
    c.drawLine(
      Offset(w * 0.32, h * 0.2),
      Offset(w * 0.68, h * 0.2),
      Kit.stroke(AppColors.stoneLight, w * 0.008),
    );

    // Wainscot.
    c.drawRect(
      Rect.fromLTWH(0, h * 0.58, w, h * 0.22),
      Kit.fill(AppColors.deepNavy.withValues(alpha: 0.9)),
    );
    c.drawLine(
      Offset(0, h * 0.58),
      Offset(w, h * 0.58),
      Kit.stroke(AppColors.goldDeep, 2),
    );
    for (var i = 0; i < 7; i++) {
      final r = Rect.fromLTWH(
        w * (0.03 + i * 0.14),
        h * 0.61,
        w * 0.11,
        h * 0.16,
      );
      c.drawRect(
        r,
        Kit.stroke(AppColors.stoneLight.withValues(alpha: 0.8), 1.4),
      );
    }

    // Pilasters.
    for (final x in [0.0, 0.26, 0.74, 0.97]) {
      c.drawRect(
        Rect.fromLTWH(w * x, 0, w * 0.03, h * 0.8),
        Kit.fill(AppColors.stone.withValues(alpha: 0.7)),
      );
    }

    // Floor.
    _floorTiles(c, s, 0.8, AppColors.stone, const Color(0xFF0D1233));

    // Cobwebs in the upper corners.
    final web = Kit.stroke(AppColors.fog.withValues(alpha: 0.25), 1);
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi / 2 / 4;
      c.drawLine(
        Offset.zero,
        Offset(math.cos(a) * w * 0.2, math.sin(a) * h * 0.14),
        web,
      );
      c.drawLine(
        Offset(w, 0),
        Offset(w - math.cos(a) * w * 0.2, math.sin(a) * h * 0.14),
        web,
      );
    }

    // Cold light from the window, breathing slowly.
    final breathe = 0.7 + 0.3 * math.sin(t * 2 * math.pi);
    Kit.lightShaft(
      c,
      Offset(w * 0.5, h * 0.3),
      w * 0.3,
      Offset(w * 0.42, h * 0.84),
      w * 0.5,
      AppColors.moonCyan,
      0.16 * breathe,
    );
  }

  @override
  void paintMid(Canvas c, Size s, double t) {
    // Wall sconces with cold flames.
    for (final x in [0.285, 0.715]) {
      final p = Offset(s.width * x, s.height * 0.2);
      final f = 0.7 + 0.3 * math.sin((t * 5 + x) * 2 * math.pi);
      Kit.glow(
        c,
        p.translate(0, -8),
        s.width * 0.07,
        AppColors.moonCyan,
        0.5 * f,
      );
      c.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - 4)
          ..quadraticBezierTo(p.dx - 5, p.dy - 14, p.dx, p.dy - 22 * f)
          ..quadraticBezierTo(p.dx + 5, p.dy - 14, p.dx, p.dy - 4),
        Kit.fill(const Color(0xFFE9FFFF)),
      );
      Kit.rrect(
        c,
        Rect.fromCenter(center: p.translate(0, 2), width: 12, height: 8),
        2,
        Kit.brassPaint(Rect.fromCenter(center: p, width: 12, height: 8)),
      );
    }
  }

  @override
  void paintFront(Canvas c, Size s, double t) {
    // Velvet curtains at both edges.
    for (final left in [true, false]) {
      final x0 = left ? 0.0 : s.width;
      final dir = left ? 1.0 : -1.0;
      final path = Path()..moveTo(x0, 0);
      path.lineTo(x0 + dir * s.width * 0.1, 0);
      path.quadraticBezierTo(
        x0 + dir * s.width * 0.05,
        s.height * 0.4,
        x0 + dir * s.width * 0.09,
        s.height * 0.86,
      );
      path.lineTo(x0, s.height * 0.9);
      path.close();
      c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              const Color(0xFF14082B),
              AppColors.deepPurple.withValues(alpha: 0.9),
            ],
          ).createShader(Offset.zero & s),
      );
      for (var i = 1; i < 4; i++) {
        c.drawLine(
          Offset(x0 + dir * s.width * 0.022 * i, 0),
          Offset(x0 + dir * s.width * (0.02 * i + 0.01), s.height * 0.86),
          Kit.stroke(Colors.black.withValues(alpha: 0.3), 2),
        );
      }
    }
    _motes(c, s, t, AppColors.moonCyan, count: 16, maxY: 0.9);
  }
}

// ============================================================== LIBRARY

class LibraryArt extends RoomArt {
  const LibraryArt();

  @override
  Color get accent => AppColors.antiqueGold;
  @override
  Color get topColor => const Color(0xFF120A24);
  @override
  Color get bottomColor => AppColors.wood;

  @override
  void paintBack(Canvas c, Size s, double t) {
    final w = s.width;
    final h = s.height;
    Kit.vGradient(
      c,
      Offset.zero & s,
      const [Color(0xFF120A24), Color(0xFF1C1033), AppColors.wood],
      const [0, 0.6, 0.88],
    );

    // Walls of books.
    const palette = [
      AppColors.deepPurple,
      AppColors.violetMist,
      Color(0xFF5A1F2E),
      AppColors.goldDeep,
      Color(0xFF1F4A44),
      Color(0xFF2B3A6B),
      Color(0xFF4A3224),
    ];
    for (var row = 0; row < 5; row++) {
      final top = h * (0.03 + row * 0.115);
      final shelfY = top + h * 0.105;
      var x = 0.0;
      var i = row * 40;
      while (x < w) {
        final bw = w * (0.022 + Kit.rand(i) * 0.018);
        final bh = h * (0.062 + Kit.rand(i + 3) * 0.04);
        final color = palette[(Kit.rand(i + 7) * palette.length).floor()];
        final rect = Rect.fromLTWH(x, shelfY - bh, bw - 1, bh);
        c.drawRect(rect, Kit.fill(Color.lerp(color, Colors.black, 0.25)!));
        c.drawLine(
          Offset(x + bw * 0.3, shelfY - bh + 4),
          Offset(x + bw * 0.3, shelfY - 4),
          Kit.stroke(AppColors.goldLight.withValues(alpha: 0.28), 1),
        );
        x += bw;
        i++;
      }
      c.drawRect(
        Rect.fromLTWH(0, shelfY, w, h * 0.012),
        Kit.fill(AppColors.woodLight),
      );
    }

    // Moon-cold window between hearth and shelf.
    final win = Path()
      ..moveTo(w * 0.375, h * 0.5)
      ..lineTo(w * 0.375, h * 0.22)
      ..quadraticBezierTo(w * 0.43, h * 0.1, w * 0.485, h * 0.22)
      ..lineTo(w * 0.485, h * 0.5)
      ..close();
    c.drawPath(win, Kit.fill(const Color(0xFF0B3447)));
    Kit.glow(c, Offset(w * 0.43, h * 0.28), w * 0.16, AppColors.moonCyan, 0.4);
    c.drawPath(win, Kit.stroke(AppColors.woodLight, w * 0.016));
    c.drawLine(
      Offset(w * 0.43, h * 0.14),
      Offset(w * 0.43, h * 0.5),
      Kit.stroke(AppColors.woodLight, w * 0.008),
    );

    // Floorboards and rug.
    c.drawRect(
      Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
      Kit.woodPaint(Rect.fromLTWH(0, h * 0.86, w, h * 0.14)),
    );
    for (var i = 0; i < 9; i++) {
      c.drawLine(
        Offset(w * i / 8, h * 0.86),
        Offset(w * (i / 8 - 0.5) * 1.5 + w * 0.5, h),
        Kit.stroke(Colors.black.withValues(alpha: 0.35), 1.5),
      );
    }
    c.drawOval(
      Rect.fromLTWH(w * 0.1, h * 0.9, w * 0.8, h * 0.12),
      Kit.fill(AppColors.deepPurple.withValues(alpha: 0.75)),
    );
    c.drawOval(
      Rect.fromLTWH(w * 0.14, h * 0.92, w * 0.72, h * 0.08),
      Kit.stroke(AppColors.antiqueGold.withValues(alpha: 0.5), 1.5),
    );

    // Warm lantern glow, gently pulsing.
    final p = 0.85 + 0.15 * math.sin(t * 2 * math.pi * 2);
    Kit.glow(c, Offset(w * 0.3, h * 0.66), w * 0.75, AppColors.ember, 0.18 * p);
  }

  @override
  void paintMid(Canvas c, Size s, double t) {
    // Rolling ladder leaning on the shelves.
    final rail = Kit.stroke(AppColors.woodLight, 4);
    final x = s.width * 0.5;
    c.drawLine(Offset(x, s.height * 0.1), Offset(x + 10, s.height * 0.6), rail);
    c.drawLine(
      Offset(x + 22, s.height * 0.1),
      Offset(x + 32, s.height * 0.6),
      rail,
    );
    for (var i = 0; i < 7; i++) {
      final y = s.height * (0.14 + i * 0.07);
      c.drawLine(
        Offset(x + i * 1.2, y),
        Offset(x + 22 + i * 1.2, y),
        Kit.stroke(AppColors.woodLight, 3),
      );
    }
  }

  @override
  void paintFront(Canvas c, Size s, double t) {
    // Stacks of books in the lower corners.
    for (final left in [true, false]) {
      var y = s.height;
      for (var i = 0; i < 4; i++) {
        final bw = s.width * (0.16 - i * 0.02);
        final bh = s.height * 0.028;
        final x = left ? -s.width * 0.02 : s.width - bw + s.width * 0.02;
        y -= bh;
        Kit.rrect(
          c,
          Rect.fromLTWH(x + (i.isEven ? 0 : 6), y, bw, bh),
          2,
          Kit.fill(
            Color.lerp(
              const [
                AppColors.deepPurple,
                Color(0xFF5A1F2E),
                Color(0xFF1F4A44),
                AppColors.goldDeep,
              ][i],
              Colors.black,
              0.5,
            )!,
          ),
        );
      }
    }
    _motes(c, s, t, AppColors.goldLight, count: 22, maxY: 0.85, seed: 3);
    _vignetteFill(c, s, Colors.black, 0.35);
  }
}

// ============================================================ WORKSHOP

class WorkshopArt extends RoomArt {
  const WorkshopArt();

  @override
  Color get accent => AppColors.ghostGreen;
  @override
  Color get topColor => const Color(0xFF07161A);
  @override
  Color get bottomColor => const Color(0xFF0C1A1E);

  @override
  void paintBack(Canvas c, Size s, double t) {
    final w = s.width;
    final h = s.height;
    Kit.vGradient(
      c,
      Offset.zero & s,
      const [Color(0xFF07161A), Color(0xFF0E2A2A), Color(0xFF0C1A1E)],
      const [0, 0.55, 0.9],
    );

    // Brickwork.
    final brick = Kit.stroke(Colors.black.withValues(alpha: 0.28), 1.2);
    for (var r = 0; r < 26; r++) {
      final y = h * 0.04 + r * h * 0.034;
      if (y > h * 0.86) break;
      c.drawLine(Offset(0, y), Offset(w, y), brick);
      for (var x = (r.isEven ? 0.0 : w * 0.05); x < w; x += w * 0.1) {
        c.drawLine(Offset(x, y), Offset(x, y + h * 0.034), brick);
      }
    }

    // Copper pipes with a faint green flow.
    final pipe = Kit.stroke(AppColors.copper, 9);
    final hi = Kit.stroke(AppColors.goldLight.withValues(alpha: 0.4), 2);
    for (final y in [0.035, 0.075]) {
      c.drawLine(Offset(0, h * y), Offset(w, h * y), pipe);
      c.drawLine(Offset(0, h * y - 2.5), Offset(w, h * y - 2.5), hi);
      for (var i = 0; i < 6; i++) {
        final f = (t * 2 + i / 6 + y) % 1.0;
        Kit.glow(c, Offset(w * f, h * y), 9, AppColors.ghostGreen, 0.6);
      }
    }
    c.drawLine(Offset(w * 0.55, h * 0.075), Offset(w * 0.55, h * 0.13), pipe);
    for (final x in [0.12, 0.38, 0.7, 0.9]) {
      Kit.rrect(
        c,
        Rect.fromCenter(
          center: Offset(w * x, h * 0.055),
          width: 14,
          height: h * 0.07,
        ),
        3,
        Kit.fill(AppColors.brassDark),
      );
    }

    // Floor.
    c.drawRect(
      Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
      Kit.fill(AppColors.stone),
    );
    for (var i = 0; i < 7; i++) {
      c.drawLine(
        Offset(w * i / 6, h * 0.86),
        Offset(w * i / 6, h),
        Kit.stroke(Colors.black.withValues(alpha: 0.4), 1.5),
      );
    }
    Kit.glow(c, Offset(w * 0.3, h * 0.78), w * 0.6, AppColors.ghostGreen, 0.14);
  }

  @override
  void paintMid(Canvas c, Size s, double t) {
    // Glass alembic on the right, bubbling.
    final w = s.width;
    final h = s.height;
    final base = Rect.fromLTWH(w * 0.78, h * 0.6, w * 0.18, h * 0.26);
    Kit.rrect(
      c,
      Rect.fromLTWH(base.left - 4, base.bottom - 10, base.width + 8, 12),
      3,
      Kit.woodPaint(base),
    );
    c.drawCircle(
      Offset(base.center.dx, base.bottom - base.width * 0.45),
      base.width * 0.4,
      Kit.fill(AppColors.ghostGreen.withValues(alpha: 0.25)),
    );
    c.drawCircle(
      Offset(base.center.dx, base.bottom - base.width * 0.45),
      base.width * 0.4,
      Kit.stroke(AppColors.parchment.withValues(alpha: 0.7), 2),
    );
    c.drawLine(
      Offset(base.center.dx, base.bottom - base.width * 0.85),
      Offset(base.center.dx + 6, base.top),
      Kit.stroke(AppColors.parchment.withValues(alpha: 0.7), 3),
    );
    c.drawPath(
      Path()
        ..moveTo(base.center.dx + 6, base.top)
        ..quadraticBezierTo(
          base.right + 10,
          base.top - 6,
          base.right + 6,
          base.top + base.height * 0.3,
        ),
      Kit.stroke(AppColors.parchment.withValues(alpha: 0.7), 3),
    );
    for (var i = 0; i < 4; i++) {
      final f = (t * 2 + i / 4) % 1.0;
      c.drawCircle(
        Offset(
          base.center.dx + math.sin(f * 9 + i) * 6,
          base.bottom - base.width * 0.45 - f * base.width * 0.3,
        ),
        2.5,
        Kit.fill(AppColors.ghostGreen.withValues(alpha: 0.7 * (1 - f))),
      );
    }
  }

  @override
  void paintFront(Canvas c, Size s, double t) {
    // Steam rising from the bench area.
    for (var i = 0; i < 5; i++) {
      final f = (t * 2 + i / 5) % 1.0;
      final x = s.width * (0.14 + i * 0.06) + math.sin(f * 7 + i) * 10;
      final y = s.height * 0.58 - f * s.height * 0.22;
      Kit.glow(
        c,
        Offset(x, y),
        26 + f * 18,
        AppColors.ghostGreen,
        0.16 * (1 - f),
      );
    }
    // Hanging chain, top left.
    for (var i = 0; i < 9; i++) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s.width * 0.04, i * 13.0 + 6),
          width: 7,
          height: 11,
        ),
        Kit.stroke(const Color(0xFF03090B), 2.4),
      );
    }
    _motes(c, s, t, AppColors.ghostGreen, count: 14, maxY: 0.85, seed: 5);
    _vignetteFill(c, s, Colors.black, 0.4);
  }
}

// =========================================================== CLOCKTOWER

class ClocktowerArt extends RoomArt {
  const ClocktowerArt();

  @override
  Color get accent => AppColors.antiqueGold;
  @override
  Color get topColor => const Color(0xFF0E0A1C);
  @override
  Color get bottomColor => const Color(0xFF1A1216);

  @override
  void paintBack(Canvas c, Size s, double t) {
    final w = s.width;
    final h = s.height;
    Kit.vGradient(
      c,
      Offset.zero & s,
      const [Color(0xFF0E0A1C), Color(0xFF1A1630), Color(0xFF1A1216)],
      const [0, 0.6, 0.9],
    );

    // Stone courses.
    final course = Kit.stroke(Colors.black.withValues(alpha: 0.3), 1.2);
    for (var y = h * 0.05; y < h * 0.88; y += h * 0.05) {
      c.drawLine(Offset(0, y), Offset(w, y), course);
    }

    // Great gears turning slowly behind everything.
    void bigGear(Offset ctr, double r, int teeth, double dir) {
      final rot = dir * t * 2 * math.pi / teeth * 2;
      final path = Kit.gear(ctr, r, teeth, rotation: rot);
      c.drawPath(path, Kit.fill(const Color(0xFF241C34)));
      c.drawPath(path, Kit.stroke(AppColors.brass.withValues(alpha: 0.55), 2));
      c.drawCircle(
        ctr,
        r * 0.72,
        Kit.stroke(AppColors.brassDark.withValues(alpha: 0.6), 2),
      );
      for (var i = 0; i < 6; i++) {
        final a = rot + i * math.pi / 3;
        c.drawLine(
          ctr,
          ctr + Offset(math.cos(a), math.sin(a)) * r * 0.72,
          Kit.stroke(AppColors.brassDark.withValues(alpha: 0.6), 3),
        );
      }
      c.drawCircle(ctr, r * 0.12, Kit.fill(AppColors.brass));
    }

    bigGear(Offset(w * 0.06, h * 0.52), w * 0.26, 18, 1);
    bigGear(Offset(w * 0.95, h * 0.1), w * 0.2, 14, -1);
    bigGear(Offset(w * 0.78, h * 0.86), w * 0.28, 20, -1);

    // Beams.
    for (final x in [0.0, 0.965]) {
      c.drawRect(
        Rect.fromLTWH(w * x, 0, w * 0.035, h * 0.9),
        Kit.woodPaint(Rect.fromLTWH(w * x, 0, w * 0.035, h)),
      );
    }

    // Planks.
    c.drawRect(
      Rect.fromLTWH(0, h * 0.88, w, h * 0.12),
      Kit.woodPaint(Rect.fromLTWH(0, h * 0.88, w, h * 0.12)),
    );
    for (var i = 0; i < 8; i++) {
      c.drawLine(
        Offset(w * i / 7, h * 0.88),
        Offset(w * i / 7, h),
        Kit.stroke(Colors.black.withValues(alpha: 0.4), 1.4),
      );
    }

    // Moonlight from the clock window, warm-tinted by brass.
    Kit.lightShaft(
      c,
      Offset(w * 0.5, h * 0.1),
      w * 0.42,
      Offset(w * 0.5, h * 0.88),
      w * 0.7,
      AppColors.goldLight,
      0.1,
    );
    Kit.glow(
      c,
      Offset(w * 0.5, h * 0.26),
      w * 0.5,
      AppColors.antiqueGold,
      0.12,
    );
  }

  @override
  void paintMid(Canvas c, Size s, double t) {
    // Hanging chains with weights.
    for (final x in [0.2, 0.8]) {
      final sway = math.sin((t + x) * 2 * math.pi) * 3;
      for (var i = 0; i < 10; i++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(
              s.width * x + sway * i / 10,
              s.height * 0.02 + i * 12,
            ),
            width: 6,
            height: 10,
          ),
          Kit.stroke(AppColors.brassDark, 2),
        );
      }
      final end = Offset(s.width * x + sway, s.height * 0.02 + 122);
      Kit.rrect(
        c,
        Rect.fromCenter(center: end.translate(0, 12), width: 22, height: 24),
        4,
        Kit.brassPaint(Rect.fromCenter(center: end, width: 22, height: 24)),
      );
    }
  }

  @override
  void paintFront(Canvas c, Size s, double t) {
    // A pendulum silhouette sweeping the lower foreground, kept to the edge.
    // Kept in the lower-right corner, clear of the tube and the logbook.
    final angle = math.sin(t * 2 * math.pi * 2) * 0.2;
    final pivot = Offset(s.width * 0.97, s.height * 0.64);
    final len = s.height * 0.26;
    final bob = pivot + Offset(math.sin(angle) * len, math.cos(angle) * len);
    c.drawLine(pivot, bob, Kit.stroke(const Color(0xFF05040C), 4));
    c.drawCircle(bob, s.width * 0.04, Kit.fill(const Color(0xFF05040C)));
    c.drawCircle(
      bob,
      s.width * 0.04,
      Kit.stroke(AppColors.brass.withValues(alpha: 0.5), 1.5),
    );
    _motes(c, s, t, AppColors.goldLight, count: 16, maxY: 0.9, seed: 8);
    _vignetteFill(c, s, Colors.black, 0.4);
  }
}

// ================================================================ VAULT

class VaultArt extends RoomArt {
  const VaultArt();

  @override
  Color get accent => const Color(0xFFB48CFF);
  @override
  Color get topColor => const Color(0xFF090514);
  @override
  Color get bottomColor => const Color(0xFF120A2A);

  @override
  void paintBack(Canvas c, Size s, double t) {
    final w = s.width;
    final h = s.height;
    Kit.vGradient(
      c,
      Offset.zero & s,
      const [Color(0xFF090514), Color(0xFF160B33), Color(0xFF120A2A)],
      const [0, 0.55, 0.9],
    );

    // Concentric arches of mirrored stone.
    final center = Offset(w * 0.5, h * 0.55);
    for (var i = 0; i < 6; i++) {
      final r = w * (0.95 - i * 0.14);
      final rect = Rect.fromCenter(center: center, width: r, height: r * 1.25);
      c.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        Kit.stroke(
          Color.lerp(
            AppColors.stoneLight,
            AppColors.violetMist,
            i / 6,
          )!.withValues(alpha: 0.7),
          w * 0.012,
        ),
      );
    }
    // Stone block lines on both walls.
    for (var y = h * 0.06; y < h * 0.86; y += h * 0.06) {
      c.drawLine(
        Offset(0, y),
        Offset(w * 0.24, y),
        Kit.stroke(Colors.black.withValues(alpha: 0.35), 1.2),
      );
      c.drawLine(
        Offset(w * 0.76, y),
        Offset(w, y),
        Kit.stroke(Colors.black.withValues(alpha: 0.35), 1.2),
      );
    }

    // Mirror strip on the right wall (the left one is interactive).
    final mir = Rect.fromLTWH(w * 0.8, h * 0.16, w * 0.18, h * 0.56);
    Kit.rrect(
      c,
      mir,
      6,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2A78), Color(0xFF120A2A), Color(0xFF2B4A78)],
        ).createShader(mir),
    );
    Kit.rrect(c, mir, 6, Kit.stroke(AppColors.stoneLight, 4));
    c.drawLine(
      mir.topLeft.translate(10, 10),
      mir.topLeft.translate(40, 80),
      Kit.stroke(Colors.white.withValues(alpha: 0.2), 3),
    );

    // Floor ellipse with a slowly turning ring of runes.
    final floor = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.9),
      width: w * 0.95,
      height: h * 0.2,
    );
    c.drawOval(floor, Kit.fill(const Color(0xFF0C0722)));
    c.drawOval(
      floor,
      Kit.stroke(AppColors.violetMist.withValues(alpha: 0.8), 2),
    );
    for (var i = 0; i < 14; i++) {
      final a = t * 2 * math.pi * 0.25 + i * 2 * math.pi / 14;
      final p =
          floor.center +
          Offset(
            math.cos(a) * floor.width * 0.42,
            math.sin(a) * floor.height * 0.42,
          );
      c.drawCircle(
        p,
        2.6,
        Kit.fill(
          AppColors.moonCyan.withValues(
            alpha: 0.5 + 0.4 * math.sin(a * 3 + t * 6),
          ),
        ),
      );
    }

    // The Echo's glow at the heart of the room.
    final pulse = 0.8 + 0.2 * math.sin(t * 2 * math.pi * 2);
    Kit.glow(
      c,
      Offset(w * 0.5, h * 0.3),
      w * 0.7,
      const Color(0xFFB48CFF),
      0.2 * pulse,
    );
    Kit.glow(
      c,
      Offset(w * 0.5, h * 0.3),
      w * 0.3,
      AppColors.moonCyan,
      0.22 * pulse,
    );
  }

  @override
  void paintMid(Canvas c, Size s, double t) {
    // Hanging crystal shards above the center.
    for (var i = 0; i < 7; i++) {
      final x = s.width * (0.3 + i * 0.066);
      final len = s.height * (0.04 + Kit.rand(i + 3) * 0.05);
      final sway = math.sin((t + i / 7) * 2 * math.pi) * 2;
      final top = Offset(x + sway * 0.3, 0);
      final tip = Offset(x + sway, len);
      c.drawLine(
        top,
        tip.translate(0, -8),
        Kit.stroke(AppColors.stoneLight, 1.2),
      );
      c.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy + 12)
          ..lineTo(tip.dx - 5, tip.dy)
          ..lineTo(tip.dx, tip.dy - 8)
          ..lineTo(tip.dx + 5, tip.dy)
          ..close(),
        Kit.fill(AppColors.moonCyan.withValues(alpha: 0.5)),
      );
    }
  }

  @override
  void paintFront(Canvas c, Size s, double t) {
    // Slow ripples spreading across the floor.
    for (var i = 0; i < 3; i++) {
      final f = (t * 2 + i / 3) % 1.0;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s.width * 0.5, s.height * 0.9),
          width: s.width * (0.2 + f * 0.9),
          height: s.height * (0.04 + f * 0.16),
        ),
        Kit.stroke(AppColors.moonCyan.withValues(alpha: 0.4 * (1 - f)), 1.6),
      );
    }
    _motes(c, s, t, const Color(0xFFD9C4FF), count: 20, maxY: 0.92, seed: 12);
    _vignetteFill(c, s, Colors.black, 0.45);
  }
}
