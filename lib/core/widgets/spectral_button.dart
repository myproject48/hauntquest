import 'package:flutter/material.dart';

import '../design/manor_tokens.dart';
import '../design/tokens.dart';
import '../theme/app_colors.dart';
import 'pressable_scale.dart';

/// Visual weight of a [SpectralButton].
enum SpectralStyle {
  /// Gold: the main action on a screen.
  primary,

  /// Cyan: supporting actions.
  secondary,

  /// Text only: low emphasis.
  quiet,
}

/// The game's standard button: gold-trimmed or cyan-lit, with a soft glow,
/// press feedback, and an optional visible reason when disabled.
class SpectralButton extends StatelessWidget {
  const SpectralButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = SpectralStyle.primary,
    this.expand = false,
    this.disabledReason,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SpectralStyle style;

  /// Fill the available width.
  final bool expand;

  /// Shown under the button (and read by screen readers) when disabled.
  final String? disabledReason;

  Color get _accent => switch (style) {
    SpectralStyle.primary => AppColors.antiqueGold,
    SpectralStyle.secondary => AppColors.moonCyan,
    SpectralStyle.quiet => AppColors.fog,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tokens = ManorTokens.of(context);
    final accent = tokens.highContrast ? Colors.white : _accent;
    final textColor = style == SpectralStyle.primary && !tokens.highContrast
        ? AppColors.goldLight
        : accent;

    final decoration = switch (style) {
      SpectralStyle.quiet => null,
      _ => BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: tokens.highContrast
              ? const [Colors.black, Colors.black]
              : [
                  AppColors.deepPurple.withValues(alpha: 0.95),
                  AppColors.deepNavy.withValues(alpha: 0.95),
                ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: enabled ? 0.95 : 0.35),
          width: tokens.highContrast ? 2 : 1.5,
        ),
        boxShadow: enabled
            ? (style == SpectralStyle.primary
                  ? AppGlow.gold(0.8)
                  : AppGlow.cyan(0.6))
            : null,
      ),
    };

    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: textColor),
          ),
        ),
      ],
    );

    final button = Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PressableScale(
        onTap: onPressed,
        semanticLabel: label,
        semanticHint: enabled ? null : disabledReason,
        child: DecoratedBox(
          decoration: decoration ?? const BoxDecoration(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52, minWidth: 140),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Center(widthFactor: expand ? null : 1, child: row),
            ),
          ),
        ),
      ),
    );

    if (enabled || disabledReason == null) {
      return expand ? SizedBox(width: double.infinity, child: button) : button;
    }

    return Column(
      crossAxisAlignment: expand
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: AppSpacing.xs),
        ExcludeSemantics(
          child: Text(
            disabledReason!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
