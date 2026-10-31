import 'package:flutter/material.dart';

import '../../app/app.dart' show appRouteObserver;
import '../../app/app_scope.dart';
import '../../app/app_services.dart';
import '../../app/game_controller.dart';
import '../../content/definitions/room_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/painting/hotspot_art.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/spectral_button.dart';
import '../dialogue/dialogue_screen.dart';
import '../ending/ending_screen.dart';
import '../inventory/inventory_drawer.dart';
import '../inventory/inventory_screen.dart';
import '../journal/journal_screen.dart';
import '../guide/guide_panel.dart';
import 'room_sheets.dart';
import 'room_stage.dart';

/// Marker kind for an object, from the current game state.
HotspotKind hotspotKindOf(GameController game, HotspotDef h) {
  if (!game.canInteract(h)) return HotspotKind.locked;
  final puzzleId = h.puzzleId;
  if (puzzleId != null && !game.puzzleSolved(puzzleId)) {
    return HotspotKind.puzzle;
  }
  final choice = h.choiceId == null
      ? null
      : game.content.choiceById(h.choiceId!);
  if (choice != null && game.choiceAvailable(choice)) return HotspotKind.speak;
  if (!game.examined(h.id)) return HotspotKind.examine;
  return HotspotKind.done;
}

/// How an object looks after what the player has done to it.
HotspotLook hotspotLookOf(GameController game, HotspotDef h) => HotspotLook(
  taken: game.examined(h.id),
  solved: h.puzzleId != null && game.puzzleSolved(h.puzzleId!),
  activated: h.useRules.any(
    (r) => game.state.usedRuleKeys.contains('${h.id}|${r.itemId}'),
  ),
);

/// Mansion exploration: the illustrated room, a small HUD, and a panel with
/// the room's description, progress and exits.
///
/// Conversations triggered by an action, and the ending, open automatically
/// when this screen is on top.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with RouteAware {
  GameController? _game;
  ModalRoute<void>? _route;
  bool _presenting = false;
  final Set<String> _deferredConversations = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final game = AppScope.of(context).game;
    if (!identical(game, _game)) {
      _game?.removeListener(_onGameChanged);
      _game = game..addListener(_onGameChanged);
      _onGameChanged();
    }
    final route = ModalRoute.of(context);
    if (route != null && !identical(route, _route)) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  /// Back on top after a sheet, puzzle or other screen closed.
  @override
  void didPopNext() => _onGameChanged();

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _game?.removeListener(_onGameChanged);
    super.dispose();
  }

  /// Opens a waiting conversation or the ending once this screen is on top.
  void _onGameChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final game = _game;
      if (!mounted || game == null || _presenting) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      final ending = game.endingId;
      if (ending != null) {
        _presenting = true;
        await context.pushReplacementMist(
          EndingScreen(endingId: ending, fromPlay: true),
        );
        return;
      }
      final pending = game.state.pendingChoiceIds.where((id) {
        final choice = game.content.choiceById(id);
        return !_deferredConversations.contains(id) &&
            choice != null &&
            game.choiceAvailable(choice);
      }).firstOrNull;
      if (pending != null) {
        _presenting = true;
        await context.pushMist(DialogueScreen(choiceId: pending));
        if (!game.choiceResolved(pending)) _deferredConversations.add(pending);
        _presenting = false;
        // Leaving an unresolved scene must not immediately reopen it.
        if (game.choiceResolved(pending)) _onGameChanged();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showPauseSheet(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.midnight,
        body: ListenableBuilder(
          listenable: Listenable.merge([services.game, services.settings]),
          builder: (context, _) => _RoomView(services: services),
        ),
      ),
    );
  }
}

