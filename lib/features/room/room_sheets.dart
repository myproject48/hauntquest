import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/game_controller.dart';
import '../../core/painting/item_icons.dart';
import '../../domain/engine/game_engine.dart';
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

/// Taps on an object land here: the player looks at it (which may reveal or
/// hand over something), then picks from what makes sense right now.
Future<void> showHotspotSheet(BuildContext context, HotspotDef hotspot) {
  final game = AppScope.of(context).game;
  final first = game.examine(hotspot.id);
  return _showSheet<void>(
    context,
    (sheetContext) => _HotspotSheet(
      hotspot: hotspot,
      game: game,
      initial: first,
      roomContext: context,
    ),
  );
}

class _HotspotSheet extends StatefulWidget {
  const _HotspotSheet({
    required this.hotspot,
    required this.game,
    required this.initial,
    required this.roomContext,
  });

  final HotspotDef hotspot;
  final GameController game;
  final EngineResult initial;

  /// The room screen, used to open full screens after the sheet closes.
  final BuildContext roomContext;

  @override
  State<_HotspotSheet> createState() => _HotspotSheetState();
}

class _HotspotSheetState extends State<_HotspotSheet> {
  late EngineResult _last = widget.initial;
  bool _choosingItem = false;

  GameController get _game => widget.game;

  void _use(String itemId) {
    setState(() {
      _last = _game.useItem(itemId, widget.hotspot.id);
      _choosingItem = false;
    });
  }

