import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'paint_kit.dart';
import 'puzzle_art.dart';

/// Original illustrations for every interactive object, keyed by hotspot id.
///
/// Each painter fills the hotspot's rectangle, so what the player sees is
/// exactly what they can tap. A content test checks every hotspot has art.
abstract final class HotspotArt {
  static const Set<String> supported = {
    'h_front_door',
    'h_portrait',
    'h_candelabra',
    'h_tallow',
    'h_guest_table',
    'l_shelf',
    'l_hearth',
    'l_desk',
    'l_blotter',
    'l_ledger',
    'w_tuner',
    'w_horn',
    'w_cabinet',
    'w_bench',
    'w_phonograph',
    'c_clockface',
    'c_gears',
    'c_logbook',
    'c_tube',
    'v_engine',
    'v_echo',
    'v_mirrors',
  };

  static void paint(Canvas c, String id, Rect r, double t) {
    switch (id) {
      case 'h_front_door':
        _door(c, r, t);
      case 'h_portrait':
        _portrait(c, r);
      case 'h_candelabra':
        _candelabra(c, r, t);
      case 'h_tallow':
        _tallow(c, r, t);
      case 'h_guest_table':
        _table(c, r);
      case 'l_shelf':
        _cipherShelf(c, r);
      case 'l_hearth':
        _hearth(c, r, t);
      case 'l_desk':
        _desk(c, r, t);
      case 'l_blotter':
        _blotter(c, r);
      case 'l_ledger':
        _ledger(c, r);
      case 'w_tuner':
        _tuner(c, r, t);
      case 'w_horn':
        _horn(c, r, t);
      case 'w_cabinet':
        _cabinet(c, r);
      case 'w_bench':
        _bench(c, r, t);
      case 'w_phonograph':
        _phonograph(c, r);
      case 'c_clockface':
        _clockFace(c, r);
      case 'c_gears':
        _gearFrame(c, r);
      case 'c_logbook':
        _lectern(c, r);
      case 'c_tube':
        _tube(c, r, t);
      case 'v_engine':
        _engine(c, r, t);
      case 'v_echo':
        _echo(c, r, t);
      case 'v_mirrors':
        _mirrors(c, r, t);
      default:
        throw ArgumentError('No hotspot art for "$id".');
    }
  }

  // ------------------------------------------------------------ the hall

