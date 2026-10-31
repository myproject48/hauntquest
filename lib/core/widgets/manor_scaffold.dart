import 'package:flutter/material.dart';

import '../design/manor_tokens.dart';
import '../design/tokens.dart';
import '../theme/app_colors.dart';
import 'fog_layer.dart';
import 'grain_overlay.dart';

/// Standard framed screen: midnight-to-violet gradient, faint fog, grain, a
/// header with an accessible back button, and width-limited content.
class ManorScaffold extends StatelessWidget {
  const ManorScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.showBack = true,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final bool showBack;

  /// Pass `double.infinity` for full-width content.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: tokens.highContrast
                  ? const LinearGradient(colors: [Colors.black, Colors.black])
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.midnight,
                        AppColors.navy,
                        AppColors.deepPurple,
                      ],
                      stops: [0, 0.6, 1],
                    ),
            ),
          ),
          if (!tokens.highContrast)
            const FogLayer(density: 0.6, verticalBias: 0.8, seed: 4),
          const GrainOverlay(vignette: 0.5),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  title: title,
                  subtitle: subtitle,
                  showBack: showBack,
                  actions: actions,
                  theme: theme,
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: body,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.showBack,
    required this.actions,
    required this.theme,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Back',
              iconSize: 26,
              constraints: const BoxConstraints(
                minWidth: AppLayout.minTouch,
                minHeight: AppLayout.minTouch,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.maybePop(context),
            )
          else
            const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.headlineSmall),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
