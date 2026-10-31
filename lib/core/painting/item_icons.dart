import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'paint_kit.dart';

/// Original illustrated icon for an inventory item, selected by `iconId`.
class ItemIcon extends StatelessWidget {
  const ItemIcon({
    super.key,
    required this.iconId,
    this.size = 64,
    this.glow = true,
    this.dimmed = false,
  });

  final String iconId;
  final double size;

  /// Soft gold light behind the object.
  final bool glow;

  /// Draws only a dark silhouette, for items not found yet.
  final bool dimmed;

  /// Icon ids that have artwork. A content test checks every item uses one.
  static const Set<String> supported = {
    'letter',
    'key',
    'lantern',
    'journal',
    'page',
    'vial',
    'cylinder',
    'cog',
    'crystal',
  };

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ItemPainter(iconId, glow: glow, dimmed: dimmed),
        ),
      ),
    );
  }
}

class _ItemPainter extends CustomPainter {
  _ItemPainter(this.id, {required this.glow, required this.dimmed});

  final String id;
  final bool glow;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);

    if (glow && !dimmed) {
      Kit.glow(canvas, c, s * 0.62, AppColors.antiqueGold, 0.28);
    }
    canvas.save();
    canvas.translate(c.dx - s / 2, c.dy - s / 2);
    canvas.scale(s);
    if (dimmed) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()
          ..colorFilter = const ColorFilter.mode(
            AppColors.stone,
            BlendMode.srcATop,
          ),
      );
    }
    switch (id) {
      case 'letter':
        _letter(canvas);
      case 'key':
        _key(canvas);
      case 'lantern':
        _lantern(canvas);
      case 'journal':
        _journal(canvas);
      case 'page':
        _page(canvas);
      case 'vial':
        _vial(canvas);
      case 'cylinder':
        _cylinder(canvas);
      case 'cog':
        _cog(canvas);
      case 'crystal':
        _crystal(canvas);
      default:
        _page(canvas);
    }
    if (dimmed) canvas.restore();
    canvas.restore();
  }

  // All drawing below uses a 1x1 coordinate space.

  void _letter(Canvas c) {
    c.save();
    c.translate(0.5, 0.52);
    c.rotate(-0.12);
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: 0.78,
      height: 0.54,
    );
    Kit.rrect(
      c,
      body.shift(const Offset(0.02, 0.03)),
      0.03,
      Kit.fill(const Color(0x66000000)),
    );
    Kit.rrect(c, body, 0.03, Kit.fill(AppColors.paper));
    c.drawPath(
      Path()
        ..moveTo(body.left, body.top)
        ..lineTo(0, 0.04)
        ..lineTo(body.right, body.top),
      Kit.fill(AppColors.paperDark),
    );
    c.drawPath(
      Path()
        ..moveTo(body.left, body.bottom)
        ..lineTo(-0.1, 0.05)
        ..moveTo(body.right, body.bottom)
        ..lineTo(0.1, 0.05),
      Kit.stroke(AppColors.paperDark, 0.012),
    );
    c.drawCircle(const Offset(0, 0.04), 0.075, Kit.fill(AppColors.deepPurple));
    c.drawCircle(
      const Offset(0, 0.04),
      0.075,
      Kit.stroke(AppColors.antiqueGold, 0.014),
    );
    c.drawCircle(
      const Offset(0, 0.04),
      0.03,
      Kit.stroke(AppColors.goldLight, 0.01),
    );
    c.restore();
  }

  void _key(Canvas c) {
    final brass = Kit.brassPaint(const Rect.fromLTWH(0, 0, 1, 1));
    c.save();
    c.translate(0.5, 0.5);
    c.rotate(-0.7);
    c.drawCircle(
      const Offset(-0.26, 0),
      0.17,
      Kit.stroke(AppColors.brass, 0.07),
    );
    c.drawCircle(
      const Offset(-0.26, 0),
      0.17,
      Kit.stroke(AppColors.goldLight, 0.012),
    );
    Kit.rrect(c, const Rect.fromLTWH(-0.1, -0.03, 0.55, 0.06), 0.02, brass);
    Kit.rrect(c, const Rect.fromLTWH(0.28, 0.02, 0.06, 0.13), 0.01, brass);
    Kit.rrect(c, const Rect.fromLTWH(0.39, 0.02, 0.06, 0.1), 0.01, brass);
    Kit.text(c, 'T', const Offset(-0.26, 0), 0.14, AppColors.brassDark);
    c.restore();
  }

  void _lantern(Canvas c) {
    Kit.glow(c, const Offset(0.5, 0.55), 0.42, AppColors.moonCyan, 0.5);
    c.drawArc(
      const Rect.fromLTWH(0.32, 0.04, 0.36, 0.3),
      3.14,
      3.14,
      false,
      Kit.stroke(AppColors.brass, 0.03),
    );
    Kit.rrect(
      c,
      const Rect.fromLTWH(0.3, 0.18, 0.4, 0.07),
      0.02,
      Kit.brassPaint(const Rect.fromLTWH(0.3, 0.18, 0.4, 0.07)),
    );
    final glass = const Rect.fromLTWH(0.33, 0.25, 0.34, 0.5);
    Kit.rrect(
      c,
      glass,
      0.05,
      Kit.fill(AppColors.moonCyan.withValues(alpha: 0.22)),
    );
    Kit.rrect(c, glass, 0.05, Kit.stroke(AppColors.brass, 0.022));
    c.drawPath(
      Path()
        ..moveTo(0.5, 0.64)
        ..quadraticBezierTo(0.42, 0.52, 0.5, 0.36)
        ..quadraticBezierTo(0.58, 0.52, 0.5, 0.64),
      Kit.fill(const Color(0xFFE9FFFF)),
    );
    Kit.rrect(
      c,
      const Rect.fromLTWH(0.28, 0.75, 0.44, 0.08),
      0.02,
      Kit.brassPaint(const Rect.fromLTWH(0.28, 0.75, 0.44, 0.08)),
    );
  }

  void _journal(Canvas c) {
    c.save();
    c.translate(0.5, 0.5);
    c.rotate(0.08);
    final r = Rect.fromCenter(center: Offset.zero, width: 0.6, height: 0.78);
    Kit.rrect(
      c,
      r.shift(const Offset(0.02, 0.03)),
      0.03,
      Kit.fill(const Color(0x66000000)),
    );
    Kit.rrect(c, r, 0.03, Kit.fill(AppColors.deepPurple));
    Kit.rrect(
      c,
      r.deflate(0.04),
      0.02,
      Kit.stroke(AppColors.antiqueGold, 0.014),
    );
    c.drawRect(
      Rect.fromLTWH(r.left, r.top, 0.07, r.height),
      Kit.fill(AppColors.midnight),
    );
    Kit.text(c, 'O.V.', const Offset(0.04, -0.12), 0.1, AppColors.goldLight);
    c.drawCircle(
      const Offset(0.04, 0.05),
      0.06,
      Kit.stroke(AppColors.antiqueGold, 0.014),
    );
    c.drawLine(
      const Offset(0.22, -0.2),
      const Offset(0.22, 0.45),
      Kit.stroke(AppColors.danger, 0.03),
    );
    Kit.rrect(
      c,
      const Rect.fromLTWH(0.27, 0.12, 0.06, 0.14),
      0.01,
      Kit.brassPaint(const Rect.fromLTWH(0.27, 0.12, 0.06, 0.14)),
    );
    c.restore();
  }

  void _page(Canvas c) {
    c.save();
    c.translate(0.5, 0.5);
    c.rotate(-0.1);
    final path = Path()
      ..moveTo(-0.27, -0.36)
      ..lineTo(0.27, -0.36)
      ..lineTo(0.27, 0.12)
      ..lineTo(0.2, 0.2)
      ..lineTo(0.24, 0.27)
      ..lineTo(0.12, 0.33)
      ..lineTo(0.14, 0.4)
      ..lineTo(-0.27, 0.4)
      ..close();
    c.drawPath(
      path.shift(const Offset(0.02, 0.03)),
      Kit.fill(const Color(0x66000000)),
    );
    c.drawPath(path, Kit.fill(AppColors.paper));
    c.drawPath(path, Kit.stroke(AppColors.paperDark, 0.012));
    for (var i = 0; i < 6; i++) {
      final y = -0.26 + i * 0.1;
      c.drawLine(
        Offset(-0.19, y),
        Offset(0.19 - (i.isEven ? 0 : 0.08), y),
        Kit.stroke(AppColors.wood.withValues(alpha: 0.7), 0.014),
      );
    }
    c.drawCircle(
      const Offset(0.14, 0.2),
      0.05,
      Kit.stroke(AppColors.verdigris, 0.014),
    );
    c.restore();
  }

  void _vial(Canvas c) {
    Kit.glow(c, const Offset(0.5, 0.62), 0.38, AppColors.moonCyan, 0.4);
    final flask = Path()
      ..moveTo(0.42, 0.1)
      ..lineTo(0.58, 0.1)
      ..lineTo(0.58, 0.38)
      ..quadraticBezierTo(0.8, 0.55, 0.74, 0.76)
      ..quadraticBezierTo(0.7, 0.9, 0.5, 0.9)
      ..quadraticBezierTo(0.3, 0.9, 0.26, 0.76)
      ..quadraticBezierTo(0.2, 0.55, 0.42, 0.38)
      ..close();
    c.drawPath(flask, Kit.fill(AppColors.moonCyan.withValues(alpha: 0.15)));
    c.save();
    c.clipPath(flask);
    Kit.vGradient(c, const Rect.fromLTWH(0, 0.52, 1, 0.5), [
      const Color(0xFFE9FFFF),
      AppColors.moonCyan,
      AppColors.cyanDeep,
    ]);
    c.restore();
    c.drawPath(
      flask,
      Kit.stroke(AppColors.parchment.withValues(alpha: 0.85), 0.02),
    );
    Kit.rrect(
      c,
      const Rect.fromLTWH(0.4, 0.05, 0.2, 0.08),
      0.02,
      Kit.fill(AppColors.woodLight),
    );
    c.drawCircle(
      const Offset(0.4, 0.7),
      0.025,
      Kit.fill(Colors.white.withValues(alpha: 0.7)),
    );
  }

  void _cylinder(Canvas c) {
    final body = const Rect.fromLTWH(0.3, 0.2, 0.4, 0.6);
    Kit.rrect(c, body, 0.05, Kit.fill(const Color(0xFFC9A66B)));
    for (var i = 0; i < 9; i++) {
      final y = body.top + 0.04 + i * 0.062;
      c.drawLine(
        Offset(body.left + 0.02, y),
        Offset(body.right - 0.02, y),
        Kit.stroke(AppColors.brassDark.withValues(alpha: 0.55), 0.008),
      );
    }
    Kit.rrect(
      c,
      const Rect.fromLTWH(0.27, 0.15, 0.46, 0.08),
      0.03,
      Kit.fill(AppColors.paper),
    );
    Kit.rrect(
      c,
      const Rect.fromLTWH(0.27, 0.77, 0.46, 0.08),
      0.03,
      Kit.fill(AppColors.paper),
    );
    Kit.rrect(
      c,
      const Rect.fromLTWH(0.34, 0.42, 0.32, 0.16),
      0.01,
      Kit.fill(AppColors.paper),
    );
    Kit.text(c, '90', const Offset(0.5, 0.5), 0.1, AppColors.wood);
    c.drawCircle(
      const Offset(0.62, 0.7),
      0.03,
      Kit.fill(const Color(0x55000000)),
    );
  }

  void _cog(Canvas c) {
    const ctr = Offset(0.5, 0.5);
    final g = Kit.gear(ctr, 0.4, 12);
    c.drawPath(
      g.shift(const Offset(0.02, 0.03)),
      Kit.fill(const Color(0x66000000)),
    );
    c.drawPath(g, Kit.brassPaint(const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8)));
    c.drawPath(g, Kit.stroke(AppColors.goldLight, 0.012));
    c.drawCircle(ctr, 0.2, Kit.stroke(AppColors.brassDark, 0.02));
    c.drawCircle(ctr, 0.08, Kit.fill(AppColors.midnight));
    c.drawCircle(ctr, 0.08, Kit.stroke(AppColors.goldLight, 0.012));
  }

  void _crystal(Canvas c) {
    Kit.glow(c, const Offset(0.5, 0.5), 0.5, AppColors.moonCyan, 0.55);
    final outer = Path()
      ..moveTo(0.5, 0.06)
      ..lineTo(0.76, 0.3)
      ..lineTo(0.68, 0.8)
      ..lineTo(0.5, 0.94)
      ..lineTo(0.32, 0.8)
      ..lineTo(0.24, 0.3)
      ..close();
    c.drawPath(outer, Kit.fill(AppColors.deepPurple));
    c.drawPath(
      Path()
        ..moveTo(0.5, 0.06)
        ..lineTo(0.6, 0.35)
        ..lineTo(0.5, 0.94)
        ..lineTo(0.4, 0.35)
        ..close(),
      Kit.fill(AppColors.violetMist),
    );
    c.drawPath(
      Path()
        ..moveTo(0.5, 0.06)
        ..lineTo(0.76, 0.3)
        ..lineTo(0.6, 0.35)
        ..close(),
      Kit.fill(AppColors.moonCyan.withValues(alpha: 0.55)),
    );
    c.drawPath(outer, Kit.stroke(AppColors.moonCyan, 0.018));
    c.drawCircle(
      const Offset(0.5, 0.45),
      0.05,
      Kit.fill(const Color(0xFFE9FFFF)),
    );
  }

  @override
  bool shouldRepaint(_ItemPainter old) =>
      old.id != id || old.glow != glow || old.dimmed != dimmed;
}