  static void _door(Canvas c, Rect r, double t) {
    final arch = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + r.width * 0.5)
      ..quadraticBezierTo(r.left, r.top, r.center.dx, r.top)
      ..quadraticBezierTo(r.right, r.top, r.right, r.top + r.width * 0.5)
      ..lineTo(r.right, r.bottom)
      ..close();
    c.drawPath(
      arch.shift(const Offset(3, 4)),
      Kit.fill(const Color(0x66000000)),
    );
    c.drawPath(arch, Kit.woodPaint(r));
    c.save();
    c.clipPath(arch);
    for (var i = 1; i < 5; i++) {
      final x = r.left + r.width * i / 5;
      c.drawLine(
        Offset(x, r.top),
        Offset(x, r.bottom),
        Kit.stroke(Colors.black.withValues(alpha: 0.45), 1.4),
      );
    }
    for (final y in [0.35, 0.72]) {
      c.drawRect(
        Rect.fromLTWH(r.left, r.top + r.height * y, r.width, r.height * 0.05),
        Kit.fill(const Color(0xFF1A1630)),
      );
    }
    // Frost creeping from the edges.
    Kit.glow(
      c,
      Offset(r.left, r.bottom),
      r.width * 0.9,
      const Color(0xFFE9FFFF),
      0.5,
    );
    Kit.glow(
      c,
      Offset(r.right, r.top + r.height * 0.3),
      r.width * 0.6,
      const Color(0xFFE9FFFF),
      0.3,
    );
    c.restore();
    c.drawPath(arch, Kit.stroke(AppColors.stoneLight, 5));
    // Ring handle and keyhole.
    final h = Offset(r.right - r.width * 0.22, r.top + r.height * 0.58);
    c.drawCircle(h, r.width * 0.08, Kit.stroke(AppColors.brass, 3));
    c.drawCircle(h.translate(0, r.width * 0.2), 4, Kit.fill(Colors.black));
    Kit.glow(
      c,
      h.translate(0, r.width * 0.2),
      14,
      AppColors.moonCyan,
      0.4 + 0.2 * math.sin(t * 2 * math.pi),
    );
  }

  static void _portrait(Canvas c, Rect r) {
    final frame = r;
    Kit.rrect(
      c,
      frame.shift(const Offset(3, 4)),
      4,
      Kit.fill(const Color(0x66000000)),
    );
    Kit.rrect(c, frame, 4, Kit.brassPaint(frame));
    final inner = frame.deflate(r.width * 0.1);
    Kit.rrect(
      c,
      inner,
      2,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B1B3F), Color(0xFF14102B)],
        ).createShader(inner),
    );
    // Painted bust.
    final cx = inner.center.dx;
    c.drawPath(
      Path()
        ..moveTo(inner.left, inner.bottom)
        ..quadraticBezierTo(
          inner.left + 2,
          inner.bottom - inner.height * 0.38,
          cx,
          inner.bottom - inner.height * 0.4,
        )
        ..quadraticBezierTo(
          inner.right - 2,
          inner.bottom - inner.height * 0.38,
          inner.right,
          inner.bottom,
        )
        ..close(),
      Kit.fill(const Color(0xFF5C3A2A)),
    );
    c.drawOval(
      Rect.fromCenter(
        center: Offset(cx, inner.top + inner.height * 0.38),
        width: inner.width * 0.46,
        height: inner.height * 0.34,
      ),
      Kit.fill(const Color(0xFFE2B99A)),
    );
    c.drawCircle(
      Offset(cx, inner.top + inner.height * 0.18),
      inner.width * 0.15,
      Kit.fill(const Color(0xFF3B2418)),
    );
    c.drawArc(
      Rect.fromCenter(
        center: Offset(cx, inner.top + inner.height * 0.34),
        width: inner.width * 0.5,
        height: inner.height * 0.34,
      ),
      math.pi,
      math.pi,
      false,
      Kit.stroke(const Color(0xFF3B2418), inner.width * 0.12),
    );
    for (final dx in [-0.1, 0.1]) {
      c.drawCircle(
        Offset(cx + inner.width * dx, inner.top + inner.height * 0.3),
        inner.width * 0.07,
        Kit.stroke(AppColors.brass, 1.6),
      );
    }
    // Plaque.
    final plaque = Rect.fromCenter(
      center: Offset(cx, r.bottom + 2),
      width: r.width * 0.62,
      height: r.height * 0.07,
    );
    Kit.rrect(c, plaque, 2, Kit.brassPaint(plaque));
    Kit.text(
      c,
      'LISTEN TWICE',
      plaque.center,
      // Sized to fit the plaque's width as well as its height.
      math.min(plaque.height * 0.55, plaque.width / 8.5),
      AppColors.wood,
      letterSpacing: 0.4,
    );
    // The brass key on a nail at the frame's corner.
    final k = Offset(r.right - 6, r.top + r.height * 0.1);
    c.drawCircle(k, 5, Kit.stroke(AppColors.goldLight, 2));
    c.drawLine(
      k.translate(0, 5),
      k.translate(0, 22),
      Kit.stroke(AppColors.goldLight, 2.4),
    );
    c.drawLine(
      k.translate(0, 18),
      k.translate(5, 18),
      Kit.stroke(AppColors.goldLight, 2),
    );
  }

  static void _candelabra(Canvas c, Rect r, double t) {
    final cx = r.center.dx;
    final base = r.bottom;
    final silver = Kit.fill(const Color(0xFFB9C3E0));
    Kit.rrect(
      c,
      Rect.fromCenter(
        center: Offset(cx, base - 4),
        width: r.width * 0.55,
        height: 8,
      ),
      3,
      silver,
    );
    c.drawLine(
      Offset(cx, base - 6),
      Offset(cx, r.top + r.height * 0.4),
      Kit.stroke(const Color(0xFFB9C3E0), 5),
    );
    final arms = Path()
      ..moveTo(r.left + 4, r.top + r.height * 0.42)
      ..quadraticBezierTo(
        r.left + 4,
        r.top + r.height * 0.7,
        cx,
        r.top + r.height * 0.7,
      )
      ..quadraticBezierTo(
        r.right - 4,
        r.top + r.height * 0.7,
        r.right - 4,
        r.top + r.height * 0.42,
      );
    c.drawPath(arms, Kit.stroke(const Color(0xFFB9C3E0), 3.5));
    const ids = ['crescent', 'half', 'full', 'waning'];
    for (var i = 0; i < 4; i++) {
      final x = r.left + 4 + (r.width - 8) * (i / 3);
      final top = r.top + r.height * (i == 1 || i == 2 ? 0.08 : 0.2);
      final candle = Rect.fromLTWH(
        x - 6,
        top + r.height * 0.18,
        12,
        r.height * 0.3,
      );
      Kit.rrect(c, candle, 2, Kit.fill(AppColors.paper));
      Sigils.paint(
        c,
        ids[i],
        Rect.fromCenter(
          center: candle.center.translate(0, 2),
          width: 9,
          height: 9,
        ),
        AppColors.deepPurple,
      );
      // Cold wick glint (unlit).
      final g = 0.5 + 0.5 * math.sin((t * 3 + i * 0.25) * 2 * math.pi);
      Kit.glow(c, Offset(x, candle.top - 3), 9, AppColors.moonCyan, 0.25 * g);
      c.drawCircle(
        Offset(x, candle.top - 1.5),
        1.6,
        Kit.fill(AppColors.moonCyan.withValues(alpha: 0.6)),
      );
    }
  }

  static void _tallow(Canvas c, Rect r, double t) {
    final cx = r.center.dx;
    final w = r.width;
    // Legs.
    for (final dx in [-0.18, 0.18]) {
      Kit.rrect(
        c,
        Rect.fromCenter(
          center: Offset(cx + w * dx, r.bottom - r.height * 0.1),
          width: w * 0.22,
          height: r.height * 0.2,
        ),
        3,
        Kit.fill(const Color(0xFF1B2040)),
      );
    }
    // Coat.
    final coat = Path()
      ..moveTo(cx - w * 0.5, r.bottom - r.height * 0.18)
      ..lineTo(cx - w * 0.38, r.top + r.height * 0.3)
      ..lineTo(cx + w * 0.38, r.top + r.height * 0.3)
      ..lineTo(cx + w * 0.5, r.bottom - r.height * 0.18)
      ..close();
    c.drawPath(coat, Kit.fill(const Color(0xFF2E3562)));
    c.drawLine(
      Offset(cx, r.top + r.height * 0.3),
      Offset(cx, r.bottom - r.height * 0.18),
      Kit.stroke(AppColors.antiqueGold.withValues(alpha: 0.7), 1.6),
    );
    for (var i = 0; i < 4; i++) {
      c.drawCircle(
        Offset(cx + w * 0.1, r.top + r.height * (0.4 + i * 0.1)),
        2,
        Kit.fill(AppColors.brass),
      );
    }
    // Chest window with a still gear.
    final win = Rect.fromCenter(
      center: Offset(cx - w * 0.14, r.top + r.height * 0.5),
      width: w * 0.22,
      height: w * 0.22,
    );
    c.drawOval(win, Kit.fill(AppColors.midnight));
    c.drawPath(
      Kit.gear(win.center, w * 0.08, 8),
      Kit.fill(AppColors.brassDark),
    );
    // Head.
    final head = Rect.fromCenter(
      center: Offset(cx, r.top + r.height * 0.17),
      width: w * 0.5,
      height: r.height * 0.24,
    );
    Kit.rrect(c, head, 8, Kit.brassPaint(head));
    final cap = Path()
      ..moveTo(head.left - 2, head.top + head.height * 0.2)
      ..quadraticBezierTo(
        cx,
        head.top - head.height * 0.5,
        head.right + 2,
        head.top + head.height * 0.2,
      )
      ..close();
    c.drawPath(cap, Kit.fill(const Color(0xFF232A55)));
    // Dormant eyes, faintly breathing.
    final b = 0.25 + 0.2 * math.sin(t * 2 * math.pi);
    for (final dx in [-0.12, 0.12]) {
      final e = Offset(cx + w * dx, head.center.dy + 2);
      c.drawCircle(e, 3.4, Kit.fill(AppColors.midnight));
      Kit.glow(c, e, 9, AppColors.moonCyan, b);
    }
    // Winding key slot on the shoulder.
    c.drawRect(
      Rect.fromCenter(
        center: Offset(cx + w * 0.3, r.top + r.height * 0.34),
        width: 8,
        height: 3,
      ),
      Kit.fill(Colors.black),
    );
  }

  static void _table(Canvas c, Rect r) {
    final top = Rect.fromLTWH(
      r.left,
      r.top + r.height * 0.45,
      r.width,
      r.height * 0.14,
    );
    Kit.rrect(c, top, 3, Kit.woodPaint(top));
    for (final x in [0.08, 0.84]) {
      c.drawRect(
        Rect.fromLTWH(
          r.left + r.width * x,
          top.bottom,
          r.width * 0.08,
          r.height * 0.4,
        ),
        Kit.fill(AppColors.wood),
      );
    }
    // Open ledger and a quill.
    final book = Rect.fromCenter(
      center: top.center.translate(-2, -top.height * 0.9),
      width: r.width * 0.55,
      height: r.height * 0.22,
    );
    Kit.rrect(c, book, 2, Kit.fill(AppColors.paper));
    c.drawLine(
      book.topCenter,
      book.bottomCenter,
      Kit.stroke(AppColors.paperDark, 1.4),
    );
    for (var i = 0; i < 3; i++) {
      final y = book.top + book.height * (0.25 + i * 0.22);
      c.drawLine(
        Offset(book.left + 4, y),
        Offset(book.center.dx - 4, y),
        Kit.stroke(AppColors.wood.withValues(alpha: 0.5), 1),
      );
    }
    c.drawLine(
      Offset(book.right - 6, book.top),
      Offset(r.right, r.top + r.height * 0.15),
      Kit.stroke(AppColors.paper, 2),
    );
    // Cold candle stub.
    Kit.rrect(
      c,
      Rect.fromLTWH(r.left + 4, top.top - r.height * 0.18, 7, r.height * 0.18),
      1,
      Kit.fill(AppColors.paper),
    );
  }

  // ----------------------------------------------------------- library

  static void _cipherShelf(Canvas c, Rect r) {
    Kit.rrect(c, r, 4, Kit.woodPaint(r));
    c.drawRect(r.deflate(r.width * 0.04), Kit.fill(const Color(0xFF0F0A1C)));
    final inner = r.deflate(r.width * 0.04);
    // Background rows of books.
    for (var row = 0; row < 3; row++) {
      final y = inner.top + inner.height * (row + 1) / 3;
      var x = inner.left;
      var i = row * 30;
      while (x < inner.right - 4) {
        final bw = inner.width * (0.04 + Kit.rand(i) * 0.03);
        final bh = inner.height * (0.18 + Kit.rand(i + 2) * 0.1);
        c.drawRect(
          Rect.fromLTWH(x, y - bh - 3, bw - 1, bh),
          Kit.fill(
            Color.lerp(
              const [
                AppColors.deepPurple,
                Color(0xFF5A1F2E),
                Color(0xFF1F4A44),
                AppColors.goldDeep,
              ][(Kit.rand(i + 5) * 4).floor()],
              Colors.black,
              0.3,
            )!,
          ),
        );
        x += bw;
        i++;
      }
      c.drawRect(
        Rect.fromLTWH(inner.left, y - 3, inner.width, 4),
        Kit.fill(AppColors.woodLight),
      );
    }
    // Six pulled-out books stamped with letters (the cipher clue).
    const letters = ['O', 'L', 'V', 'W', 'H', 'Q'];
    final bw = inner.width / 6.6;
    for (var i = 0; i < 6; i++) {
      final x = inner.left + inner.width * 0.04 + i * bw * 1.06;
      final pull = 4.0 + (i.isEven ? 6 : 0);
      final rect = Rect.fromLTWH(
        x - pull * 0.3,
        inner.top + inner.height * 0.12 + pull,
        bw - 3,
        inner.height * 0.68,
      );
      Kit.rrect(
        c,
        rect.shift(const Offset(2, 3)),
        3,
        Kit.fill(const Color(0x66000000)),
      );
      Kit.rrect(
        c,
        rect,
        3,
        Kit.fill(
          Color.lerp(AppColors.deepPurple, AppColors.violetMist, i / 6)!,
        ),
      );
      Kit.rrect(
        c,
        rect.deflate(3),
        2,
        Kit.stroke(AppColors.goldLight.withValues(alpha: 0.7), 1.2),
      );
      Kit.text(
        c,
        letters[i],
        rect.center.translate(0, -rect.height * 0.1),
        rect.width * 0.62,
        AppColors.goldLight,
      );
    }
  }

  static void _hearth(Canvas c, Rect r, double t) {
    Kit.rrect(c, r, 4, Kit.fill(AppColors.stoneLight));
    for (var i = 0; i < 4; i++) {
      c.drawLine(
        Offset(r.left, r.top + r.height * i / 4),
        Offset(r.right, r.top + r.height * i / 4),
        Kit.stroke(Colors.black.withValues(alpha: 0.3), 1.2),
      );
    }
    Kit.rrect(
      c,
      Rect.fromLTWH(r.left - 6, r.top - 5, r.width + 12, r.height * 0.12),
      3,
      Kit.woodPaint(r),
    );
    final open = Rect.fromLTWH(
      r.left + r.width * 0.16,
      r.top + r.height * 0.28,
      r.width * 0.68,
      r.height * 0.72,
    );
    c.drawPath(
      Path()
        ..moveTo(open.left, open.bottom)
        ..lineTo(open.left, open.top + open.height * 0.3)
        ..quadraticBezierTo(
          open.center.dx,
          open.top - open.height * 0.2,
          open.right,
          open.top + open.height * 0.3,
        )
        ..lineTo(open.right, open.bottom)
        ..close(),
      Kit.fill(const Color(0xFF05040C)),
    );
    // Ash mound and a charred scrap of paper.
    c.drawOval(
      Rect.fromLTWH(
        open.left + 4,
        open.bottom - open.height * 0.2,
        open.width - 8,
        open.height * 0.2,
      ),
      Kit.fill(const Color(0xFF3A3A4A)),
    );
    c.drawPath(
      Path()
        ..moveTo(open.center.dx - 8, open.bottom - open.height * 0.2)
        ..lineTo(open.center.dx + 4, open.bottom - open.height * 0.28)
        ..lineTo(open.center.dx + 12, open.bottom - open.height * 0.18)
        ..close(),
      Kit.fill(AppColors.paperDark),
    );
    // A last thread of cold smoke.
    final f = (t * 2) % 1.0;
    Kit.glow(
      c,
      Offset(
        open.center.dx + math.sin(f * 6) * 6,
        open.bottom - open.height * (0.25 + f * 0.4),
      ),
      14,
      AppColors.fog,
      0.2 * (1 - f),
    );
  }

  static void _desk(Canvas c, Rect r, double t) {
    final top = Rect.fromLTWH(
      r.left,
      r.top + r.height * 0.4,
      r.width,
      r.height * 0.16,
    );
    Kit.rrect(c, top, 3, Kit.woodPaint(top));
    c.drawRect(
      Rect.fromLTWH(
        r.left + r.width * 0.06,
        top.bottom,
        r.width * 0.1,
        r.height * 0.44,
      ),
      Kit.fill(AppColors.wood),
    );
    c.drawRect(
      Rect.fromLTWH(
        r.right - r.width * 0.16,
        top.bottom,
        r.width * 0.1,
        r.height * 0.44,
      ),
      Kit.fill(AppColors.wood),
    );
    // Green glass lamp, glowing.
    final lamp = Offset(r.left + r.width * 0.2, top.top);
    final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi * 2);
    Kit.glow(
      c,
      lamp.translate(0, -r.height * 0.15),
      r.width * 0.5,
      AppColors.ghostGreen,
      0.28 * pulse,
    );
    c.drawLine(
      lamp,
      lamp.translate(0, -r.height * 0.22),
      Kit.stroke(AppColors.brass, 3),
    );
    c.drawPath(
      Path()
        ..moveTo(lamp.dx - r.width * 0.12, lamp.dy - r.height * 0.2)
        ..lineTo(lamp.dx + r.width * 0.12, lamp.dy - r.height * 0.2)
        ..lineTo(lamp.dx + r.width * 0.06, lamp.dy - r.height * 0.34)
        ..lineTo(lamp.dx - r.width * 0.06, lamp.dy - r.height * 0.34)
        ..close(),
      Kit.fill(AppColors.verdigris),
    );
    // Open journal with an underlined last entry.
    final book = Rect.fromCenter(
      center: Offset(r.center.dx + r.width * 0.12, top.top - r.height * 0.07),
      width: r.width * 0.42,
      height: r.height * 0.14,
    );
    Kit.rrect(c, book, 2, Kit.fill(AppColors.paper));
    c.drawLine(
      book.topCenter,
      book.bottomCenter,
      Kit.stroke(AppColors.paperDark, 1.4),
    );
    c.drawLine(
      Offset(book.left + 5, book.bottom - 6),
      Offset(book.center.dx - 5, book.bottom - 6),
      Kit.stroke(AppColors.danger, 1.6),
    );
    c.drawLine(
      Offset(book.left + 5, book.bottom - 4),
      Offset(book.center.dx - 5, book.bottom - 4),
      Kit.stroke(AppColors.danger, 1.6),
    );
    // Inkwell.
    c.drawCircle(
      Offset(r.right - r.width * 0.1, top.top - 5),
      5,
      Kit.fill(AppColors.midnight),
    );
  }

  static void _blotter(Canvas c, Rect r) {
    Kit.rrect(c, r, 4, Kit.fill(const Color(0xFF1F4A44)));
    Kit.rrect(c, r.deflate(3), 3, Kit.stroke(AppColors.goldDeep, 1.2));
    for (final x in [0.1, 0.54]) {
      final slot = Rect.fromLTWH(
        r.left + r.width * x,
        r.top + r.height * 0.2,
        r.width * 0.36,
        r.height * 0.6,
      );
      Kit.rrect(c, slot, 2, Kit.fill(AppColors.paper.withValues(alpha: 0.18)));
      Kit.rrect(
        c,
        slot,
        2,
        Kit.stroke(AppColors.paper.withValues(alpha: 0.55), 1.2),
      );
    }
    for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      c.drawCircle(
        Offset(
          corner.dx + (corner.dx == r.left ? 5 : -5),
          corner.dy + (corner.dy == r.top ? 5 : -5),
        ),
        2,
        Kit.fill(AppColors.brass),
      );
    }
  }

  static void _ledger(Canvas c, Rect r) {
    Kit.rrect(
      c,
      r.shift(const Offset(2, 3)),
      3,
      Kit.fill(const Color(0x66000000)),
    );
    Kit.rrect(c, r, 3, Kit.fill(const Color(0xFF4A1523)));
    Kit.rrect(c, r.deflate(4), 2, Kit.stroke(AppColors.antiqueGold, 1.2));
    c.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width * 0.1, r.height),
      Kit.fill(const Color(0xFF2E0C16)),
    );
    Kit.text(
      c,
      'E.M.',
      r.center.translate(r.width * 0.05, 0),
      r.height * 0.3,
      AppColors.goldLight,
    );
    c.drawLine(
      Offset(r.right - 10, r.bottom),
      Offset(r.right - 10, r.bottom + 10),
      Kit.stroke(AppColors.danger, 3),
    );
  }

  // ---------------------------------------------------------- workshop

  static void _tuner(Canvas c, Rect r, double t) {
    final center = r.center;
    final rad = r.shortestSide / 2;
    c.drawCircle(center, rad, Kit.brassPaint(r));
    c.drawCircle(center, rad * 0.84, Kit.fill(const Color(0xFF0E1230)));
    for (var i = 0; i <= 10; i++) {
      final a = math.pi * 0.75 + math.pi * 1.5 * i / 10;
      c.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * rad * 0.62,
        center + Offset(math.cos(a), math.sin(a)) * rad * 0.78,
        Kit.stroke(AppColors.goldLight, i % 5 == 0 ? 2.4 : 1.2),
      );
    }
    // The needle trembles while waiting for a number.
    final a = math.pi * 0.75 + 0.02 + 0.05 * math.sin(t * 2 * math.pi * 9);
    c.drawLine(
      center,
      center + Offset(math.cos(a), math.sin(a)) * rad * 0.66,
      Kit.stroke(AppColors.ghostGreen, 3),
    );
    c.drawCircle(center, rad * 0.08, Kit.fill(AppColors.brass));
    for (final dx in [-1.0, 1.0]) {
      c.drawCircle(
        center + Offset(dx * rad * 0.92, 0),
        2.2,
        Kit.fill(AppColors.brassDark),
      );
    }
  }

  static void _horn(Canvas c, Rect r, double t) {
    final cone = Path()
      ..moveTo(r.left + r.width * 0.1, r.center.dy - r.height * 0.1)
      ..lineTo(r.right, r.top)
      ..quadraticBezierTo(
        r.right + r.width * 0.1,
        r.center.dy,
        r.right,
        r.bottom,
      )
      ..lineTo(r.left + r.width * 0.1, r.center.dy + r.height * 0.1)
      ..close();
    c.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            AppColors.brassDark,
            AppColors.copper,
            AppColors.goldLight,
            AppColors.copper,
          ],
        ).createShader(r),
    );
    final mouth = Rect.fromCenter(
      center: Offset(r.right - 2, r.center.dy),
      width: r.width * 0.2,
      height: r.height,
    );
    c.drawOval(mouth, Kit.fill(const Color(0xFF031014)));
    c.drawOval(mouth, Kit.stroke(AppColors.goldLight, 2));
    // Something breathes inside.
    Kit.glow(
      c,
      mouth.center,
      r.height * 0.5,
      AppColors.ghostGreen,
      0.3 + 0.25 * math.sin(t * 2 * math.pi * 2),
    );
    for (final x in [0.25, 0.7]) {
      c.drawRect(
        Rect.fromLTWH(r.left + r.width * x, r.top - 4, 5, r.height + 8),
        Kit.fill(AppColors.brassDark),
      );
    }
  }

  static void _cabinet(Canvas c, Rect r) {
    Kit.rrect(c, r, 4, Kit.fill(const Color(0xFF29383A)));
    for (final left in [true, false]) {
      final door = Rect.fromLTWH(
        left ? r.left + 4 : r.center.dx + 1,
        r.top + 4,
        r.width / 2 - 5,
        r.height - 8,
      );
      Kit.rrect(c, door, 3, Kit.fill(const Color(0xFF34494A)));
      Kit.rrect(
        c,
        door.deflate(6),
        2,
        Kit.stroke(Colors.black.withValues(alpha: 0.4), 1.4),
      );
    }
    // Verdigris crusts, heaviest around the lock.
    for (var i = 0; i < 16; i++) {
      final p = Offset(
        r.left + Kit.rand(i) * r.width,
        r.top + Kit.rand(i + 20) * r.height,
      );
      c.drawCircle(
        p,
        3 + Kit.rand(i + 40) * 8,
        Kit.fill(AppColors.verdigris.withValues(alpha: 0.45)),
      );
    }
    final lock = r.center;
    Kit.glow(c, lock, r.width * 0.3, AppColors.verdigris, 0.7);
    c.drawCircle(lock, r.width * 0.09, Kit.fill(AppColors.verdigris));
    c.drawCircle(lock, r.width * 0.09, Kit.stroke(const Color(0xFF1F5A4A), 2));
    for (final y in [0.2, 0.8]) {
      c.drawRect(
        Rect.fromLTWH(r.left, r.top + r.height * y, r.width, 5),
        Kit.fill(AppColors.brassDark),
      );
    }
  }

  static void _bench(Canvas c, Rect r, double t) {
    final top = Rect.fromLTWH(
      r.left,
      r.top + r.height * 0.55,
      r.width,
      r.height * 0.14,
    );
    Kit.rrect(c, top, 3, Kit.woodPaint(top));
    for (final x in [0.06, 0.86]) {
      c.drawRect(
        Rect.fromLTWH(
          r.left + r.width * x,
          top.bottom,
          r.width * 0.08,
          r.height * 0.31,
        ),
        Kit.fill(AppColors.wood),
      );
    }
    const colors = [
      AppColors.ghostGreen,
      AppColors.ember,
      AppColors.moonCyan,
      Color(0xFFB48CFF),
    ];
    for (var i = 0; i < 4; i++) {
      final cx = r.left + r.width * (0.16 + i * 0.22);
      final h = r.height * (0.26 + (i % 2) * 0.1);
      final flask = Path()
        ..moveTo(cx - 3, top.top - h)
        ..lineTo(cx + 3, top.top - h)
        ..lineTo(cx + 3, top.top - h * 0.65)
        ..quadraticBezierTo(cx + 15, top.top - h * 0.3, cx + 11, top.top)
        ..lineTo(cx - 11, top.top)
        ..quadraticBezierTo(
          cx - 15,
          top.top - h * 0.3,
          cx - 3,
          top.top - h * 0.65,
        )
        ..close();
      Kit.glow(c, Offset(cx, top.top - h * 0.3), 26, colors[i], 0.35);
      c.drawPath(flask, Kit.fill(colors[i].withValues(alpha: 0.4)));
      c.drawPath(
        flask,
        Kit.stroke(AppColors.parchment.withValues(alpha: 0.75), 1.6),
      );
      final f = (t * 2 + i / 4) % 1.0;
      c.drawCircle(
        Offset(cx + math.sin(f * 8 + i) * 3, top.top - h * 0.2 - f * h * 0.35),
        1.8,
        Kit.fill(colors[i].withValues(alpha: 0.9 * (1 - f))),
      );
    }
  }

  static void _phonograph(Canvas c, Rect r) {
    final box = Rect.fromLTWH(
      r.left,
      r.top + r.height * 0.6,
      r.width * 0.85,
      r.height * 0.4,
    );
    Kit.rrect(c, box, 4, Kit.woodPaint(box));
    c.drawOval(
      Rect.fromLTWH(box.left + 6, box.top - 4, box.width - 12, 10),
      Kit.fill(AppColors.midnight),
    );
    c.drawLine(
      Offset(box.center.dx, box.top),
      Offset(box.center.dx, box.top - r.height * 0.1),
      Kit.stroke(AppColors.brass, 2.4),
    );
    // Lily-shaped horn.
    final horn = Path()
      ..moveTo(box.center.dx, box.top - r.height * 0.1)
      ..quadraticBezierTo(r.right, r.top + r.height * 0.4, r.right - 2, r.top)
      ..quadraticBezierTo(
        r.center.dx,
        r.top + r.height * 0.1,
        box.center.dx - 4,
        box.top - r.height * 0.12,
      )
      ..close();
    c.drawPath(horn, Kit.brassPaint(r));
    c.drawPath(horn, Kit.stroke(AppColors.goldLight, 1.4));
    c.drawCircle(
      Offset(box.right - 10, box.center.dy),
      4,
      Kit.stroke(AppColors.brass, 2),
    );
  }

  // -------------------------------------------------------- clocktower

  static void _clockFace(Canvas c, Rect r) {
    final center = r.center;
    final rad = r.shortestSide / 2;
    Kit.glow(c, center, rad * 1.3, AppColors.antiqueGold, 0.3);
    c.drawCircle(center, rad, Kit.brassPaint(r));
    c.drawCircle(center, rad * 0.88, Kit.fill(const Color(0xFF14122E)));
    c.drawCircle(center, rad * 0.88, Kit.stroke(AppColors.brassDark, 3));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      c.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * rad * 0.72,
        center + Offset(math.cos(a), math.sin(a)) * rad * 0.82,
        Kit.stroke(AppColors.goldLight, i % 3 == 0 ? 3.4 : 1.8),
      );
    }
    // Hands drooping at the wrong hour.
    c.drawLine(
      center,
      center + Offset(-rad * 0.22, rad * 0.4),
      Kit.stroke(AppColors.goldLight, 6),
    );
    c.drawLine(
      center,
      center + Offset(rad * 0.18, rad * 0.62),
      Kit.stroke(AppColors.moonCyan, 4),
    );
    c.drawCircle(center, rad * 0.06, Kit.fill(AppColors.brass));
    // Setting lever on the side.
    c.drawLine(
      center + Offset(rad * 0.95, 0),
      center + Offset(rad * 1.12, -rad * 0.12),
      Kit.stroke(AppColors.brass, 5),
    );
    c.drawCircle(
      center + Offset(rad * 1.12, -rad * 0.12),
      6,
      Kit.fill(AppColors.goldLight),
    );
  }

  static void _gearFrame(Canvas c, Rect r) {
    Kit.rrect(c, r, 4, Kit.fill(const Color(0xFF14102B)));
    Kit.rrect(c, r, 4, Kit.stroke(AppColors.brassDark, 3));
    // Three gears side by side: never wider than a sixth of the frame.
    final rad = math.min(r.height * 0.28, r.width * 0.15);
    final centers = [
      Offset(r.left + r.width * 0.22, r.center.dy),
      Offset(r.left + r.width * 0.5, r.center.dy - rad * 0.2),
      Offset(r.left + r.width * 0.78, r.center.dy),
    ];
    for (var i = 0; i < 3; i++) {
      final isEmpty = i == 1;
      if (isEmpty) {
        // The empty socket where the spare cog belongs.
        final dash = Kit.stroke(AppColors.moonCyan.withValues(alpha: 0.7), 2);
        for (var k = 0; k < 12; k++) {
          final a = k * math.pi / 6;
          c.drawArc(
            Rect.fromCircle(center: centers[i], radius: rad),
            a,
            math.pi / 12,
            false,
            dash,
          );
        }
        c.drawCircle(centers[i], rad * 0.1, Kit.fill(AppColors.brass));
      } else {
        final g = Kit.gear(centers[i], rad, 10, rotation: i * 0.2);
        c.drawPath(
          g,
          Kit.brassPaint(Rect.fromCircle(center: centers[i], radius: rad)),
        );
        c.drawPath(g, Kit.stroke(AppColors.goldLight, 1.2));
        c.drawCircle(centers[i], rad * 0.45, Kit.fill(const Color(0xFF14102B)));
        c.drawCircle(centers[i], rad * 0.1, Kit.fill(AppColors.brass));
      }
    }
  }

  static void _lectern(Canvas c, Rect r) {
    final stand = Path()
      ..moveTo(r.center.dx - r.width * 0.15, r.bottom)
      ..lineTo(r.center.dx - r.width * 0.08, r.top + r.height * 0.45)
      ..lineTo(r.center.dx + r.width * 0.08, r.top + r.height * 0.45)
      ..lineTo(r.center.dx + r.width * 0.15, r.bottom)
      ..close();
    c.drawPath(stand, Kit.woodPaint(r));
    final slope = Path()
      ..moveTo(r.left, r.top + r.height * 0.5)
      ..lineTo(r.left + r.width * 0.12, r.top + r.height * 0.2)
      ..lineTo(r.right - r.width * 0.12, r.top + r.height * 0.2)
      ..lineTo(r.right, r.top + r.height * 0.5)
      ..close();
    c.drawPath(slope, Kit.woodPaint(r));
    final book = Rect.fromLTWH(
      r.left + r.width * 0.14,
      r.top + r.height * 0.12,
      r.width * 0.72,
      r.height * 0.34,
    );
    Kit.rrect(c, book, 2, Kit.fill(AppColors.paper));
    c.drawLine(
      book.topCenter,
      book.bottomCenter,
      Kit.stroke(AppColors.paperDark, 1.6),
    );
    for (var i = 0; i < 3; i++) {
      c.drawLine(
        Offset(book.left + 5, book.top + 8 + i * 7),
        Offset(book.center.dx - 5, book.top + 8 + i * 7),
        Kit.stroke(AppColors.wood.withValues(alpha: 0.5), 1),
      );
    }
    c.drawLine(
      book.center,
      book.center.translate(4, book.height * 0.65),
      Kit.stroke(AppColors.danger, 2.4),
    );
  }

  static void _tube(Canvas c, Rect r, double t) {
    final path = Path()
      ..moveTo(r.center.dx, r.bottom)
      ..lineTo(r.center.dx, r.top + r.height * 0.35)
      ..quadraticBezierTo(
        r.center.dx,
        r.top + r.height * 0.1,
        r.left,
        r.top + r.height * 0.1,
      );
    c.drawPath(path, Kit.stroke(AppColors.brassDark, r.width * 0.35));
    c.drawPath(path, Kit.stroke(AppColors.brass, r.width * 0.25));
    c.drawPath(
      path,
      Kit.stroke(AppColors.goldLight.withValues(alpha: 0.5), r.width * 0.06),
    );
    final bell = Rect.fromCenter(
      center: Offset(r.left, r.top + r.height * 0.1),
      width: r.width * 0.6,
      height: r.height * 0.22,
    );
    c.drawOval(bell, Kit.fill(const Color(0xFF05040C)));
    c.drawOval(bell, Kit.stroke(AppColors.goldLight, 2));
    // A faint violet whisper curls out of the mouth.
    final f = 0.5 + 0.5 * math.sin((t * 3) * 2 * math.pi);
    Kit.glow(
      c,
      bell.center.translate(-6, 0),
      r.width * 1.2,
      const Color(0xFFB48CFF),
      0.2 + 0.25 * f,
    );
    for (final y in [0.45, 0.8]) {
      c.drawRect(
        Rect.fromLTWH(
          r.center.dx - r.width * 0.28,
          r.top + r.height * y,
          r.width * 0.56,
          4,
        ),
        Kit.fill(AppColors.brassDark),
      );
    }
  }

  // ------------------------------------------------------------- vault

  static void _engine(Canvas c, Rect r, double t) {
    final cx = r.center.dx;
    final baseY = r.bottom - r.height * 0.1;
    final basin = Rect.fromCenter(
      center: Offset(cx, baseY),
      width: r.width,
      height: r.height * 0.2,
    );
    c.drawOval(basin, Kit.fill(const Color(0xFF1B1440)));
    c.drawOval(basin, Kit.stroke(AppColors.copper, 4));
    c.drawOval(basin.deflate(10), Kit.stroke(AppColors.violetMist, 2));
    // Four pillars: tide, ember, gale, stone.
    const ids = ['tide', 'ember', 'gale', 'stone'];
    const colors = [
      AppColors.moonCyan,
      AppColors.ember,
      AppColors.ghostGreen,
      Color(0xFFB8B8D0),
    ];
    for (var i = 0; i < 4; i++) {
      final x = r.left + r.width * (0.12 + i * 0.253);
      final h = r.height * (0.5 + 0.06 * (i % 2));
      final pillar = Rect.fromLTWH(
        x - r.width * 0.055,
        baseY - h,
        r.width * 0.11,
        h,
      );
      Kit.rrect(c, pillar, 5, Kit.fill(const Color(0xFF2A2250)));
      Kit.rrect(c, pillar, 5, Kit.stroke(colors[i].withValues(alpha: 0.7), 2));
      Kit.glow(
        c,
        pillar.topCenter.translate(0, 14),
        r.width * 0.12,
        colors[i],
        0.4,
      );
      Sigils.paint(
        c,
        ids[i],
        Rect.fromCenter(
          center: pillar.topCenter.translate(0, 18),
          width: r.width * 0.09,
          height: r.width * 0.09,
        ),
        colors[i],
      );
    }
    // Empty cradle, slowly pulsing, waiting for the core.
    final cradle = Offset(cx, r.top + r.height * 0.34);
    c.drawArc(
      Rect.fromCenter(
        center: cradle,
        width: r.width * 0.26,
        height: r.height * 0.14,
      ),
      0,
      math.pi,
      false,
      Kit.stroke(AppColors.copper, 4),
    );
    Kit.glow(
      c,
      cradle.translate(0, -6),
      r.width * 0.16,
      AppColors.moonCyan,
      0.2 + 0.15 * math.sin(t * 2 * math.pi * 2),
    );
    // Orbiting ring.
    c.drawOval(
      Rect.fromCenter(
        center: cradle.translate(0, -4),
        width: r.width * 0.5,
        height: r.height * 0.12,
      ),
      Kit.stroke(AppColors.goldDeep.withValues(alpha: 0.7), 2),
    );
  }

  static void _echo(Canvas c, Rect r, double t) {
    final ctr = r.center;
    for (var i = 0; i < 4; i++) {
      final f = (t * 2 + i / 4) % 1.0;
      c.drawCircle(
        ctr,
        r.shortestSide * (0.15 + f * 0.4),
        Kit.stroke(AppColors.moonCyan.withValues(alpha: 0.5 * (1 - f)), 1.6),
      );
    }
    Kit.glow(c, ctr, r.shortestSide * 0.6, const Color(0xFFE9FFFF), 0.4);
    c.drawPath(
      Path()
        ..moveTo(ctr.dx - r.width * 0.12, ctr.dy - r.height * 0.1)
        ..quadraticBezierTo(
          ctr.dx,
          ctr.dy - r.height * 0.34,
          ctr.dx + r.width * 0.12,
          ctr.dy - r.height * 0.1,
        )
        ..quadraticBezierTo(
          ctr.dx + r.width * 0.14,
          ctr.dy + r.height * 0.2,
          ctr.dx,
          ctr.dy + r.height * 0.32,
        )
        ..quadraticBezierTo(
          ctr.dx - r.width * 0.14,
          ctr.dy + r.height * 0.2,
          ctr.dx - r.width * 0.12,
          ctr.dy - r.height * 0.1,
        )
        ..close(),
      Kit.fill(Colors.white.withValues(alpha: 0.18)),
    );
  }

  static void _mirrors(Canvas c, Rect r, double t) {
    Kit.rrect(
      c,
      r,
      8,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2A78), Color(0xFF120A2A), Color(0xFF2B4A78)],
        ).createShader(r),
    );
    Kit.rrect(c, r, 8, Kit.stroke(AppColors.stoneLight, 5));
    // Your reflection, a moment late; and someone standing behind it.
    final lag = math.sin(t * 2 * math.pi * 2) * r.width * 0.06;
    final me = Offset(r.center.dx + lag, r.bottom - r.height * 0.28);
    c.drawOval(
      Rect.fromCenter(
        center: me.translate(0, -r.height * 0.14),
        width: r.width * 0.3,
        height: r.width * 0.34,
      ),
      Kit.fill(AppColors.midnight.withValues(alpha: 0.75)),
    );
    c.drawPath(
      Path()
        ..moveTo(me.dx - r.width * 0.3, r.bottom)
        ..quadraticBezierTo(
          me.dx - r.width * 0.28,
          me.dy - r.height * 0.06,
          me.dx,
          me.dy - r.height * 0.06,
        )
        ..quadraticBezierTo(
          me.dx + r.width * 0.28,
          me.dy - r.height * 0.06,
          me.dx + r.width * 0.3,
          r.bottom,
        )
        ..close(),
      Kit.fill(AppColors.midnight.withValues(alpha: 0.75)),
    );
    final other = Offset(r.left + r.width * 0.3, r.top + r.height * 0.32);
    c.drawOval(
      Rect.fromCenter(
        center: other,
        width: r.width * 0.16,
        height: r.width * 0.2,
      ),
      Kit.fill(const Color(0xFF05040C).withValues(alpha: 0.6)),
    );
    Kit.glow(c, other, 10, const Color(0xFFB48CFF), 0.4);
    c.drawLine(
      r.topLeft.translate(12, 14),
      r.topLeft.translate(r.width * 0.45, r.height * 0.3),
      Kit.stroke(Colors.white.withValues(alpha: 0.18), 3),
    );
  }
}