class _RoomView extends StatelessWidget {
  const _RoomView({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final game = services.game;
    final settings = services.settings.settings;
    final room = game.currentRoom;
    final reduce = MotionPolicy.reduceOf(context);
    final listMode =
        settings.roomListMode || MediaQuery.accessibleNavigationOf(context);

    final stage = AnimatedSwitcher(
      duration: reduce ? Duration.zero : AppMotion.slow,
      switchInCurve: AppMotion.enter,
      switchOutCurve: Curves.easeIn,
      child: RoomStage(
        key: ValueKey(room.id),
        room: room,
        kindOf: (h) => hotspotKindOf(game, h),
        lookOf: (h) => hotspotLookOf(game, h),
        showMarkers: settings.highlightInteractables,
        interactive: !listMode,
        // Status bar plus the HUD row (padding, 48 dp buttons, padding).
        hudClearance:
            MediaQuery.paddingOf(context).top +
            AppSpacing.sm * 2 +
            AppLayout.minTouch,
        onHotspot: (h) => showHotspotSheet(context, h),
      ),
    );

    final stageWithHud = Stack(
      fit: StackFit.expand,
      children: [
        stage,
        const SafeArea(bottom: false, child: _Hud()),
        Positioned(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: _FeedbackBanner(feedback: game.feedback),
        ),
      ],
    );

    final panel = _InfoPanel(
      room: room,
      services: services,
      listMode: listMode,
    );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 840 && box.maxWidth > box.maxHeight;
        if (wide) {
          return Row(
            children: [
              Expanded(child: stageWithHud),
              Container(
                width: 380,
                color: AppColors.midnight,
                child: SafeArea(left: false, child: panel),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: stageWithHud),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.44),
              child: Container(
                color: AppColors.midnight,
                child: SafeArea(top: false, child: panel),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud();

  @override
  Widget build(BuildContext context) {
    // Pinned to the top edge so the buttons never sit over the scene.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HudButton(
            icon: Icons.menu_rounded,
            label: 'Pause menu',
            onTap: () => showPauseSheet(context),
          ),
          const Spacer(),
          HudButton(
            icon: Icons.flare_rounded,
            label: 'The Whispering Guide',
            onTap: () => showWhisperingGuide(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          HudButton(
            icon: Icons.map_rounded,
            label: 'Manor map',
            onTap: () => showMapSheet(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          HudButton(
            icon: Icons.menu_book_rounded,
            label: 'Journal and evidence',
            onTap: () => context.pushMist(const JournalScreen()),
          ),
          const SizedBox(width: AppSpacing.sm),
          HudButton(
            icon: Icons.backpack_rounded,
            label: 'Inventory',
            onTap: () => context.pushMist(const InventoryScreen()),
          ),
        ],
      ),
    );
  }
}

/// A round HUD button with a gold ring, tooltip, and press feedback.
class HudButton extends StatelessWidget {
  const HudButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ManorTokens.of(context);
    return Tooltip(
      message: label,
      child: PressableScale(
        onTap: onTap,
        semanticLabel: label,
        borderRadius: 24,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.midnight.withValues(alpha: 0.85),
            border: Border.all(color: tokens.panelBorder, width: 1.5),
            boxShadow: AppGlow.gold(0.5),
          ),
          child: Icon(icon, color: AppColors.goldLight, size: 24),
        ),
      ),
    );
  }
}

/// A brief banner for discoveries ("Added to inventory", "A way opens").
/// Shows for a few seconds; never blocks taps on the scene.
class _FeedbackBanner extends StatefulWidget {
  const _FeedbackBanner({required this.feedback});

  final ValueNotifier<FeedbackNote?> feedback;

  @override
  State<_FeedbackBanner> createState() => _FeedbackBannerState();
}

class _FeedbackBannerState extends State<_FeedbackBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  FeedbackNote? _note;

  @override
  void initState() {
    super.initState();
    widget.feedback.addListener(_show);
  }

  void _show() {
    final note = widget.feedback.value;
    if (note == null || note.serial == _note?.serial) return;
    setState(() => _note = note);
    _life.forward(from: 0);
  }

  @override
  void dispose() {
    widget.feedback.removeListener(_show);
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    if (note == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final reduce = MotionPolicy.reduceOf(context);
    final (icon, color) = switch (note.kind) {
      FeedbackKind.item => (Icons.backpack_rounded, AppColors.goldLight),
      FeedbackKind.path => (
        Icons.door_front_door_rounded,
        AppColors.ghostGreen,
      ),
      FeedbackKind.truth => (Icons.auto_stories_rounded, AppColors.moonCyan),
      FeedbackKind.info => (Icons.info_outline_rounded, AppColors.moonCyan),
    };
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _life,
        builder: (context, child) {
          final v = _life.value;
          if (_life.isDismissed || v >= 1) return const SizedBox.shrink();
          // Fade in, hold, fade out. Reduced motion: no slide.
          final opacity = v < 0.08
              ? v / 0.08
              : (v > 0.88 ? (1 - v) / 0.12 : 1.0);
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, reduce ? 0 : 12 * (1 - opacity)),
              child: child,
            ),
          );
        },
        child: Semantics(
          liveRegion: true,
          label: note.text,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.midnight.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: color.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(note.text, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.room,
    required this.services,
    required this.listMode,
  });

