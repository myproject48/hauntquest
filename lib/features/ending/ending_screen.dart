import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/painting/ending_scenes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/fill_or_scroll.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/spectral_button.dart';
import '../menu/new_game_action.dart';
import 'ending_reveal.dart';
import '../menu/main_menu_screen.dart';

/// An ending: full-bleed illustration, the title, and the epilogue revealed
/// one paragraph at a time.
///
/// Reached by making the Echo's final choice, or as a preview from
/// Settings > Review tools.
class EndingScreen extends StatefulWidget {
  const EndingScreen({
    super.key,
    required this.endingId,
    this.fromPlay = false,
  });

  final String endingId;

  /// True when reached by finishing the story (not a review preview).
  final bool fromPlay;

  @override
  State<EndingScreen> createState() => _EndingScreenState();
}

class _EndingScreenState extends State<EndingScreen> {
  int _shown = 1;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final content = services.content;
    final game = services.game;
    final ending = content.endingById(widget.endingId)!;
    final theme = Theme.of(context);
    final total = ending.epilogue.length;
    final finished = _shown >= total;

    return Scaffold(
      body: EndingReveal(
        style: ending.revealStyle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            EndingScene(sceneId: ending.sceneId),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00050818), Color(0xF2050818)],
                  stops: [0.3, 0.85],
                ),
              ),
            ),
            SafeArea(
              // Fills the screen; scrolls when text is large or the epilogue
              // grows past the screen.
              child: FillOrScroll(
                controller: _scroll,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: widget.fromPlay
                          ? const SizedBox(height: AppLayout.minTouch)
                          : IconButton(
                              tooltip: 'Back',
                              iconSize: 26,
                              constraints: const BoxConstraints(
                                minWidth: AppLayout.minTouch,
                                minHeight: AppLayout.minTouch,
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () => Navigator.maybePop(context),
                            ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppLayout.contentMaxWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeSlideIn(
                              child: Text(
                                'EPILOGUE',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.antiqueGold,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 150),
                              duration: const Duration(milliseconds: 900),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  ending.title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontSize: 34,
                                        shadows: [
                                          Shadow(
                                            color: AppColors.goldLight
                                                .withValues(alpha: 0.6),
                                            blurRadius: 22,
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 300),
                              child: ManorPanel(
                                tone: PanelTone.strong,
                                child: Semantics(
                                  liveRegion: true,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var i = 0; i < _shown; i++)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            bottom: i == _shown - 1
                                                ? 0
                                                : AppSpacing.md,
                                          ),
                                          child: FadeSlideIn(
                                            key: ValueKey('$i'),
                                            child: Text(
                                              ending.epilogue[i],
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(height: 1.6),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (!finished)
                              Center(
                                child: SpectralButton(
                                  label: 'Continue',
                                  icon: Icons.arrow_downward_rounded,
                                  onPressed: () {
                                    setState(() => _shown++);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted || !_scroll.hasClients) {
                                            return;
                                          }
                                          // Keep the newest paragraph and buttons in view.
                                          final end =
                                              _scroll.position.maxScrollExtent;
                                          if (MotionPolicy.reduceOf(context)) {
                                            _scroll.jumpTo(end);
                                          } else {
                                            _scroll.animateTo(
                                              end,
                                              duration: AppMotion.medium,
                                              curve: AppMotion.enter,
                                            );
                                          }
                                        });
                                  },
                                ),
                              )
                            else ...[
                              FadeSlideIn(
                                child: Center(
                                  child: Text(
                                    'THE END',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: AppColors.goldLight,
                                      letterSpacing: 6,
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.fromPlay) ...[
                                const SizedBox(height: AppSpacing.md),
                                FadeSlideIn(
                                  child: Semantics(
                                    label:
                                        'Your journey: ${game.state.solvedPuzzleIds.length} of ${content.puzzles.length} puzzles solved, '
                                        '${game.state.visitedRoomIds.length} of ${content.rooms.length} rooms explored, '
                                        '${game.state.resolvedChoices.length} choices made.',
                                    child: ExcludeSemantics(
                                      child: Text(
                                        '${game.state.solvedPuzzleIds.length}/${content.puzzles.length} puzzles  ·  '
                                        '${game.state.visitedRoomIds.length}/${content.rooms.length} rooms  ·  '
                                        '${game.state.resolvedChoices.length} choices',
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 150),
                                child: SpectralButton(
                                  label: 'Back to title',
                                  icon: Icons.home_rounded,
                                  expand: true,
                                  onPressed: () => Navigator.of(context)
                                      .pushAndRemoveUntil(
                                        MistPageRoute<void>(
                                          builder: (_) =>
                                              const MainMenuScreen(),
                                        ),
                                        (_) => false,
                                      ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (widget.fromPlay)
                                SpectralButton(
                                  label: 'Begin again',
                                  icon: Icons.replay_rounded,
                                  style: SpectralStyle.secondary,
                                  expand: true,
                                  onPressed: () => beginNewGame(context),
                                )
                              else
                                SpectralButton(
                                  label: 'Close preview',
                                  style: SpectralStyle.quiet,
                                  expand: true,
                                  onPressed: () => Navigator.maybePop(context),
                                ),
                            ],
                            if (!widget.fromPlay) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Preview of this ending. In the game it follows the Echo\'s final choice.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
