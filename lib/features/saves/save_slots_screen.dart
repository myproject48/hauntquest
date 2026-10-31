import 'package:flutter/material.dart';

import '../../core/design/manor_tokens.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/painting/item_icons.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/spectral_button.dart';
import '../intro/intro_screen.dart';

/// Lists the autosave and three manual save slots.
///
/// Saving is not built yet, so every slot is honestly shown as empty. The
/// screen is ready to show real saves once the persistence layer exists.
class SaveSlotsScreen extends StatelessWidget {
  const SaveSlotsScreen({super.key});

  static const _slots = [
    ('Autosave', 'Written automatically when you move or solve something.'),
    ('Slot 1', 'Keep a journey of your own here.'),
    ('Slot 2', 'Keep a journey of your own here.'),
    ('Slot 3', 'Keep a journey of your own here.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ManorScaffold(
      title: 'Continue',
      subtitle: 'Saved journeys',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          FadeSlideIn(
            child: ManorPanel(
              tone: PanelTone.discovery,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'No saved journeys yet',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Saving is not built yet, so there is nothing to continue. You can begin a new quest and explore the manor.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SpectralButton(
                    label: 'Begin Quest',
                    icon: Icons.auto_stories_rounded,
                    onPressed: () =>
                        context.pushReplacementMist(const IntroScreen()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (i, slot) in _slots.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 120 + i * 80),
                child: _SlotCard(title: slot.$1, hint: slot.$2),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    return Semantics(
      container: true,
      label: '$title, empty. $hint',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: tokens.panelFill.withValues(alpha: 0.6),
            border: Border.all(
              color: tokens.panelBorder.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const ItemIcon(
                iconId: 'lantern',
                size: 56,
                glow: false,
                dimmed: true,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Empty', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(hint, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
