import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/game_controller.dart';
import '../../content/definitions/item_def.dart';
import '../../content/definitions/room_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../domain/engine/game_events.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/item_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/spectral_button.dart';
import 'discovery_dialog.dart';
import 'inventory_card.dart';

/// Opens the tactile, animated inventory drawer as a bottom sheet.
Future<void> showInventoryDrawer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.midnight.withValues(alpha: 0.72),
    sheetAnimationStyle: MotionPolicy.reduceOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (sheetContext) => const InventoryDrawerSheet(),
  );
}

/// The tactile, animated inventory drawer interface.
class InventoryDrawerSheet extends StatefulWidget {
  const InventoryDrawerSheet({super.key, this.initialItemId});

  final String? initialItemId;

  @override
  State<InventoryDrawerSheet> createState() => _InventoryDrawerSheetState();
}

class _InventoryDrawerSheetState extends State<InventoryDrawerSheet> {
  late String? _selectedId = widget.initialItemId;
  String? _combineSourceId;
  String? _feedbackText;
  bool _showingRoomTargets = false;

  void _onSlotTapped(String itemId, GameController game) {
    if (_combineSourceId != null) {
      if (_combineSourceId == itemId) {
        // Tapped same item: cancel combination mode.
        setState(() {
          _combineSourceId = null;
          _feedbackText = null;
        });
        return;
      }
      _executeCombination(_combineSourceId!, itemId, game);
    } else {
      setState(() {
        _selectedId = itemId;
        _feedbackText = null;
        _showingRoomTargets = false;
      });
    }
  }

  void _executeCombination(String itemA, String itemB, GameController game) {
    final result = game.combineItems(itemA, itemB);
    setState(() {
      _combineSourceId = null;
      _showingRoomTargets = false;
    });

    if (result.ok) {
      final combinedEvent = result.events.whereType<ItemCombined>().firstOrNull;
      final newId = combinedEvent?.resultItemId;
      final newItem = newId != null ? game.content.itemById(newId) : null;

      setState(() {
        _selectedId = newId;
        _feedbackText = result.message;
      });

      if (newItem != null && mounted) {
        showDiscoveryDialog(
          context,
          item: newItem,
          message: result.message ?? 'A new item has been fashioned.',
          onInspect: () => _openInspectModal(context, newItem, game),
        );
      }
    } else {
      setState(() {
        _feedbackText = result.rejection?.message ?? 'Cannot combine those items.';
      });
    }
  }

  void _openInspectModal(BuildContext context, ItemDef item, GameController game) {
    game.inspectItem(item.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.midnight.withValues(alpha: 0.8),
      builder: (_) => _InspectBottomSheet(item: item, game: game),
    );
  }

