import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_services.dart';
import '../../content/definitions/room_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pressable_scale.dart';
import '../inventory/inventory_screen.dart';
import '../journal/journal_screen.dart';
import 'room_sheets.dart';
import 'room_stage.dart';

/// Mansion exploration: the illustrated room, a small HUD, and a panel with
/// the room's description and exits.
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key});

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
          listenable: Listenable.merge([services.preview, services.settings]),
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
    final preview = services.preview;
    final settings = services.settings.settings;
    final room = preview.currentRoom;
    final reduce = MotionPolicy.reduceOf(context);
    final listMode =
        settings.roomListMode || MediaQuery.accessibleNavigationOf(context);

    HotspotKind kindOf(HotspotDef h) {
      if (!preview.canInteract(h)) return HotspotKind.locked;
      if (h.puzzleId != null) return HotspotKind.puzzle;
      if (h.choiceId != null) return HotspotKind.speak;
      return HotspotKind.examine;
    }

    final stage = AnimatedSwitcher(
      duration: reduce ? Duration.zero : AppMotion.slow,
      switchInCurve: AppMotion.enter,
      child: RoomStage(
        key: ValueKey(room.id),
        room: room,
        kindOf: kindOf,
        showMarkers: settings.highlightInteractables,
        interactive: !listMode,
        onHotspot: (h) => showExamineSheet(context, h),
      ),
    );

    final stageWithHud = Stack(
      fit: StackFit.expand,
      children: [
        stage,
        SafeArea(bottom: false, child: _Hud(roomName: room.name)),
      ],
    );

    final panel = _InfoPanel(
      room: room,
      services: services,
      kindOf: kindOf,
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
  const _Hud({required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              HudButton(
                icon: Icons.menu_rounded,
                label: 'Pause menu',
                onTap: () => showPauseSheet(context),
              ),
              const Spacer(),
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
        ],
      ),
    );
  }
}

/// Small chip that explains what the preview build includes. Sits in the info
/// panel so it never covers the scene.
class _PreviewChip extends StatelessWidget {
  const _PreviewChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: PressableScale(
        onTap: () => showPreviewInfo(context),
        semanticLabel: 'Playable preview. What is included?',
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
                  'Preview: what is included?',
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

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.room,
    required this.services,
    required this.kindOf,
    required this.listMode,
  });

  final RoomDef room;
  final AppServices services;
  final HotspotKind Function(HotspotDef) kindOf;
  final bool listMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = services.preview;

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
          const SizedBox(height: AppSpacing.sm),
          const _PreviewChip(),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              room.description.resolve(preview),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (!listMode)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Tap the marked objects in the scene to examine them.',
                style: theme.textTheme.bodySmall,
              ),
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
                child: _ListRow(
                  icon: switch (kindOf(h)) {
                    HotspotKind.examine => Icons.search_rounded,
                    HotspotKind.puzzle => Icons.extension_rounded,
                    HotspotKind.speak => Icons.chat_bubble_rounded,
                    HotspotKind.locked => Icons.lock_rounded,
                  },
                  title: h.label,
                  semantic:
                      '${h.semanticLabel}${kindOf(h) == HotspotKind.locked ? ', locked' : ''}',
                  onTap: () => showExamineSheet(context, h),
                ),
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
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.title,
    required this.semantic,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    return PressableScale(
      onTap: onTap,
      semanticLabel: semantic,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: tokens.panelFill,
          border: Border.all(color: tokens.panelBorder.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 20, color: AppColors.moonCyan),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ExcludeSemantics(
                child: Text(title, style: theme.textTheme.bodyMedium),
              ),
            ),
            const ExcludeSemantics(
              child: Icon(Icons.chevron_right_rounded, color: AppColors.fog),
            ),
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
    final preview = services.preview;
    final open = preview.canUseExit(exit);
    final dest = services.content.roomById(exit.toRoomId);
    final accent = dest == null ? AppColors.fog : moodColor(dest.mood);

    return PressableScale(
      onTap: () {
        if (open) {
          preview.moveTo(exit.toRoomId);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(exit.lockedText ?? 'The way is blocked.')),
            );
        }
      },
      semanticLabel: '${exit.label}${open ? '' : ', locked'}',
      semanticHint: open
          ? 'Go to ${dest?.name ?? 'the next room'}'
          : exit.lockedText,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
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
            ExcludeSemantics(
              child: Icon(
                open ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded,
                color: open ? accent : AppColors.fog,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ExcludeSemantics(
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
                      open ? (dest?.name ?? '') : 'Locked',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
