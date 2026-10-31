import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/motion_policy.dart';
import '../theme/app_colors.dart';
import '../widgets/fog_layer.dart';
import '../widgets/grain_overlay.dart';
import 'paint_kit.dart';

/// Full-bleed illustration for an ending, chosen by `sceneId` from
/// `story.json`: `ending_release_echo`, `ending_echo_guardian`,
/// `ending_seal_echo`.
class EndingScene extends StatefulWidget {
  const EndingScene({super.key, required this.sceneId});

  final String sceneId;

  static const Set<String> supported = {
    'ending_release_echo',
    'ending_echo_guardian',
    'ending_seal_echo',
  };

  @override
  State<EndingScene> createState() => _EndingSceneState();
}

class _EndingSceneState extends State<EndingScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceOf(context)) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!EndingScene.supported.contains(widget.sceneId)) {
      throw ArgumentError('No ending art for "${widget.sceneId}".');
    }
    final fog = switch (widget.sceneId) {
      'ending_release_echo' => AppColors.goldLight,
      'ending_echo_guardian' => AppColors.antiqueGold,
      _ => const Color(0xFFB48CFF),
    };
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _EndingPainter(widget.sceneId, _t),
            ),
          ),
          FogLayer(color: fog, density: 0.9, verticalBias: 0.78, seed: 5),
          const GrainOverlay(vignette: 0.55),
        ],
      ),
    );
  }
}

class _EndingPainter extends CustomPainter {
  _EndingPainter(this.id, this.anim) : super(repaint: anim);

