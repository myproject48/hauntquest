import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../content/definitions/item_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/item_icons.dart';
import '../../core/painting/paint_kit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/spectral_button.dart';

/// Shows a visually rewarding discovery presentation when a new item is forged or found.
Future<void> showDiscoveryDialog(
  BuildContext context, {
  required ItemDef item,
  required String message,
  VoidCallback? onInspect,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: AppColors.midnight.withValues(alpha: 0.82),
    builder: (dialogContext) =>
        _DiscoveryModal(item: item, message: message, onInspect: onInspect),
  );
}

class _DiscoveryModal extends StatefulWidget {
  const _DiscoveryModal({
    required this.item,
    required this.message,
    this.onInspect,
  });

  final ItemDef item;
  final String message;
  final VoidCallback? onInspect;

  @override
  State<_DiscoveryModal> createState() => _DiscoveryModalState();
}

class _DiscoveryModalState extends State<_DiscoveryModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rays = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _rays.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceOf(context)) {
      _rays.stop();
      _rays.value = 0.2;
    } else if (_rays.isDismissed) {
      _rays.forward();
    }
  }

  @override
  void dispose() {
    _rays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    final reduce = MotionPolicy.reduceOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Semantics(
          label: 'Discovery: ${widget.item.name}. ${widget.message}',
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.midnight,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.goldLight, width: 2),
              boxShadow: AppGlow.gold(0.9),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated background rays
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _rays,
                      builder: (context, _) => CustomPaint(
                        painter: _RaysPainter(angle: _rays.value * 2 * math.pi),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Discovery Crest
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.deepPurple.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: AppColors.goldLight,
                              width: 1.2,
                            ),
                            boxShadow: AppGlow.gold(0.6),
                          ),
                          child: Text(
                            'NEW DISCOVERY',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.goldLight,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Item Icon on Pedestal
                        SizedBox(
                          height: 140,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                bottom: 10,
                                child: Container(
                                  width: 140,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.deepPurple,
                                    border: Border.all(
                                      color: AppColors.antiqueGold,
                                      width: 1.5,
                                    ),
                                    boxShadow: AppGlow.gold(0.7),
                                  ),
                                ),
                              ),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: reduce
                                    ? Duration.zero
                                    : const Duration(milliseconds: 650),
                                curve: Curves.elasticOut,
                                builder: (context, scale, child) =>
                                    Transform.scale(scale: scale, child: child),
                                child: ItemIcon(
                                  iconId: widget.item.iconId,
                                  size: 100,
                                  glow: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Title
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 150),
                          child: Text(
                            widget.item.name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppColors.paper,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Message
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 250),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: tokens.panelFill.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: tokens.panelBorder.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.paperDark,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Actions
                        Row(
                          children: [
                            if (widget.onInspect != null) ...[
                              Expanded(
                                child: SpectralButton(
                                  label: 'Inspect',
                                  icon: Icons.search_rounded,
                                  style: SpectralStyle.secondary,
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onInspect?.call();
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: SpectralButton(
                                label: 'Pocket Item',
                                icon: Icons.backpack_rounded,
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.angle});

  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final radius = math.max(size.width, size.height) * 0.9;
    const rayCount = 12;

    for (var i = 0; i < rayCount; i++) {
      final rayAngle = angle + (i * 2 * math.pi / rayCount);
      final p1 = Offset(
        center.dx + radius * math.cos(rayAngle - 0.12),
        center.dy + radius * math.sin(rayAngle - 0.12),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(rayAngle + 0.12),
        center.dy + radius * math.sin(rayAngle + 0.12),
      );

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      canvas.drawPath(
        path,
        Kit.fill(AppColors.antiqueGold.withValues(alpha: 0.05)),
      );
    }

    Kit.glow(canvas, center, radius * 0.5, AppColors.antiqueGold, 0.2);
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.angle != angle;
}