  void _open(Widget screen) {
    Navigator.pop(context);
    widget.roomContext.pushMist(screen);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        final theme = Theme.of(context);
        final h = widget.hotspot;
        final content = _game.content;
        final rejected = _last.rejection;
        final locked = !_game.canInteract(h);
        final puzzle = h.puzzleId == null
            ? null
            : content.puzzleById(h.puzzleId!);
        final access = puzzle == null ? null : _game.puzzleAccess(puzzle);
        final choice = h.choiceId == null
            ? null
            : content.choiceById(h.choiceId!);
        final canSpeak = choice != null && _game.choiceAvailable(choice);
        final found = _last.itemsAcquired;
        final opened = _last.exitsOpened;

        return _SheetFrame(
          title: h.label,
          tone: found.isNotEmpty || opened.isNotEmpty
              ? PanelTone.discovery
              : PanelTone.strong,
          leading: Icon(
            locked ? Icons.lock_rounded : Icons.visibility_rounded,
            color: locked ? AppColors.fog : AppColors.goldLight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  _last.message ?? '',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (rejected?.hint != null) ...[
                const SizedBox(height: AppSpacing.md),
                HintLine(text: rejected!.hint!),
              ],
              for (final id in found) ...[
                const SizedBox(height: AppSpacing.md),
                _FoundRow(
                  name: content.itemById(id)!.name,
                  iconId: content.itemById(id)!.iconId,
                ),
              ],
              for (final id in opened) ...[
                const SizedBox(height: AppSpacing.sm),
                _OpenedRow(
                  text: 'A way opens: ${content.exitById(id)?.label ?? id}',
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (!locked && puzzle != null && access != PuzzleAccess.solved)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SpectralButton(
                    label: 'Look closer: ${puzzle.title}',
                    icon: Icons.extension_rounded,
                    expand: true,
                    onPressed: () => _open(PuzzleScreen(puzzleId: puzzle.id)),
                  ),
                ),
              if (canSpeak)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SpectralButton(
                    label: 'Speak',
                    icon: Icons.chat_bubble_rounded,
                    expand: true,
                    onPressed: () => _open(DialogueScreen(choiceId: choice.id)),
                  ),
                ),
              if (!locked && _game.inventory.isNotEmpty && !_choosingItem)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SpectralButton(
                    label: 'Use an item',
                    icon: Icons.back_hand_rounded,
                    style: SpectralStyle.secondary,
                    expand: true,
                    onPressed: () => setState(() => _choosingItem = true),
                  ),
                ),
              if (_choosingItem) ...[
                Text(
                  'Use which item on the ${h.label.toLowerCase()}?',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final id in _game.inventory)
                      _ItemChoice(
                        name: content.itemById(id)!.name,
                        iconId: content.itemById(id)!.iconId,
                        onTap: () => _use(id),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              SpectralButton(
                label: _choosingItem ? 'Cancel' : 'Close',
                style: SpectralStyle.quiet,
                expand: true,
                onPressed: _choosingItem
                    ? () => setState(() => _choosingItem = false)
                    : () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A gentle nudge for a blocked action, marked with a lightbulb icon.
class HintLine extends StatelessWidget {
  const HintLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Hint. $text',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.midnight,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.moonCyan.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.moonCyan,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoundRow extends StatelessWidget {
  const _FoundRow({required this.name, required this.iconId});

  final String name;
  final String iconId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Found $name. Added to your inventory.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppColors.deepPurple.withValues(alpha: 0.6),
            border: Border.all(color: AppColors.goldLight),
            boxShadow: AppGlow.gold(0.7),
          ),
          child: Row(
            children: [
              ItemIcon(iconId: iconId, size: 52),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FOUND',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.goldLight,
                      ),
                    ),
                    Text(name, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              const Icon(Icons.backpack_rounded, color: AppColors.goldLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenedRow extends StatelessWidget {
  const _OpenedRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.door_front_door_rounded, color: AppColors.ghostGreen),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _ItemChoice extends StatelessWidget {
  const _ItemChoice({
    required this.name,
    required this.iconId,
    required this.onTap,
  });

  final String name;
  final String iconId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Use $name',
      enforceMinSize: false,
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: tokens.panelFill,
          border: Border.all(color: tokens.panelBorder.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            ItemIcon(iconId: iconId, size: 44, glow: false),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textPrimary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains a blocked action (for example a locked door) with a nudge.
Future<void> showBlockedSheet(
  BuildContext context, {
  required String title,
  required String message,
  String? hint,
}) {
  return _showSheet<void>(context, (sheetContext) {
    final theme = Theme.of(sheetContext);
    return _SheetFrame(
      title: title,
      leading: const Icon(Icons.lock_rounded, color: AppColors.fog),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(message, style: theme.textTheme.bodyLarge),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.md),
            HintLine(text: hint),
          ],
          const SizedBox(height: AppSpacing.lg),
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

/// Every room, where the player is, and which neighbours are reachable.
Future<void> showMapSheet(BuildContext context) {
  final game = AppScope.of(context).game;
  return _showSheet<void>(context, (sheetContext) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => _SheetFrame(
        title: 'Manor map',
        leading: const Icon(Icons.map_rounded, color: AppColors.goldLight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final room in game.content.rooms)
              _MapRow(room: room, game: game, sheetContext: sheetContext),
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
    required this.game,
    required this.sheetContext,
  });

  final RoomDef room;
  final GameController game;
  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    final here = room.id == game.currentRoomId;
    final visited = game.isVisited(room.id);
    final reachable =
        game.reviewMode ||
        game.currentRoom.exits.any(
          (e) => e.toRoomId == room.id && game.canUseExit(e),
        );
    final canGo = here || reachable;
    final puzzlesHere = game.content.puzzles.where((p) => p.roomId == room.id);
    final solvedCount = puzzlesHere
        .where((p) => game.puzzleSolved(p.id))
        .length;

    final status = here
        ? 'You are here'
        : reachable
        ? 'Open path from here'
        : visited
        ? 'Visited, not next door'
        : 'Not found yet';
    final accent = moodColor(room.mood);
    final detail = visited && puzzlesHere.isNotEmpty
        ? '  ·  $solvedCount/${puzzlesHere.length} puzzles'
        : '';
    final name = visited || here ? room.name : 'Unknown room';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PressableScale(
        onTap: canGo
            ? () {
                if (game.moveTo(room.id)) Navigator.pop(sheetContext);
              }
            : null,
        semanticLabel: '$name. $status$detail',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      Text('$status$detail', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  here
                      ? Icons.place_rounded
                      : (canGo
                            ? Icons.chevron_right_rounded
                            : Icons.lock_outline_rounded),
                  color: here ? AppColors.goldLight : AppColors.fog,
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
Color moodColor(String mood) => switch (mood) {
  'moonCyan' => AppColors.moonCyan,
  'ghostGreen' => AppColors.ghostGreen,
  'antiqueGold' => AppColors.antiqueGold,
  'violetMist' => const Color(0xFFB48CFF),
  _ => AppColors.fog,
};

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
              Navigator.of(context).pushAndRemoveUntil(
                MistPageRoute<void>(builder: (_) => const MainMenuScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your journey is saved automatically. Use Continue on the title screen to return.',
            textAlign: TextAlign.center,
            style: Theme.of(sheetContext).textTheme.bodySmall,
          ),
        ],
      ),
    );
  });
}

/// Explains how progress is kept in this build.
Future<void> showBuildInfo(BuildContext context) {
  final game = AppScope.of(context).game;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: ManorTokens.of(dialogContext).panelBorder),
      ),
      title: const Text('About your progress'),
      content: SingleChildScrollView(
        child: Text(
          game.lastSaveError != null
              ? 'Autosave could not finish. Your previous complete save remains available. Check device storage and use Retry autosave on the Continue screen.'
              : 'Your discoveries, inventory, puzzle inputs, hints and solved states are saved on this device. '
                    'Use Continue to resume after closing the app.\n\n'
                    'Original soundscapes and effects are available in Settings. Echo puzzles also include written clues and visual pulses.',
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
