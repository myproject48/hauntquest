import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/spectral_button.dart';

/// Credits and open-source licenses.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    return ManorScaffold(
      title: 'Credits',
      subtitle: 'HauntQuest AI',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          FadeSlideIn(
            child: ManorPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  section(
                    'The Whispering Manor',
                    'An original mystery. Every character, place, puzzle and line of dialogue was written for this game.',
                  ),
                  section(
                    'Art',
                    'All illustrations (rooms, objects, portraits, endings and the manor) are drawn in code with Flutter. No stock images or generated images are used.',
                  ),
                  section(
                    'Made with Kiro',
                    'Built for the Kiroween 2026 hackathon, Costume Contest, using Kiro specs, steering and agent workflows.',
                  ),
                  const GoldDivider(),
                  const SizedBox(height: AppSpacing.md),
                  SpectralButton(
                    label: 'Open-source licenses',
                    icon: Icons.description_outlined,
                    style: SpectralStyle.secondary,
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'HauntQuest AI',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
