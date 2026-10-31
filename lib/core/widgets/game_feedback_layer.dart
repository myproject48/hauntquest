import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/game_controller.dart';
import '../../domain/engine/game_events.dart';
import '../design/motion_policy.dart';
import '../theme/app_colors.dart';

/// Event-driven finite effects over the active route. The navigator is a
/// cached child, and particles have their own repaint boundary.
class GameFeedbackLayer extends StatefulWidget {
  const GameFeedbackLayer({super.key, required this.child});
  final Widget child;
  @override
  State<GameFeedbackLayer> createState() => GameFeedbackLayerState();
}

class GameFeedbackLayerState extends State<GameFeedbackLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  GameController? _game;
  Color _color = AppColors.goldLight;
  bool _reduced = false;
  bool get animating => _burst.isAnimating;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final game = AppScope.of(context).game;
    if (!identical(_game, game)) {
      _game?.pulses.removeListener(_pulse);
      _game = game;
      game.pulses.addListener(_pulse);
    }
    _reduced = MotionPolicy.reduceOf(context);
    if (_reduced) {
      _burst.stop();
      _burst.value = 1;
    }
  }

  void _pulse() {
    final events = _game?.pulses.value?.events ?? [];
    if (_reduced || events.any((e) => e is EndingReached)) return;
    final good = events.any(
      (e) =>
          e is PuzzleSolved ||
          e is ItemAcquired ||
          e is ExitOpened ||
          (e is RoomEntered && e.firstVisit),
    );
    final wrong = !good && events.any((e) => e is PuzzleAttempted);
    if (!good && !wrong) return;
    setState(() => _color = wrong ? AppColors.danger : AppColors.goldLight);
    _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _game?.pulses.removeListener(_pulse);
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('game-feedback-particles'),
              painter: _BurstPainter(_burst, _color),
            ),
          ),
        ),
      ),
    ],
  );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.animation, this.color) : super(repaint: animation);
  final Animation<double> animation;
  final Color color;
  @override
  void paint(Canvas c, Size size) {
    final p = animation.value;
    if (p <= 0 || p >= 1 || size.isEmpty) return;
    final center = Offset(size.width * .5, size.height * .42);
    final radius = math.min(size.width, size.height) * .26;
    final alpha = math.sin(math.pi * p) * .6;
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    c.drawCircle(center, radius * Curves.easeOutCubic.transform(p), paint);
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final a = center + Offset(math.cos(angle), math.sin(angle)) * radius * p;
      final b =
          center +
          Offset(math.cos(angle), math.sin(angle)) * radius * (p + .08);
      c.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}
