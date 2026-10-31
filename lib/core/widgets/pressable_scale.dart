import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/manor_tokens.dart';
import '../design/motion_policy.dart';
import '../design/tokens.dart';

/// Gives any child tactile feedback: a quick scale-down on press, a light
/// haptic on tap, a visible focus ring for keyboard users, and proper button
/// semantics. Enforces the minimum touch target.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.borderRadius = AppRadius.md,
    this.haptic = true,
    this.enforceMinSize = true,
  });

  final Widget child;

  /// Null disables the control.
  final VoidCallback? onTap;

  /// Spoken label. When null, the child's own text is used.
  final String? semanticLabel;
  final String? semanticHint;
  final double borderRadius;
  final bool haptic;
  final bool enforceMinSize;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  bool _focused = false;

  void _activate() {
    if (widget.onTap == null) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MotionPolicy.reduceOf(context);
    final tokens = ManorTokens.of(context);
    final enabled = widget.onTap != null;

    Widget content = AnimatedScale(
      scale: _pressed && !reduce ? 0.96 : 1,
      duration: reduce ? Duration.zero : AppMotion.fast,
      curve: AppMotion.enter,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: _focused ? Border.all(color: tokens.focus, width: 2.5) : null,
        ),
        child: widget.child,
      ),
    );

    if (widget.enforceMinSize) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppLayout.minTouch,
          minHeight: AppLayout.minTouch,
        ),
        child: content,
      );
    }

    // When a label is given it replaces the child's own text, so screen
    // readers do not hear it twice.
    if (widget.semanticLabel != null) {
      content = ExcludeSemantics(child: content);
    }

    // One merged node: label, hint, button role, tap and focus together.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel,
        hint: widget.semanticHint,
        child: FocusableActionDetector(
          enabled: enabled,
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: enabled
                ? () => setState(() => _pressed = false)
                : null,
            onTap: enabled ? _activate : null,
            child: content,
          ),
        ),
      ),
    );
  }
}
