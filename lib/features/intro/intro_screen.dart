import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/painting/exterior_scene.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/spectral_button.dart';
import '../../core/widgets/typewriter_text.dart';
import '../room/room_screen.dart';

/// The story opening, one line at a time, over the manor at night. Tap to
/// finish a line, then continue. Can be skipped.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _typeKey = GlobalKey<TypewriterTextState>();
  int _index = 0;
  bool _lineDone = false;

  void _enterManor() {
    AppScope.of(context).preview.restart();
    context.pushReplacementMist(const RoomScreen());
  }

  void _advance(int total) {
    if (!_lineDone) {
      _typeKey.currentState?.complete();
      return;
    }
    if (_index >= total - 1) {
      _enterManor();
    } else {
      setState(() {
        _index++;
        _lineDone = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = AppScope.of(context).content.story;
    final lines = story.introLines;
    final theme = Theme.of(context);
    final last = _index == lines.length - 1;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ExteriorScene(),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x99050818)),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: SpectralButton(
                      label: 'Skip',
                      style: SpectralStyle.quiet,
                      onPressed: _enterManor,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppLayout.contentMaxWidth,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _advance(lines.length),
                                child: ManorPanel(
                                  tone: PanelTone.strong,
                                  padding: const EdgeInsets.all(AppSpacing.xl),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 120,
                                    ),
                                    child: Center(
                                      child: TypewriterText(
                                        key: _typeKey,
                                        text: lines[_index],
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(height: 1.6),
                                        textAlign: TextAlign.center,
                                        onCompleted: () =>
                                            setState(() => _lineDone = true),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              SpectralButton(
                                label: !_lineDone
                                    ? 'Show all'
                                    : (last ? 'Enter the manor' : 'Continue'),
                                icon: last && _lineDone
                                    ? Icons.door_front_door_outlined
                                    : null,
                                style: last && _lineDone
                                    ? SpectralStyle.primary
                                    : SpectralStyle.secondary,
                                onPressed: () => _advance(lines.length),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ExcludeSemantics(
                                child: Text(
                                  '${_index + 1} of ${lines.length}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