  final RoomDef room;
  final AppServices services;
  final bool listMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = services.game;
    final explored = room.hotspots
        .where((h) => hotspotKindOf(game, h) == HotspotKind.done)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(room.name, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label:
                'Explored $explored of ${room.hotspots.length} objects here. '
                '${game.state.solvedPuzzleIds.length} of ${services.content.puzzles.length} puzzles solved.',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  _ProgressPips(done: explored, total: room.hotspots.length),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      '$explored/${room.hotspots.length} explored  ·  '
                      '${game.state.solvedPuzzleIds.length}/${services.content.puzzles.length} puzzles',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              room.description.resolve(game),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (!listMode)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Tap the marked objects in the scene.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          SpectralButton(
            label: 'Open Inventory Drawer',
            icon: Icons.backpack_rounded,
            style: SpectralStyle.secondary,
            expand: true,
            onPressed: () => showInventoryDrawer(context),
          ),
          if (listMode) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text('Objects', style: theme.textTheme.labelMedium),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final h in room.hotspots)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _ListRow(hotspot: h, kind: hotspotKindOf(game, h)),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text('Ways onward', style: theme.textTheme.labelMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final exit in room.exits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _ExitRow(exit: exit, services: services),
            ),
          const SizedBox(height: AppSpacing.sm),
          const _SessionChip(),
        ],
      ),
    );
  }
}

class _ProgressPips extends StatelessWidget {
  const _ProgressPips({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: AppMotion.medium,
            margin: const EdgeInsets.only(right: 3),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? AppColors.antiqueGold : Colors.transparent,
              border: Border.all(color: AppColors.antiqueGold, width: 1.2),
            ),
          ),
      ],
    );
  }
}

IconData _kindIcon(HotspotKind k) => switch (k) {
  HotspotKind.examine => Icons.search_rounded,
  HotspotKind.puzzle => Icons.extension_rounded,
  HotspotKind.speak => Icons.chat_bubble_rounded,
  HotspotKind.locked => Icons.lock_rounded,
  HotspotKind.done => Icons.check_rounded,
};

String _kindWord(HotspotKind k) => switch (k) {
  HotspotKind.examine => 'not yet examined',
  HotspotKind.puzzle => 'puzzle',
  HotspotKind.speak => 'someone to speak with',
  HotspotKind.locked => 'locked',
  HotspotKind.done => 'nothing new',
};

class _ListRow extends StatelessWidget {
  const _ListRow({required this.hotspot, required this.kind});

  final HotspotDef hotspot;
  final HotspotKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    return PressableScale(
      onTap: () => showHotspotSheet(context, hotspot),
      semanticLabel: '${hotspot.semanticLabel}, ${_kindWord(kind)}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: tokens.panelFill,
          border: Border.all(color: tokens.panelBorder.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              _kindIcon(kind),
              size: 20,
              color: kind == HotspotKind.done
                  ? AppColors.fog
                  : AppColors.moonCyan,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(hotspot.label, style: theme.textTheme.bodyMedium),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.fog),
          ],
        ),
      ),
    );
  }
}

class _ExitRow extends StatelessWidget {
  const _ExitRow({required this.exit, required this.services});

  final ExitDef exit;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    final game = services.game;
    final open = game.canUseExit(exit);
    final dest = services.content.roomById(exit.toRoomId);
    final known = game.isVisited(exit.toRoomId);
    final accent = dest == null ? AppColors.fog : moodColor(dest.mood);
    final destName = known || open ? (dest?.name ?? '') : 'Somewhere unknown';

    return PressableScale(
      onTap: () {
        final r = game.move(exit.id);
        final rejected = r.rejection;
        if (rejected != null) {
          showBlockedSheet(
            context,
            title: exit.label,
            message: rejected.message,
            hint: rejected.hint,
          );
        }
      },
      semanticLabel: '${exit.label}, ${open ? 'to $destName' : 'locked'}',
      semanticHint: open ? null : 'Double tap to see what is needed',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: open ? 0.22 : 0.06),
              tokens.panelFill,
            ],
          ),
          border: Border.all(
            color: open
                ? accent.withValues(alpha: 0.8)
                : tokens.panelBorder.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              open ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded,
              color: open ? accent : AppColors.fog,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exit.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    open ? destName : 'Locked',
                    style: theme.textTheme.bodySmall,
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

/// Explains automatic saving.
class _SessionChip extends StatelessWidget {
  const _SessionChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: PressableScale(
        onTap: () => showBuildInfo(context),
        semanticLabel: 'About progress in this build',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.midnight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.moonCyan.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.moonCyan,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  AppScope.of(context).game.lastSaveError != null
                      ? 'Autosave failed • tap for details'
                      : 'Progress saves automatically',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.moonCyan,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
