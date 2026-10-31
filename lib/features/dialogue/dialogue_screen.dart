import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../content/definitions/choice_def.dart';
import '../../content/definitions/progress_view.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/character_portraits.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/fog_layer.dart';
import '../../core/widgets/grain_overlay.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/spectral_button.dart';
import '../../core/widgets/typewriter_text.dart';

/// A conversation: the speaker's portrait, their line, and the player's
/// answers. Availability of each answer comes from the real story conditions
/// (for example, "Call Ottoline home" stays locked until earned).
///
/// Choosing shows the reply but does not record story flags yet.
class DialogueScreen extends StatefulWidget {
  const DialogueScreen({super.key, required this.choiceId});

  final String choiceId;

  @override
  State<DialogueScreen> createState() => _DialogueScreenState();
}

class _DialogueScreenState extends State<DialogueScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  final _typeKey = GlobalKey<TypewriterTextState>();
  bool _lineDone = false;
  ChoiceOption? _chosen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceOf(context)) {
      _life.stop();
      _life.value = 0.25;
    } else if (!_life.isAnimating) {
      _life.repeat();
    }
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Color _accent(String name) => switch (name) {
    'antiqueGold' => AppColors.antiqueGold,
    'ghostGreen' => AppColors.ghostGreen,
    'violetMist' => const Color(0xFFB48CFF),
    _ => AppColors.moonCyan,
  };

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final content = services.content;
    final choice = content.choiceById(widget.choiceId)!;
    final speaker = content.characterById(choice.speakerId)!;
    final preview = services.preview;
    final theme = Theme.of(context);
    final accent = _accent(speaker.accent);
    final chosen = _chosen;

    final line = chosen?.resultText ?? choice.prompt.resolve(preview);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 1.2,
                colors: [
                  Color.lerp(AppColors.deepPurple, accent, 0.25)!,
                  AppColors.midnight,
                ],
              ),
            ),
          ),
          FogLayer(color: accent, density: 0.9, verticalBias: 0.35, seed: 9),
          const GrainOverlay(vignette: 0.6),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: IconButton(
                      tooltip: 'Leave conversation',
                      iconSize: 26,
                      constraints: const BoxConstraints(
                        minWidth: AppLayout.minTouch,
                        minHeight: AppLayout.minTouch,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppLayout.contentMaxWidth,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeSlideIn(
                              child: Column(
                                children: [
                                  CharacterPortrait(
                                    characterId: speaker.id,
                                    size: 150,
                                    animation: _life,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      speaker.name,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(color: accent),
                                    ),
                                  ),
                                  Text(
                                    speaker.role,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _typeKey.currentState?.complete(),
                              child: ManorPanel(
                                tone: PanelTone.strong,
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: TypewriterText(
                                  key: ValueKey(line),
                                  text: line,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.6,
                                  ),
                                  onCompleted: () =>
                                      setState(() => _lineDone = true),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (chosen == null && _lineDone)
                              ..._options(choice, preview)
                            else if (chosen != null && _lineDone)
                              ..._after(theme),
                          ],
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

  List<Widget> _options(ChoiceDef choice, ProgressView preview) {
    return [
      for (final (i, option) in choice.options.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: FadeSlideIn(
            delay: Duration(milliseconds: 80 * i),
            child: Builder(
              builder: (context) {
                final enabled = option.enabledWhen?.evaluate(preview) ?? true;
                return SpectralButton(
                  label: option.label,
                  style: SpectralStyle.secondary,
                  expand: true,
                  onPressed: enabled
                      ? () => setState(() {
                          _chosen = option;
                          _lineDone = false;
                        })
                      : null,
                  disabledReason: enabled ? null : option.disabledReason,
                );
              },
            ),
          ),
        ),
    ];
  }

  List<Widget> _after(ThemeData theme) {
    return [
      FadeSlideIn(
        child: Text(
          'Preview: your answer is shown, but it is not recorded in the story yet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      FadeSlideIn(
        delay: const Duration(milliseconds: 100),
        child: Center(
          child: SpectralButton(
            label: 'Done',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
      ),
    ];
  }
}