  final String id;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size s) {
    if (s.isEmpty) return;
    final t = anim.value;
    switch (id) {
      case 'ending_release_echo':
        _dawn(canvas, s, t);
      case 'ending_echo_guardian':
        _guardian(canvas, s, t);
      default:
        _seal(canvas, s, t);
    }
  }

  // A Quiet Dawn: the manor at sunrise, windows dark, a single bird.
  void _dawn(Canvas c, Size s, double t) {
    Kit.vGradient(
      c,
      Offset.zero & s,
      const [
        Color(0xFF1B1A4A),
        Color(0xFF5A3F88),
        Color(0xFFE59A7A),
        Color(0xFFF4D9A0),
      ],
      const [0, 0.4, 0.72, 1],
    );
    final sun = Offset(s.width * 0.5, s.height * 0.7);
    Kit.glow(c, sun, s.width * 0.9, AppColors.goldLight, 0.55);
    c.drawCircle(sun, s.width * 0.1, Kit.fill(const Color(0xFFFFF1C9)));
    // Faint stars fading out.
    for (var i = 0; i < 40; i++) {
      c.drawCircle(
        Offset(Kit.rand(i) * s.width, Kit.rand(i + 9) * s.height * 0.35),
        1.2,
        Kit.fill(
          Colors.white.withValues(
            alpha: 0.5 * (1 - Kit.rand(i + 9) * 2.4).clamp(0, 1),
          ),
        ),
      );
    }
    // Hills and the manor in silhouette.
    final hill = Path()..moveTo(0, s.height);
    for (var x = 0.0; x <= s.width; x += 10) {
      hill.lineTo(
        x,
        s.height * 0.78 -
            math.sin(x / s.width * math.pi * 2 + 1) * s.height * 0.025,
      );
    }
    hill.lineTo(s.width, s.height);
    c.drawPath(hill, Kit.fill(const Color(0xFF1B1633)));
    final u = math.min(s.width, s.height * 0.7);
    c.save();
    c.translate(s.width * 0.5, s.height * 0.78);
    final dark = Kit.fill(const Color(0xFF120F26));
    c.drawRect(Rect.fromLTRB(-0.3 * u, -0.2 * u, 0.3 * u, 0), dark);
    c.drawPath(
      Path()
        ..moveTo(-0.33 * u, -0.2 * u)
        ..lineTo(-0.2 * u, -0.3 * u)
        ..lineTo(0.2 * u, -0.3 * u)
        ..lineTo(0.33 * u, -0.2 * u)
        ..close(),
      dark,
    );
    c.drawPath(
      Path()
        ..moveTo(-0.05 * u, -0.3 * u)
        ..lineTo(-0.05 * u, -0.46 * u)
        ..lineTo(0, -0.58 * u)
        ..lineTo(0.05 * u, -0.46 * u)
        ..lineTo(0.05 * u, -0.3 * u)
        ..close(),
      dark,
    );
    c.drawCircle(Offset(0, -0.42 * u), 0.03 * u, Kit.fill(AppColors.goldLight));
    c.restore();
    // One bird crossing the sun.
    final f = (t * 2) % 1.0;
    final bird = Offset(
      f * (s.width + 60) - 30,
      s.height * 0.5 - math.sin(f * math.pi) * 30,
    );
    final flap = math.sin(t * 2 * math.pi * 30) * 5;
    c.drawPath(
      Path()
        ..moveTo(bird.dx - 10, bird.dy - flap)
        ..quadraticBezierTo(bird.dx - 4, bird.dy - 6, bird.dx, bird.dy)
        ..quadraticBezierTo(
          bird.dx + 4,
          bird.dy - 6,
          bird.dx + 10,
          bird.dy - flap,
        ),
      Kit.stroke(const Color(0xFF2B1B3F), 2),
    );
  }

  // Guardianship: an open arch, a watcher and a freely moving light.
  void _guardian(Canvas c, Size s, double t) {
    Kit.vGradient(
      c,
      Offset.zero & s,
      const [Color(0xFF0B0A25), Color(0xFF2B1357), Color(0xFF6B3F2A)],
      const [0, 0.6, 1],
    );
    final cx = s.width * 0.5;
    final base = s.height * 0.82;
    final u = math.min(s.width, s.height * 0.75);
    // Great arch, glowing gold from beyond.
    final arch = Path()
      ..moveTo(cx - 0.3 * u, base)
      ..lineTo(cx - 0.3 * u, base - 0.5 * u)
      ..quadraticBezierTo(cx, base - 0.95 * u, cx + 0.3 * u, base - 0.5 * u)
      ..lineTo(cx + 0.3 * u, base)
      ..close();
    final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi * 2);
    Kit.glow(
      c,
      Offset(cx, base - 0.4 * u),
      u * 0.9,
      AppColors.goldLight,
      0.5 * pulse,
    );
    c.drawPath(
      arch,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE8A8), Color(0xFFE59A52)],
            ).createShader(
              Rect.fromLTWH(cx - 0.3 * u, base - 0.9 * u, 0.6 * u, 0.9 * u),
            ),
    );
    c.drawPath(arch, Kit.stroke(AppColors.stoneLight, u * 0.03));
    Kit.lightShaft(
      c,
      Offset(cx, base - 0.2 * u),
      0.5 * u,
      Offset(cx, s.height),
      1.1 * u,
      AppColors.goldLight,
      0.35,
    );
    // Floor.
    c.drawRect(
      Rect.fromLTWH(0, base, s.width, s.height - base),
      Kit.fill(const Color(0xFF14102B)),
    );
    // The guardian and Tallow keep a welcoming doorway.
    void figure(double x, double h, {bool porter = false}) {
      final dark = Kit.fill(const Color(0xFF0A0818));
      c.drawPath(
        Path()
          ..moveTo(x - h * 0.2, base + 6)
          ..quadraticBezierTo(x - h * 0.22, base - h * 0.5, x, base - h * 0.56)
          ..quadraticBezierTo(
            x + h * 0.22,
            base - h * 0.5,
            x + h * 0.2,
            base + 6,
          )
          ..close(),
        dark,
      );
      c.drawCircle(Offset(x, base - h * 0.68), h * 0.11, dark);
      if (porter) {
        c.drawRect(
          Rect.fromCenter(
            center: Offset(x, base - h * 0.8),
            width: h * 0.2,
            height: h * 0.05,
          ),
          dark,
        );
      } else {
        c.drawCircle(Offset(x, base - h * 0.8), h * 0.06, dark);
        c.drawCircle(
          Offset(x - h * 0.05, base - h * 0.7),
          h * 0.035,
          Kit.stroke(AppColors.brass, 1.6),
        );
      }
    }

    figure(cx - 0.05 * u, 0.55 * u);
    figure(cx + 0.18 * u, 0.5 * u, porter: true);
    final lantern = Offset(cx + 0.1 * u, base - 0.18 * u);
    Kit.glow(c, lantern, 0.2 * u, AppColors.moonCyan, 0.6);
    c.drawCircle(lantern, 0.018 * u, Kit.fill(const Color(0xFFE9FFFF)));
    // Echo ripples becoming a friendly whisper along the arch.
    for (var i = 0; i < 3; i++) {
      final f = (t * 2 + i / 3) % 1.0;
      c.drawArc(
        Rect.fromCircle(
          center: Offset(cx, base - 0.5 * u),
          radius: u * (0.3 + f * 0.35),
        ),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        Kit.stroke(AppColors.moonCyan.withValues(alpha: 0.4 * (1 - f)), 1.6),
      );
    }
  }

  // Containment: the voices settle around a sealed, stable core.
  void _seal(Canvas c, Size s, double t) {
    Kit.vGradient(
      c,
      Offset.zero & s,
      const [Color(0xFF05030F), Color(0xFF160B33), Color(0xFF2A1458)],
      const [0, 0.6, 1],
    );
    final cx = s.width * 0.5;
    final cy = s.height * 0.46;
    final u = math.min(s.width, s.height * 0.75);
    // Voices settle within the containment field.
    for (var arm = 0; arm < 7; arm++) {
      final p = Path();
      for (var i = 0; i <= 60; i++) {
        final k = i / 60;
        final a = arm * 2 * math.pi / 7 + k * 5 - t * 2 * math.pi;
        final r = u * (0.62 - k * 0.5);
        final pt = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.55);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      c.drawPath(
        p,
        Kit.stroke(const Color(0xFFB48CFF).withValues(alpha: 0.4), 1.8),
      );
    }
    Kit.glow(c, Offset(cx, cy), u * 0.6, const Color(0xFFB48CFF), 0.35);
    // Floor ellipse.
    c.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s.height * 0.78),
        width: u * 1.1,
        height: u * 0.22,
      ),
      Kit.fill(const Color(0xFF0C0722)),
    );
    c.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s.height * 0.78),
        width: u * 1.1,
        height: u * 0.22,
      ),
      Kit.stroke(AppColors.violetMist, 2),
    );
    // A sealed glass sphere, held by three intersecting containment rings.
    final center = Offset(cx, cy);
    final radius = u * .24;
    c.drawCircle(
      center,
      radius,
      Kit.fill(AppColors.moonCyan.withValues(alpha: .15)),
    );
    Kit.glow(c, center, radius, AppColors.moonCyan, .6);
    c.drawCircle(center, radius, Kit.stroke(AppColors.stoneLight, 3));
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(cx, cy);
      c.rotate(i * math.pi / 3);
      c.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2.4,
          height: radius * .65,
        ),
        Kit.stroke(AppColors.goldLight, 2.4),
      );
      c.restore();
    }
    c.drawCircle(center, u * .025, Kit.fill(AppColors.paper));
  }

  @override
  bool shouldRepaint(_EndingPainter old) => old.id != id;
}
