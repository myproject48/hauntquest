import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/motion_policy.dart';
import '../theme/app_colors.dart';
import '../widgets/fog_layer.dart';
import '../widgets/grain_overlay.dart';
import 'paint_kit.dart';

/// The manor seen from the gate at night, built from parallax layers: sky and
/// moon, far hills, the house, near fence and tree, and two fog bands between.
///
/// Drag or tilt-free pointer movement shifts the layers slightly. With reduced
/// motion the scene is still and the layers do not shift.
class ExteriorScene extends StatefulWidget {
  const ExteriorScene({super.key, this.reveal});

  /// Optional 0 to 1 intro value: the moon rises and the house fades in.
  final Animation<double>? reveal;

  @override
  State<ExteriorScene> createState() => _ExteriorSceneState();
}

class _ExteriorSceneState extends State<ExteriorScene>
    with TickerProviderStateMixin {
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  final ValueNotifier<Offset> _parallax = ValueNotifier(Offset.zero);
  Offset _from = Offset.zero;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      _parallax.value = Offset.lerp(
        _from,
        Offset.zero,
        Curves.easeOutCubic.transform(_settle.value),
      )!;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MotionPolicy.reduceOf(context);
    if (_reduce) {
      _time.stop();
      _parallax.value = Offset.zero;
    } else if (!_time.isAnimating) {
      _time.repeat();
    }
  }

  @override
  void dispose() {
    _time.dispose();
    _settle.dispose();
    _parallax.dispose();
    super.dispose();
  }

  void _onPan(DragUpdateDetails d, Size size) {
    if (_reduce) return;
    final next =
        _parallax.value +
        Offset(d.delta.dx / size.width * 2.2, d.delta.dy / size.height * 2.2);
    _parallax.value = Offset(next.dx.clamp(-1, 1), next.dy.clamp(-1, 1));
  }

  void _onPanEnd() {
    _from = _parallax.value;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reveal = widget.reveal ?? const AlwaysStoppedAnimation(1.0);
    final repaint = Listenable.merge([_time, _parallax, reveal]);

    Widget layer(_Layer l) => RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ExteriorPainter(
          layer: l,
          time: _time,
          parallax: _parallax,
          reveal: reveal,
          repaint: repaint,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (d) => _onPan(d, box.biggest),
        onPanEnd: (_) => _onPanEnd(),
        onPanCancel: _onPanEnd,
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              layer(_Layer.sky),
              layer(_Layer.hills),
              const FogLayer(density: 0.8, verticalBias: 0.62, seed: 2),
              layer(_Layer.house),
              const FogLayer(
                density: 1.1,
                verticalBias: 0.8,
                speed: 1.6,
                seed: 7,
              ),
              layer(_Layer.foreground),
              const GrainOverlay(vignette: 0.6),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Layer { sky, hills, house, foreground }

class _ExteriorPainter extends CustomPainter {
  _ExteriorPainter({
    required this.layer,
    required this.time,
    required this.parallax,
    required this.reveal,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _Layer layer;
  final Animation<double> time;
  final ValueNotifier<Offset> parallax;
  final Animation<double> reveal;

  static const _depth = {
    _Layer.sky: 0.2,
    _Layer.hills: 0.5,
    _Layer.house: 1.0,
    _Layer.foreground: 2.0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = parallax.value;
    final d = _depth[layer]!;
    canvas.save();
    canvas.translate(-p.dx * 12 * d, -p.dy * 6 * d);
    switch (layer) {
      case _Layer.sky:
        _sky(canvas, size);
      case _Layer.hills:
        _hills(canvas, size);
      case _Layer.house:
        _house(canvas, size);
      case _Layer.foreground:
        _foreground(canvas, size);
    }
    canvas.restore();
  }

  double get _t => time.value;
  double get _r => Curves.easeOutCubic.transform(reveal.value.clamp(0, 1));

  void _sky(Canvas canvas, Size s) {
    // Oversized so parallax never shows the edge.
    final r = Rect.fromLTWH(-20, -20, s.width + 40, s.height + 40);
    Kit.vGradient(
      canvas,
      r,
      const [
        AppColors.midnight,
        AppColors.navy,
        AppColors.deepPurple,
        Color(0xFF3A1F6B),
      ],
      const [0, 0.45, 0.8, 1],
    );

    // Stars.
    final star = Paint();
    for (var i = 0; i < 90; i++) {
      final x = Kit.rand(i * 3 + 1) * s.width;
      final y = Kit.rand(i * 3 + 2) * s.height * 0.62;
      final tw = 0.5 + 0.5 * math.sin((_t * 3 + Kit.rand(i)) * 2 * math.pi);
      star.color = AppColors.moonCyan.withValues(alpha: (0.15 + 0.6 * tw) * _r);
      canvas.drawCircle(Offset(x, y), 0.6 + Kit.rand(i * 7) * 1.3, star);
    }

    // Moon rises into place.
    // Kept below the menu title and to the right of the splash title.
    final rise = (1 - _r) * s.height * 0.18;
    final moon = Offset(s.width * 0.76, s.height * 0.27 + rise);
    final mr = math.min(s.width, s.height) * 0.085;
    final pulse = 0.88 + 0.12 * math.sin(_t * 2 * math.pi * 2);
    Kit.glow(canvas, moon, mr * 5, AppColors.moonCyan, 0.28 * pulse * _r);
    Kit.glow(canvas, moon, mr * 2.2, AppColors.moonCyan, 0.35 * _r);
    canvas.drawCircle(moon, mr, Kit.fill(const Color(0xFFE9FFFF)));
    final crater = Kit.fill(AppColors.cyanDeep.withValues(alpha: 0.28));
    canvas.drawCircle(moon.translate(-mr * 0.3, -mr * 0.2), mr * 0.2, crater);
    canvas.drawCircle(moon.translate(mr * 0.28, mr * 0.28), mr * 0.26, crater);
    canvas.drawCircle(moon.translate(mr * 0.1, -mr * 0.5), mr * 0.12, crater);

    // Thin clouds crossing the moon.
    for (var i = 0; i < 3; i++) {
      final cx = ((_t * (0.4 + i * 0.2) + i * 0.33) % 1.4 - 0.2) * s.width;
      final cy = moon.dy + (i - 1) * mr * 0.9;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: s.width * 0.5,
          height: mr * 0.5,
        ),
        Kit.fill(AppColors.deepPurple.withValues(alpha: 0.35 * _r)),
      );
    }

    // A few bats drifting across the moonlight.
    for (var i = 0; i < 3; i++) {
      final f = (_t * (0.8 + i * 0.25) + i * 0.31) % 1.0;
      final bx = f * (s.width + 80) - 40;
      final by = s.height * (0.12 + i * 0.05) + math.sin(f * 14 + i) * 8;
      final flap = math.sin(_t * 2 * math.pi * 40 + i);
      _bat(canvas, Offset(bx, by), 7 + i * 1.5, flap, _r);
    }
  }

  void _bat(Canvas c, Offset at, double w, double flap, double a) {
    final wing = w * (0.35 + 0.35 * flap);
    c.drawPath(
      Path()
        ..moveTo(at.dx, at.dy)
        ..quadraticBezierTo(
          at.dx - w * 0.5,
          at.dy - wing,
          at.dx - w,
          at.dy + wing * 0.2,
        )
        ..quadraticBezierTo(
          at.dx - w * 0.5,
          at.dy + wing * 0.1,
          at.dx,
          at.dy + w * 0.2,
        )
        ..quadraticBezierTo(
          at.dx + w * 0.5,
          at.dy + wing * 0.1,
          at.dx + w,
          at.dy + wing * 0.2,
        )
        ..quadraticBezierTo(at.dx + w * 0.5, at.dy - wing, at.dx, at.dy)
        ..close(),
      Kit.fill(AppColors.midnight.withValues(alpha: 0.85 * a)),
    );
  }

  void _hills(Canvas canvas, Size s) {
    final base = s.height * 0.74;
    Path ridge(double amp, double freq, double phase, double y) {
      final path = Path()..moveTo(-30, s.height + 20);
      for (var x = -30.0; x <= s.width + 30; x += 12) {
        final yy =
            y -
            amp * (0.5 + 0.5 * math.sin(x / s.width * freq * math.pi + phase));
        path.lineTo(x, yy);
      }
      return path
        ..lineTo(s.width + 30, s.height + 20)
        ..close();
    }

    canvas.drawPath(
      ridge(s.height * 0.07, 3.2, 1.0, base - s.height * 0.05),
      Kit.fill(const Color(0xFF14123A)),
    );
    canvas.drawPath(
      ridge(s.height * 0.05, 2.4, 3.1, base + s.height * 0.015),
      Kit.fill(const Color(0xFF0B0B28)),
    );
  }

  void _house(Canvas canvas, Size s) {
    final u = math.min(s.width, s.height * 0.75);
    final cx = s.width * 0.5;
    final ground = s.height * 0.8;
    final a = _r;
    if (a <= 0) return;

    canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: a));
    canvas.translate(cx, ground + (1 - a) * 12);

    final body = Kit.fill(const Color(0xFF070A1E));
    final rim = Kit.stroke(AppColors.moonCyan.withValues(alpha: 0.35), 1.2);

    // Main block and roof.
    final block = Rect.fromLTRB(-0.42 * u, -0.30 * u, 0.42 * u, 0);
    canvas.drawRect(block, body);
    final roof = Path()
      ..moveTo(-0.46 * u, -0.30 * u)
      ..lineTo(-0.30 * u, -0.43 * u)
      ..lineTo(-0.07 * u, -0.43 * u)
      ..lineTo(0.07 * u, -0.43 * u)
      ..lineTo(0.30 * u, -0.43 * u)
      ..lineTo(0.46 * u, -0.30 * u)
      ..close();
    canvas.drawPath(roof, body);
    canvas.drawPath(roof, rim);

    // Left tower with a pointed cap.
    final left = Path()
      ..moveTo(-0.44 * u, -0.30 * u)
      ..lineTo(-0.44 * u, -0.52 * u)
      ..lineTo(-0.36 * u, -0.66 * u)
      ..lineTo(-0.28 * u, -0.52 * u)
      ..lineTo(-0.28 * u, -0.30 * u)
      ..close();
    canvas.drawPath(left, body);
    canvas.drawPath(left, rim);

    // Clock tower.
    final tower = Path()
      ..moveTo(-0.075 * u, -0.43 * u)
      ..lineTo(-0.075 * u, -0.66 * u)
      ..lineTo(0, -0.84 * u)
      ..lineTo(0.075 * u, -0.66 * u)
      ..lineTo(0.075 * u, -0.43 * u)
      ..close();
    canvas.drawPath(tower, body);
    canvas.drawPath(tower, rim);
    final face = Offset(0, -0.57 * u);
    Kit.glow(canvas, face, 0.12 * u, AppColors.antiqueGold, 0.5);
    canvas.drawCircle(face, 0.042 * u, Kit.fill(AppColors.goldLight));
    canvas.drawCircle(face, 0.042 * u, Kit.stroke(AppColors.goldDeep, 1.4));
    final hands = Kit.stroke(AppColors.midnight, 1.4);
    canvas.drawLine(face, face.translate(0, -0.03 * u), hands);
    canvas.drawLine(face, face.translate(0.02 * u, 0.012 * u), hands);

    // Right chimneys.
    canvas.drawRect(Rect.fromLTWH(0.26 * u, -0.5 * u, 0.04 * u, 0.1 * u), body);
    canvas.drawRect(
      Rect.fromLTWH(0.34 * u, -0.48 * u, 0.035 * u, 0.08 * u),
      body,
    );

    // Windows: most dark, a few warm and flickering.
    final lit = {1, 4, 6, 9, 11};
    var i = 0;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 7; col++) {
        final wx = (-0.36 + col * 0.12) * u;
        final wy = (-0.24 + row * 0.11) * u;
        final r = Rect.fromLTWH(wx, wy, 0.045 * u, 0.065 * u);
        if (lit.contains(i)) {
          final f = 0.6 + 0.4 * math.sin(_t * 2 * math.pi * (6 + i) + i);
          Kit.glow(canvas, r.center, 0.09 * u, AppColors.antiqueGold, 0.35 * f);
          Kit.rrect(
            canvas,
            r,
            2,
            Kit.fill(AppColors.antiqueGold.withValues(alpha: 0.55 + 0.4 * f)),
          );
        } else {
          Kit.rrect(canvas, r, 2, Kit.fill(AppColors.stone));
        }
        i++;
      }
    }

    // Front door with a cold cyan glow spilling out.
    final door = Path()
      ..moveTo(-0.035 * u, 0)
      ..lineTo(-0.035 * u, -0.07 * u)
      ..quadraticBezierTo(0, -0.115 * u, 0.035 * u, -0.07 * u)
      ..lineTo(0.035 * u, 0)
      ..close();
    Kit.lightShaft(
      canvas,
      Offset(0, -0.02 * u),
      0.06 * u,
      Offset(0, 0.14 * u),
      0.2 * u,
      AppColors.moonCyan,
      0.35,
    );
    canvas.drawPath(door, Kit.fill(AppColors.moonCyan.withValues(alpha: 0.75)));
    canvas.restore();
  }

  void _foreground(Canvas canvas, Size s) {
    final y = s.height * 0.9;
    final dark = Kit.fill(const Color(0xFF04051A));

    // Ground.
    canvas.drawRect(Rect.fromLTRB(-30, y, s.width + 30, s.height + 30), dark);

    // Iron fence.
    final bar = Kit.stroke(const Color(0xFF04051A), 3);
    for (var x = -10.0; x < s.width + 30; x += 26) {
      canvas.drawLine(Offset(x, y + 28), Offset(x, y - 34), bar);
      canvas.drawPath(
        Path()
          ..moveTo(x - 4, y - 34)
          ..lineTo(x, y - 46)
          ..lineTo(x + 4, y - 34)
          ..close(),
        dark,
      );
    }
    canvas.drawLine(Offset(-10, y - 12), Offset(s.width + 30, y - 12), bar);
    canvas.drawLine(Offset(-10, y + 10), Offset(s.width + 30, y + 10), bar);

    // Dead tree on the left.
    final tx = s.width * 0.12;
    final trunk = Kit.stroke(const Color(0xFF04051A), 9);
    final branch = Kit.stroke(const Color(0xFF04051A), 4);
    final sway = 2 * math.sin(_t * 2 * math.pi);
    canvas.drawPath(
      Path()
        ..moveTo(tx, y + 20)
        ..quadraticBezierTo(
          tx - 12,
          y - s.height * 0.14,
          tx + 4,
          y - s.height * 0.26,
        ),
      trunk,
    );
    for (final b in [
      [tx - 2, y - s.height * 0.12, -60.0, -36.0],
      [tx + 2, y - s.height * 0.18, 56.0, -44.0],
      [tx + 4, y - s.height * 0.25, -34.0, -48.0],
      [tx + 4, y - s.height * 0.25, 30.0, -40.0],
    ]) {
      canvas.drawLine(
        Offset(b[0], b[1]),
        Offset(b[0] + b[2] + sway, b[1] + b[3]),
        branch,
      );
    }

    // Grass tufts.
    for (var i = 0; i < 40; i++) {
      final gx = Kit.rand(i + 50) * s.width;
      final h = 8 + Kit.rand(i + 90) * 14;
      canvas.drawLine(
        Offset(gx, y + 30),
        Offset(gx + 3 * math.sin(_t * 6 + i), y + 30 - h),
        Kit.stroke(const Color(0xFF04051A), 2),
      );
    }
  }

  @override
  bool shouldRepaint(_ExteriorPainter old) => old.layer != layer;
}