  void _useOnHotspot(String itemId, HotspotDef hotspot, GameController game) {
    final result = game.useItem(itemId, hotspot.id);
    setState(() {
      _showingRoomTargets = false;
      _feedbackText = result.message ??
          (result.ok
              ? 'Used ${game.content.itemById(itemId)?.name} on ${hotspot.label}.'
              : result.rejection?.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);

    return ListenableBuilder(
      listenable: services.game,
      builder: (context, _) {
        final game = services.game;
        final ids = game.inventory;
        final selectedId = ids.contains(_selectedId)
            ? _selectedId
            : (ids.isEmpty ? null : ids.first);
        final selectedItem = selectedId == null
            ? null
            : services.content.itemById(selectedId);
        final combineSourceItem = _combineSourceId == null
            ? null
            : services.content.itemById(_combineSourceId!);

        final currentRoom = game.currentRoom;
        final roomHotspots = currentRoom.hotspots;

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
              maxHeight: 680,
            ),
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.midnight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                border: Border.all(color: tokens.panelBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tactile Ornate Drawer Handle
                      _DrawerGrip(onTap: () => Navigator.pop(context)),

                      // Header Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.backpack_rounded,
                              color: AppColors.goldLight,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Semantics(
                              header: true,
                              child: Text(
                                'INVENTORY',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.goldLight,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.deepPurple,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: AppColors.antiqueGold.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                '${ids.length} items',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.paper,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.fog,
                              ),
                              tooltip: 'Close inventory drawer',
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                    const GoldDivider(),

                    // Combination Mode Active Banner
                    if (_combineSourceId != null && combineSourceItem != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        color: AppColors.deepPurple.withValues(alpha: 0.6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_fix_high_rounded,
                              color: AppColors.moonCyan,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Combining ${combineSourceItem.name}. Tap second item.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.moonCyan,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _combineSourceId = null;
                                _feedbackText = null;
                              }),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),

                    // Helpful Feedback / Error Banner
                    if (_feedbackText != null)
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          color: AppColors.navy,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.antiqueGold,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _feedbackText!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.paper,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                tooltip: 'Dismiss message',
                                onPressed: () => setState(() => _feedbackText = null),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Items Strip / Grid
                    SizedBox(
                      height: 122,
                      child: ids.isEmpty
                          ? Center(
                              child: Text(
                                'Your pockets are empty.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.fog,
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              itemCount: math.max(ids.length, 6),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: AppSpacing.sm),
                              itemBuilder: (context, i) {
                                if (i < ids.length) {
                                  final id = ids[i];
                                  final item = services.content.itemById(id);
                                  return InventoryCard(
                                    item: item,
                                    selected: id == selectedId,
                                    isCombineSource: id == _combineSourceId,
                                    combineSourceItemName: _combineSourceId != null
                                        ? combineSourceItem?.name
                                        : null,
                                    onTap: () => _onSlotTapped(id, game),
                                  );
                                }
                                return const InventoryCard(
                                  item: null,
                                  selected: false,
                                  onTap: null,
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Selected Item Action Dock
                    if (selectedItem != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: ManorPanel(
                          tone: PanelTone.normal,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  ItemIcon(
                                    iconId: selectedItem.iconId,
                                    size: 38,
                                    glow: true,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedItem.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: AppColors.goldLight,
                                          ),
                                        ),
                                        Text(
                                          selectedItem.description
                                              .resolve(game),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),

                              // Room Hotspot Use Targets List
                              if (_showingRoomTargets) ...[
                                Text(
                                  'Use ${selectedItem.name} on:',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppColors.goldLight,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    for (final h in roomHotspots)
                                      ActionChip(
                                        avatar: const Icon(
                                          Icons.touch_app_rounded,
                                          size: 16,
                                          color: AppColors.goldLight,
                                        ),
                                        label: Text(h.label),
                                        onPressed: () => _useOnHotspot(
                                          selectedItem.id,
                                          h,
                                          game,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: SpectralButton(
                                      label: 'Inspect',
                                      icon: Icons.search_rounded,
                                      style: SpectralStyle.secondary,
                                      onPressed: () => _openInspectModal(
                                        context,
                                        selectedItem,
                                        game,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: SpectralButton(
                                      label: 'Combine',
                                      icon: Icons.auto_fix_high_rounded,
                                      style: _combineSourceId == selectedItem.id
                                          ? SpectralStyle.primary
                                          : SpectralStyle.secondary,
                                      onPressed: () {
                                        setState(() {
                                          _combineSourceId = selectedItem.id;
                                          _showingRoomTargets = false;
                                          _feedbackText =
                                              'Select another item to combine with ${selectedItem.name}.';
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (roomHotspots.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                SpectralButton(
                                  label: _showingRoomTargets
                                      ? 'Cancel'
                                      : 'Use in Room',
                                  icon: Icons.back_hand_rounded,
                                  style: SpectralStyle.primary,
                                  onPressed: () {
                                    setState(() {
                                      _showingRoomTargets =
                                          !_showingRoomTargets;
                                      _combineSourceId = null;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  }
}

class _DrawerGrip extends StatelessWidget {
  const _DrawerGrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Inventory drawer handle. Double tap to close drawer.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // The visible grip is a thin bar; the tap area is a full 48x48 dp
        // (it was about 48x21 dp before).
        child: SizedBox(
          width: AppLayout.minTouch * 2,
          height: AppLayout.minTouch,
          child: Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.antiqueGold.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectBottomSheet extends StatelessWidget {
  const _InspectBottomSheet({required this.item, required this.game});

  final ItemDef item;
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = item.detail.resolve(game);
    final blurb = item.description.resolve(game);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.contentMaxWidth,
          maxHeight: 620,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.midnight,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            border: Border.all(color: AppColors.goldLight, width: 2),
            boxShadow: AppGlow.gold(0.8),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.antiqueGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: ItemIcon(iconId: item.iconId, size: 110, glow: true),
                ),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  header: true,
                  child: Text(
                    item.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.paper,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  blurb,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.moonCyan,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ManorPanel(
                  tone: PanelTone.discovery,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CLOSER LOOK',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.goldLight,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        detail,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SpectralButton(
                  label: 'Close Inspection',
                  style: SpectralStyle.quiet,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
