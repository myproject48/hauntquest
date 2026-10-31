import 'package:flutter/material.dart';

import '../design/motion_policy.dart';

/// Reveals text letter by letter. Screen readers always get the full text.
/// Call [TypewriterTextState.complete] (for example on tap) to skip ahead.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.onCompleted,
    this.charactersPerSecond = 45,
  }) : assert(charactersPerSecond > 0);

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final VoidCallback? onCompleted;
  final double charactersPerSecond;

  @override
  State<TypewriterText> createState() => TypewriterTextState();
}

class TypewriterTextState extends State<TypewriterText>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _notified = false;

  bool get isComplete => _controller.isCompleted;

  @override
  void initState() {
    super.initState();
    _controller = _build();
  }

  AnimationController _build() {
    final ms =
        (widget.text.characters.length / widget.charactersPerSecond * 1000)
            .round();
    final c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms < 1 ? 1 : ms),
    );
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_notified) {
        _notified = true;
        // Completion can happen during build (for example when motion is
        // reduced), so tell the parent after the frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCompleted?.call();
        });
      }
    });
    return c;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceOf(context)) {
      _controller.value = 1;
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.dispose();
      _notified = false;
      _controller = _build();
      if (MotionPolicy.reduceOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  /// Shows all remaining text immediately.
  void complete() {
    if (!_controller.isCompleted) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final graphemes = widget.text.characters;
          final count = (graphemes.length * _controller.value).round();
          // Keep layout stable: hidden characters are transparent, not absent.
          final visible = graphemes.take(count).toString();
          final hidden = graphemes.skip(count).toString();
          final base = widget.style ?? DefaultTextStyle.of(context).style;
          return Text.rich(
            TextSpan(
              style: base,
              children: [
                TextSpan(text: visible),
                TextSpan(
                  text: hidden,
                  style: base.copyWith(color: Colors.transparent),
                ),
              ],
            ),
            textAlign: widget.textAlign,
          );
        },
      ),
    );
  }
}
