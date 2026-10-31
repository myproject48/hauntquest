import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/settings_controller.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/spectral_button.dart';
import '../ending/ending_screen.dart';

/// Reading, motion and play settings that apply immediately and are saved on
/// the device.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([services.settings, services.preview]),
      builder: (context, _) {
        final settings = services.settings.settings;
        final controller = services.settings;
        void update(AppSettings s) => controller.update(s);

        return ManorScaffold(
          title: 'Settings',
          subtitle: 'Accessibility and comfort',
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (controller.lastSaveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Semantics(
                    liveRegion: true,
                    child: ManorPanel(
                      tone: PanelTone.strong,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Your settings changed, but could not be saved on this device. They will reset when the app closes.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              _Section(
                index: 0,
                title: 'Reading',
                children: [
                  Text('Text size', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final scale in AppSettings.textScales)
                        _SizeChoice(
                          label: '${(scale * 100).round()}%',
                          selected: settings.textScale == scale,
                          onTap: () =>
                              update(settings.copyWith(textScale: scale)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SwitchRow(
                    title: 'Easier reading spacing',
                    subtitle: 'Adds space between letters and lines.',
                    value: settings.spacedText,
                    onChanged: (v) => update(settings.copyWith(spacedText: v)),
                  ),
                  _SwitchRow(
                    title: 'High contrast',
                    subtitle: 'Pure black panels, white text, bright borders.',
                    value: settings.highContrast,
                    onChanged: (v) =>
                        update(settings.copyWith(highContrast: v)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _Sample(),
                ],
              ),
              _Section(
                index: 1,
                title: 'Motion',
                children: [
                  _SwitchRow(
                    title: 'Reduce motion',
                    subtitle: 'Stops drifting fog, parallax and flickering, and shortens transitions. Your device setting is respected too.',
                    value: settings.reducedMotion,
                    onChanged: (v) =>
                        update(settings.copyWith(reducedMotion: v)),
                  ),
                ],
              ),
              _Section(
                index: 2,
                title: 'Exploring',
                children: [
                  _SwitchRow(
                    title: 'Mark tappable objects',
                    subtitle: 'Shows a badge on every object you can examine.',
                    value: settings.highlightInteractables,
                    onChanged: (v) =>
                        update(settings.copyWith(highlightInteractables: v)),
                  ),
                  _SwitchRow(
                    title: 'List objects as buttons',
                    subtitle: 'Also lists each room\'s objects in a column. Helpful with screen readers and switch access.',
                    value: settings.roomListMode,
                    onChanged: (v) =>
                        update(settings.copyWith(roomListMode: v)),
                  ),
                ],
              ),
              _Section(
                index: 3,
                title: 'Sound',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.volume_off_rounded,
                        color: AppColors.fog,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Music and sound effects are not part of this build yet. Volume controls will appear here when they are.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _Section(
                index: 4,
                title: 'Review tools',
                children: [
                  Text(
                    'For reviewing the art and writing. These are not part of the game.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SwitchRow(
                    title: 'Reveal everything',
                    subtitle: 'Opens every room, shows every item, person and clue, and lets you try every puzzle and conversation.',
                    value: services.preview.revealAll,
                    onChanged: (v) => services.preview.revealAll = v,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Preview the endings',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final e in services.content.story.endings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SpectralButton(
                        label: e.title,
                        icon: Icons.flag_rounded,
                        style: SpectralStyle.secondary,
                        expand: true,
                        onPressed: () =>
                            context.pushMist(EndingScreen(endingId: e.id)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.index,
    required this.title,
    required this.children,
  });

  final int index;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: FadeSlideIn(
        delay: Duration(milliseconds: 70 * index),
        child: ManorPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.goldLight,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const GoldDivider(),
              const SizedBox(height: AppSpacing.sm),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

class _SizeChoice extends StatelessWidget {
  const _SizeChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Text size $label${selected ? ', selected' : ''}',
      borderRadius: AppRadius.md,
      child: Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: selected ? AppColors.deepPurple : tokens.panelFill,
          border: Border.all(
            color: selected
                ? AppColors.goldLight
                : tokens.panelBorder.withValues(alpha: 0.5),
            width: selected ? 2.2 : 1,
          ),
          boxShadow: selected ? AppGlow.gold(0.6) : null,
        ),
        child: ExcludeSemantics(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: selected ? AppColors.goldLight : tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Sample extends StatelessWidget {
  const _Sample();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    return Semantics(
      label: 'Sample text. The door you came through has sealed itself.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppColors.midnight,
            border: Border.all(
              color: tokens.panelBorder.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            'The door you came through has sealed itself. Frost traces the keyhole.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
