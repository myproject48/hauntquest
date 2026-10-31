import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/game_controller.dart';
import '../../content/definitions/choice_def.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/painting/character_portraits.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/fog_layer.dart';
import '../../core/widgets/grain_overlay.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/spectral_button.dart';
import '../../core/widgets/typewriter_text.dart';
import '../ending/ending_screen.dart';

/// Presents an authored scene. Branch permissions and effects belong to the
/// narrative engine; completed scenes are immutable, read-only transcripts.
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
  bool _answeredHere = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceOf(context)) {
      _life.stop();
      _life.value = .25;
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
    final choice = services.content.choiceById(widget.choiceId);
    if (choice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversation unavailable')),
        body: const Center(child: Text('This voice has no story here.')),
      );
    }
    final game = services.game;
    final speaker = services.content.characterById(choice.speakerId)!;
    final theme = Theme.of(context);
    final accent = _accent(speaker.accent);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final resolved = game.choiceResolved(choice.id);
        final recorded = game.state.dialogueRecords[choice.id];
        final transcript = game.engine.narrative.transcript(game.state, choice);
        final chosen = choice.options
            .where((o) => o.id == game.state.resolvedChoices[choice.id])
            .firstOrNull;
        final noReplay =
            resolved && !_answeredHere && choice.replay == DialogueReplay.never;
        final line = noReplay
            ? 'This decision is final. The Echo remembers what you chose.'
            : resolved
            ? (recorded?.response ??
                  transcript?.response ??
                  chosen?.resultText ??
                  'The conversation has ended.')
            : choice.prompt.resolve(game.state);
        final nextId = _answeredHere ? chosen?.nextChoiceId : null;
        final next = nextId == null
            ? null
            : services.content.choiceById(nextId);
        final canContinue = next != null && game.choiceAvailable(next);
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.5),
                    radius: 1.2,
                    colors: [
                      Color.lerp(AppColors.deepPurple, accent, .25)!,
                      AppColors.midnight,
                    ],
                  ),
                ),
              ),
              FogLayer(color: accent, density: .9, verticalBias: .35, seed: 9),
              const GrainOverlay(vignette: .6),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: IconButton(
                          tooltip: 'Leave conversation',
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
                                      if (resolved && !_answeredHere)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            noReplay
                                                ? 'A FINAL DECISION'
                                                : 'CONVERSATION RECORDED',
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                if (resolved &&
                                    !_answeredHere &&
                                    transcript != null) ...[
                                  Text(
                                    transcript.prompt,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  if (chosen != null)
                                    Text(
                                      'You chose: ${chosen.label}',
                                      style: theme.textTheme.labelMedium,
                                    ),
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      _typeKey.currentState?.complete(),
                                  child: ManorPanel(
                                    tone: PanelTone.strong,
                                    padding: const EdgeInsets.all(
                                      AppSpacing.xl,
                                    ),
                                    child: TypewriterText(
                                      key: _typeKey,
                                      text: line,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(height: 1.6),
                                      onCompleted: () {
                                        if (mounted) {
                                          setState(() => _lineDone = true);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                if (!_lineDone)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      key: const ValueKey('skip-dialogue-text'),
                                      onPressed: () =>
                                          _typeKey.currentState?.complete(),
                                      icon: const Icon(
                                        Icons.fast_forward_rounded,
                                      ),
                                      label: const Text('Show full text'),
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.lg),
                                if (_lineDone && !resolved)
                                  ..._options(choice, game),
                                if (_lineDone && resolved)
                                  Center(
                                    child: SpectralButton(
                                      label: game.endingId != null
                                          ? 'See what follows'
                                          : canContinue
                                          ? 'Continue conversation'
                                          : 'Done',
                                      icon: game.endingId != null
                                          ? Icons.auto_awesome_rounded
                                          : Icons.check_rounded,
                                      onPressed: () {
                                        if (game.endingId case final ending?) {
                                          Navigator.of(context)
                                              .pushAndRemoveUntil(
                                                MistPageRoute<void>(
                                                  builder: (_) => EndingScreen(
                                                    endingId: ending,
                                                    fromPlay: true,
                                                  ),
                                                ),
                                                (r) => r.isFirst,
                                              );
                                        } else if (canContinue) {
                                          Navigator.of(context).pushReplacement(
                                            MistPageRoute<void>(
                                              builder: (_) => DialogueScreen(
                                                choiceId: nextId!,
                                              ),
                                            ),
                                          );
                                        } else {
                                          Navigator.maybePop(context);
                                        }
                                      },
                                    ),
                                  ),
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
      },
    );
  }

  List<Widget> _options(ChoiceDef choice, GameController game) {
    if (!game.choiceAvailable(choice)) {
      return [
        const Text(
          'This conversation is not open to you right now.',
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('Leave'),
        ),
      ];
    }
    return [
      for (final option in choice.options)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: SpectralButton(
            key: ValueKey('dialogue-option-${option.id}'),
            label: option.label,
            style: SpectralStyle.secondary,
            expand: true,
            disabledReason: game.optionEnabled(option)
                ? null
                : option.disabledReason,
            onPressed: game.optionEnabled(option)
                ? () {
                    final result = game.resolveChoice(choice.id, option.id);
                    if (!result.ok) return;
                    setState(() {
                      _answeredHere = true;
                      _lineDone = false;
                    });
                  }
                : null,
          ),
        ),
    ];
  }
}
