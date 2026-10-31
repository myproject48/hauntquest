import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/preview_controller.dart';
import '../../content/definitions/room_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/spectral_button.dart';
import '../dialogue/dialogue_screen.dart';
import '../menu/main_menu_screen.dart';
import '../puzzle/puzzle_screen.dart';
import '../settings/settings_screen.dart';

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.midnight.withValues(alpha: 0.7),
    sheetAnimationStyle: MotionPolicy.reduceOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: builder,
  );
}

/// Frame shared by all bottom sheets: drag handle, panel, width limit.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.child,
    this.tone = PanelTone.strong,
    this.leading,
  });

  final String title;
  final Widget child;
  final PanelTone tone;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: ManorPanel(
            tone: tone,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title, style: theme.textTheme.titleLarge),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const GoldDivider(),
                  const SizedBox(height: AppSpacing.sm),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows what the player finds when they look at an object.
Future<void> showExamineSheet(BuildContext context, HotspotDef hotspot) {
  final services = AppScope.of(context);
  final preview = services.preview;
  final puzzle = hotspot.puzzleId == null
      ? null
      : services.content.puzzleById(hotspot.puzzleId!);
  final choice = hotspot.choiceId == null
      ? null
      : services.content.choiceById(hotspot.choiceId!);

  return _showSheet<void>(context, (sheetContext) {
    final theme = Theme.of(sheetContext);
    final allowed = preview.canInteract(hotspot);
    final text = allowed
        ? hotspot.description.resolve(preview)
        : (hotspot.lockedText ?? 'You cannot do that yet.');

    return _SheetFrame(
      title: hotspot.label,
      tone: allowed ? PanelTone.discovery : PanelTone.strong,
      leading: Icon(
        allowed ? Icons.visibility_rounded : Icons.lock_rounded,
        color: allowed ? AppColors.goldLight : AppColors.fog,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(text, style: theme.textTheme.bodyLarge),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (allowed && puzzle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SpectralButton(
                label: 'Look closer: ${puzzle.title}',
                icon: Icons.extension_rounded,
                expand: true,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.pushMist(PuzzleScreen(puzzleId: puzzle.id));
                },
              ),
            ),
          if (allowed && choice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SpectralButton(
                label: 'Speak',
                icon: Icons.chat_bubble_rounded,
                expand: true,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.pushMist(DialogueScreen(choiceId: choice.id));
                },
              ),
            ),
          SpectralButton(
            label: 'Close',
            style: SpectralStyle.quiet,
            expand: true,
            onPressed: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    );
  });
}

/// Room list with where the player is and what is reachable.
Future<void> showMapSheet(BuildContext context) {
  final preview = AppScope.of(context).preview;
  return _showSheet<void>(context, (sheetContext) {
    return ListenableBuilder(
      listenable: preview,
      builder: (context, _) => _SheetFrame(
        title: 'Manor map',
        leading: const Icon(Icons.map_rounded, color: AppColors.goldLight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final room in preview.content.rooms)
              _MapRow(room: room, preview: preview, sheetContext: sheetContext),
            const SizedBox(height: AppSpacing.xs),
            SpectralButton(
              label: 'Close',
              style: SpectralStyle.quiet,
              expand: true,
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  });
}

class _MapRow extends StatelessWidget {
  const _MapRow({
    required this.room,
    required this.preview,
    required this.sheetContext,
  });

  final RoomDef room;
  final PreviewController preview;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    final here = room.id == preview.currentRoomId;
    final visited = preview.isVisited(room.id);
    final reachable =
        preview.revealAll ||
        preview.currentRoom.exits.any(
          (e) => e.toRoomId == room.id && e.initiallyOpen,
        );
    final canGo = here || reachable;

    final status = here
        ? 'You are here'
        : reachable
        ? 'Open path'
        : visited
        ? 'Visited'
        : 'Not found yet';
    final accent = _moodColor(room.mood);

    void go() {
      if (here) {
        Navigator.pop(sheetContext);
      } else if (preview.moveTo(room.id)) {
        Navigator.pop(sheetContext);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PressableScale(
        onTap: canGo ? go : null,
        semanticLabel: '${room.name}. $status',
        semanticHint: canGo ? null : 'Not reachable from here',
        child: Opacity(
          opacity: canGo || visited ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: tokens.panelFill,
              border: Border.all(
                color: here
                    ? AppColors.goldLight
                    : tokens.panelBorder.withValues(alpha: 0.4),
                width: here ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accent, accent.withValues(alpha: 0.25)],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visited || here ? room.name : 'Unknown room',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(status, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    here
                        ? Icons.place_rounded
                        : (canGo
                              ? Icons.chevron_right_rounded
                              : Icons.lock_outline_rounded),
                    color: here ? AppColors.goldLight : AppColors.fog,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps a room's mood token name (from content) to its color.
Color _moodColor(String mood) => switch (mood) {
  'moonCyan' => AppColors.moonCyan,
  'ghostGreen' => AppColors.ghostGreen,
  'antiqueGold' => AppColors.antiqueGold,
  'violetMist' => const Color(0xFFB48CFF),
  _ => AppColors.fog,
};

/// Public so the room screen can tint its exit buttons the same way.
Color moodColor(String mood) => _moodColor(mood);

/// Pause menu opened from the HUD or the back gesture.
Future<void> showPauseSheet(BuildContext context) {
  return _showSheet<void>(context, (sheetContext) {
    return _SheetFrame(
      title: 'Paused',
      leading: const Icon(
        Icons.pause_circle_outline_rounded,
        color: AppColors.goldLight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SpectralButton(
            label: 'Resume',
            icon: Icons.play_arrow_rounded,
            expand: true,
            onPressed: () => Navigator.pop(sheetContext),
          ),
          const SizedBox(height: AppSpacing.sm),
          SpectralButton(
            label: 'Settings',
            icon: Icons.tune_rounded,
            style: SpectralStyle.secondary,
            expand: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              context.pushMist(const SettingsScreen());
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SpectralButton(
            label: 'Back to title',
            icon: Icons.home_rounded,
            style: SpectralStyle.secondary,
            expand: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              _confirmQuit(context);
            },
          ),
        ],
      ),
    );
  });
}

Future<void> _confirmQuit(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: ManorTokens.of(dialogContext).panelBorder),
      ),
      title: const Text('Leave the manor?'),
      content: const Text(
        'Progress is not saved yet. You can begin again at any time.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  if (leave == true && context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MistPageRoute<void>(builder: (_) => const MainMenuScreen()),
      (_) => false,
    );
  }
}

/// Explains what the preview build does and does not include.
Future<void> showPreviewInfo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: ManorTokens.of(dialogContext).panelBorder),
      ),
      title: const Text('Playable preview'),
      content: const SingleChildScrollView(
        child: Text(
          'You can walk the open rooms, read every description, try the puzzles to see whether an answer is right, and read the dialogue.\n\n'
          'Not built yet: collecting items, opening new paths, remembering your choices, and saving. Review mode in Settings reveals every room and clue so the whole manor can be seen.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
