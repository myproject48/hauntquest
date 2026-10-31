import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/game_controller.dart';
import '../../app/game_store.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/spectral_button.dart';
import '../../core/theme/app_colors.dart';
import '../menu/new_game_action.dart';
import '../ending/ending_screen.dart';
import '../room/room_screen.dart';

/// The Continue screen: shows the autosaved journey (or recovery notes when
/// a save could not be restored) and resumes it. One journey is kept at a
/// time; there are no manual slots.
class SaveSlotsScreen extends StatelessWidget {
  const SaveSlotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = AppScope.of(context).game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final hasJourney = game.inProgress || game.endingId != null;
        return ManorScaffold(
          title: 'Continue',
          subtitle: 'Saved journeys',
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Autosave', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              if (game.lastSaveError != null)
                const ManorPanel(
                  child: Text(
                    'Autosave could not finish. Your previous complete save is preserved. Free some device storage and try again.',
                  ),
                ),
              if ({
                SaveRecovery.corrupt,
                SaveRecovery.unsupported,
                SaveRecovery.recoveredBackup,
              }.contains(game.saveRecovery))
                ManorPanel(
                  child: Text(switch (game.saveRecovery) {
                    SaveRecovery.recoveredBackup => 'A damaged save was recovered from the last valid backup.',
                    SaveRecovery.unsupported => 'This save belongs to a newer version. It has been preserved. Update the app to resume it, or confirm New Game to replace it.',
                    _ => 'The saved journey could not be restored safely. Confirm New Game to replace it. Your existing save data has been preserved.',
                  }),
                ),
              if (game.lastSaveError != null)
                TextButton(
                  onPressed: game.isSaving ? null : game.retrySave,
                  child: const Text('Retry autosave'),
                ),
              if (hasJourney) ...[
                FadeSlideIn(child: _CurrentJourney(game: game)),
                const SizedBox(height: AppSpacing.lg),
              ],
              FadeSlideIn(
                child: ManorPanel(
                  tone: hasJourney ? PanelTone.normal : PanelTone.discovery,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          hasJourney
                              ? 'Your journey is saved'
                              : 'No saved journeys yet',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your journey saves automatically after every action, '
                        'including unfinished puzzles. The manor keeps one '
                        'journey at a time.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SpectralButton(
                        label: 'Begin Quest',
                        icon: Icons.auto_stories_rounded,
                        onPressed: () => beginNewGame(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The automatically saved active journey.
class _CurrentJourney extends StatelessWidget {
  const _CurrentJourney({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = game.state;
    final content = game.content;
    return ManorPanel(
      tone: PanelTone.discovery,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.endingId == null ? 'JOURNEY IN PROGRESS' : 'JOURNEY COMPLETE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.goldLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              s.endingId == null
                  ? game.currentRoom.name
                  : content.endingById(s.endingId!)!.title,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${s.visitedRoomIds.length}/${content.rooms.length} rooms  ·  '
            '${s.solvedPuzzleIds.length}/${content.puzzles.length} puzzles  ·  '
            '${s.inventory.length} items carried',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          SpectralButton(
            label: s.endingId == null ? 'Resume' : 'Read your ending',
            icon: Icons.play_arrow_rounded,
            expand: true,
            onPressed: () => context.pushReplacementMist(
              s.endingId == null
                  ? const RoomScreen()
                  : EndingScreen(endingId: s.endingId!, fromPlay: true),
            ),
          ),
        ],
      ),
    );
  }
}
