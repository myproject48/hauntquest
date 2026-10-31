import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/painting/exterior_scene.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/fill_or_scroll.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/spectral_button.dart';
import '../about/about_screen.dart';
import 'new_game_action.dart';
import '../saves/save_slots_screen.dart';
import '../settings/settings_screen.dart';

/// Title screen: the manor on its hill, the title lockup, and the main routes.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ExteriorScene(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00050818), Color(0xE6050818)],
                stops: [0.35, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final landscape =
                    box.maxWidth >= 720 && box.maxWidth > box.maxHeight * 1.15;
                final lockup = _TitleLockup(compact: box.maxHeight < 560);
                const actions = _MenuActions();
                if (landscape) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(child: lockup),
                          ),
                        ),
                        const SizedBox(
                          width: AppLayout.sidePanelWidth,
                          child: Center(
                            child: SingleChildScrollView(child: actions),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // Title at the top, buttons at the bottom; scrolls when the
                // screen is short or the text is large.
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.contentMaxWidth,
                    ),
                    child: FillOrScroll(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xl,
                        AppSpacing.xl,
                        AppSpacing.lg,
                      ),
                      children: [
                        lockup,
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xl),
                          child: actions,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleLockup extends StatelessWidget {
  const _TitleLockup({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final size = (width * 0.1).clamp(30.0, compact ? 44.0 : 60.0);
    return FadeSlideIn(
      duration: const Duration(milliseconds: 900),
      child: Semantics(
        header: true,
        label: 'HauntQuest AI. The Whispering Manor.',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HAUNTQUEST',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: size,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(
                      color: AppColors.moonCyan.withValues(alpha: 0.75),
                      blurRadius: 26,
                    ),
                    Shadow(
                      color: AppColors.moonCyan.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'A I',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.antiqueGold,
                    letterSpacing: 14,
                  ),
                ),
              ),
              SizedBox(width: 200, child: const GoldDivider()),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The Whispering Manor',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.fog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuActions extends StatelessWidget {
  const _MenuActions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          delay: const Duration(milliseconds: 250),
          child: SpectralButton(
            label: 'Begin Quest',
            icon: Icons.auto_stories_rounded,
            expand: true,
            onPressed: () => _beginQuest(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          delay: const Duration(milliseconds: 340),
          child: SpectralButton(
            label: 'Continue',
            icon: Icons.bookmark_rounded,
            style: SpectralStyle.secondary,
            expand: true,
            onPressed: () => context.pushMist(const SaveSlotsScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          delay: const Duration(milliseconds: 430),
          child: SpectralButton(
            label: 'Settings',
            icon: Icons.tune_rounded,
            style: SpectralStyle.secondary,
            expand: true,
            onPressed: () => context.pushMist(const SettingsScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FadeSlideIn(
          delay: const Duration(milliseconds: 520),
          child: Center(
            child: SpectralButton(
              label: 'Credits',
              style: SpectralStyle.quiet,
              onPressed: () => context.pushMist(const AboutScreen()),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FadeSlideIn(
          delay: const Duration(milliseconds: 600),
          child: Text(
            'Your journey saves automatically. Original soundscapes await within; volume and mute controls are in Settings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

Future<void> _beginQuest(BuildContext context) => beginNewGame(context);
