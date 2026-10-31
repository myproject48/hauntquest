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
import '../menu/main_menu_screen.dart';

/// An ending: full-bleed illustration, the title, and the epilogue revealed
/// one paragraph at a time.
///
/// Reached today only from Settings > Review tools. In the finished game it
/// follows the Echo's final choice.
class EndingScreen extends StatefulWidget {
  const EndingScreen({super.key, required this.endingId});

  final String endingId;

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
    final content = AppScope.of(context).content;
    final ending = content.endingById(widget.endingId)!;
    final theme = Theme.of(context);
    final total = ending.epilogue.length;
    final finished = _shown >= total;

    return Scaffold(
      body: Stack(
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
                    child: IconButton(
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
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 34,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.goldLight.withValues(
                                        alpha: 0.6,
                                      ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted || !_scroll.hasClients) return;
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
                                        builder: (_) => const MainMenuScreen(),
                                      ),
                                      (_) => false,
                                    ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SpectralButton(
                              label: 'Close preview',
                              style: SpectralStyle.quiet,
                              expand: true,
                              onPressed: () => Navigator.maybePop(context),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Preview of this ending. In the game it follows the Echo\'s final choice.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
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
    );
  }
}
