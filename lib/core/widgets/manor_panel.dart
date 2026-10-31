import 'package:flutter/material.dart';

import '../design/manor_tokens.dart';
import '../design/tokens.dart';
import '../theme/app_colors.dart';

/// Visual weight of a [ManorPanel].
enum PanelTone {
  /// Standard translucent navy panel.
  normal,

  /// Near-opaque panel for text over busy scenes.
  strong,

  /// Gold-lit panel for important discoveries.
  discovery,
}

/// Bordered panel with gold corner ornaments. The base surface for dialogs,
/// cards, and reading text.
class ManorPanel extends StatelessWidget {
  const ManorPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.tone = PanelTone.normal,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final PanelTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = ManorTokens.of(context);
    final strong = tone != PanelTone.normal;
    final fill = strong ? tokens.panelFillStrong : tokens.panelFill;
    final border = tone == PanelTone.discovery
        ? AppColors.goldLight
        : tokens.panelBorder;

    return CustomPaint(
      foregroundPainter: _CornerPainter(
        color: border,
        thick: tokens.highContrast,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: tokens.highContrast
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      AppColors.deepPurple.withValues(alpha: 0.35),
                      fill,
                    ),
                    fill,
                  ],
                ),
          color: tokens.highContrast ? fill : null,
          border: Border.all(
            color: border.withValues(alpha: tokens.highContrast ? 1 : 0.55),
            width: tokens.highContrast ? 2 : 1,
          ),
          boxShadow: [
            ...AppGlow.depth(),
            if (tone == PanelTone.discovery) ...AppGlow.gold(),
          ],
        ),
        // Own Material so list tiles and ink ripples inside stay visible.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color, required this.thick});

  final Color color;
  final bool thick;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick ? 3 : 2
      ..strokeCap = StrokeCap.round;
    const len = 16.0;
    const inset = 6.0;
    final w = size.width;
    final h = size.height;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawPath(
        Path()
          ..moveTo(x + dx * len, y)
          ..lineTo(x, y)
          ..lineTo(x, y + dy * len),
        p,
      );
      canvas.drawCircle(
        Offset(x + dx * 5, y + dy * 5),
        1.6,
        Paint()..color = color,
      );
    }

    corner(inset, inset, 1, 1);
    corner(w - inset, inset, -1, 1);
    corner(inset, h - inset, 1, -1);
    corner(w - inset, h - inset, -1, -1);
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.color != color || old.thick != thick;
}

/// A thin gold rule with a diamond in the middle.
class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = ManorTokens.of(context).panelBorder;
    return ExcludeSemantics(
      child: SizedBox(
        height: 16,
        child: CustomPaint(
          size: const Size(double.infinity, 16),
          painter: _DividerPainter(color),
        ),
      ),
    );
  }
}

class _DividerPainter extends CustomPainter {
  _DividerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final line = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), line);
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - 5)
        ..lineTo(cx + 5, cy)
        ..lineTo(cx, cy + 5)
        ..lineTo(cx - 5, cy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DividerPainter old) => old.color != color;
}
