import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/game_controller.dart';
import '../../content/definitions/item_def.dart';
import '../../content/definitions/progress_view.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/item_icons.dart';
import '../../domain/engine/game_events.dart';
import '../../core/painting/paint_kit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/spectral_button.dart';
import 'discovery_dialog.dart';
import 'inventory_card.dart';

/// Number of slots shown, filled or empty.
const int _slotCount = 12;

/// Items the player carries, with a close-up inspect view, combine interactions,
/// and tactile mobile-friendly item slots.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.initialItemId});

  /// Item to inspect first, for example when opened from the evidence board.
  final String? initialItemId;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late String? _selected = widget.initialItemId;
  String? _combineSourceId;
  String? _feedbackText;

  void _onSlotTapped(String id, GameController game) {
    if (_combineSourceId != null) {
      if (_combineSourceId == id) {
        setState(() {
          _combineSourceId = null;
          _feedbackText = null;
        });
        return;
      }
      _executeCombination(_combineSourceId!, id, game);
    } else {
      setState(() {
        _selected = id;
        _feedbackText = null;
      });
    }
  }

  void _executeCombination(String itemA, String itemB, GameController game) {
    final result = game.combineItems(itemA, itemB);
    setState(() => _combineSourceId = null);

    if (result.ok) {
      final combinedEvent = result.events.whereType<ItemCombined>().firstOrNull;
      final newId = combinedEvent?.resultItemId;
      final newItem = newId != null ? game.content.itemById(newId) : null;

      setState(() {
        _selected = newId;
        _feedbackText = result.message;
      });

      if (newItem != null && mounted) {
        showDiscoveryDialog(
          context,
          item: newItem,
          message: result.message ?? 'A new item has been forged.',
          onInspect: () => game.inspectItem(newItem.id),
        );
      }
    } else {
      setState(() {
        _feedbackText = result.rejection?.message ?? 'Cannot combine those items.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: services.game,
      builder: (context, _) {
        final game = services.game;
        final ids = game.inventory;
        final selected = ids.contains(_selected)
            ? _selected
            : (ids.isEmpty ? null : ids.first);
        final item = selected == null
            ? null
            : services.content.itemById(selected);
        final combineSourceItem = _combineSourceId == null
            ? null
            : services.content.itemById(_combineSourceId!);

        final detail = item == null
            ? const _EmptyDetail()
            : _ItemDetail(
                key: ValueKey(item.id),
                item: item,
                progress: game,
                isCombining: _combineSourceId == item.id,
                onCombinePressed: () {
                  setState(() {
                    _combineSourceId = item.id;
                    _feedbackText =
                        'Select another item from your inventory to combine with ${item.name}.';
                  });
                },
                onShown: () => game.inspectItem(item.id),
              );

        return ManorScaffold(
          title: 'Inventory',
          subtitle: ids.length == 1
              ? '1 item carried'
              : '${ids.length} items carried',
          maxWidth: double.infinity,
          body: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 720;
              final strip = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Combine mode or feedback banner
                  if (_combineSourceId != null && combineSourceItem != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.deepPurple,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.moonCyan),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_fix_high_rounded,
                              color: AppColors.moonCyan,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Combining ${combineSourceItem.name}. Tap second item.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.moonCyan,
                                  fontWeight: FontWeight.bold,
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
                    ),
                  if (_feedbackText != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.antiqueGold),
                          ),
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
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                tooltip: 'Dismiss message',
                                onPressed: () =>
                                    setState(() => _feedbackText = null),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _SlotGrid(
                    ids: ids,
                    selected: selected,
                    combineSourceId: _combineSourceId,
                    combineSourceItemName: combineSourceItem?.name,
                    content: services.content.items,
                    onSelect: (id) => _onSlotTapped(id, game),
                    horizontal: !wide,
                  ),
                ],
              );

              if (wide) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(child: detail),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(child: strip),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppLayout.contentMaxWidth,
                          ),
                          child: detail,
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: strip,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.ids,
    required this.selected,
    this.combineSourceId,
    this.combineSourceItemName,
    required this.content,
    required this.onSelect,
    required this.horizontal,
  });

  final List<String> ids;
  final String? selected;
  final String? combineSourceId;
  final String? combineSourceItemName;
  final List<ItemDef> content;
  final ValueChanged<String> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    ItemDef find(String id) => content.firstWhere((i) => i.id == id);
    final count = math.max(ids.length, _slotCount);

    final tiles = <Widget>[
      for (var i = 0; i < count; i++)
        i < ids.length
            ? FadeSlideIn(
                delay: Duration(milliseconds: 30 * i),
                child: InventoryCard(
                  item: find(ids[i]),
                  selected: ids[i] == selected,
                  isCombineSource: ids[i] == combineSourceId,
                  combineSourceItemName: ids[i] != combineSourceId
                      ? combineSourceItemName
                      : null,
                  onTap: () => onSelect(ids[i]),
                ),
              )
            : const InventoryCard(item: null, selected: false, onTap: null),
    ];

    if (horizontal) {
      return SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          itemCount: tiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, i) => tiles[i],
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: tiles,
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ManorPanel(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const ItemIcon(iconId: 'page', size: 72, glow: false, dimmed: true),
            const SizedBox(height: AppSpacing.md),
            Text('Your pockets are empty.', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Things you find in the manor appear here.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Large inspect view: the item floats in a pool of light above its pedestal.
class _ItemDetail extends StatefulWidget {
  const _ItemDetail({
    super.key,
    required this.item,
    required this.progress,
    required this.isCombining,
    required this.onCombinePressed,
    this.onShown,
  });

  final ItemDef item;
  final ProgressView progress;
  final bool isCombining;
  final VoidCallback onCombinePressed;

  /// Called once after the item is first shown, to record that it was inspected.
  final VoidCallback? onShown;

  @override
  State<_ItemDetail> createState() => _ItemDetailState();
}

class _ItemDetailState extends State<_ItemDetail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceOf(context)) {
      _bob.stop();
      _bob.value = 0.5;
    } else if (!_bob.isAnimating) {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final detail = item.detail.resolve(widget.progress);
    final blurb = item.description.resolve(widget.progress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(painter: _PedestalPainter()),
                  ),
                ),
                AnimatedBuilder(
                  animation: _bob,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      -6 + 12 * Curves.easeInOut.transform(_bob.value),
                    ),
                    child: child,
                  ),
                  child: ItemIcon(iconId: item.iconId, size: 140),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FadeSlideIn(
          delay: const Duration(milliseconds: 100),
          child: Semantics(
            header: true,
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FadeSlideIn(
          delay: const Duration(milliseconds: 150),
          child: Text(
            blurb,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.moonCyan,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Combine action button
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: SpectralButton(
                label: widget.isCombining ? 'Selecting Second Item...' : 'Combine with...',
                icon: Icons.auto_fix_high_rounded,
                style: widget.isCombining ? SpectralStyle.primary : SpectralStyle.secondary,
                expand: true,
                onPressed: widget.onCombinePressed,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        FadeSlideIn(
          delay: const Duration(milliseconds: 250),
          child: ManorPanel(
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
                Text(detail, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PedestalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Cone of light from above.
    Kit.lightShaft(
      canvas,
      Offset(cx, 0),
      size.width * 0.12,
      Offset(cx, size.height * 0.86),
      size.width * 0.6,
      AppColors.moonCyan,
      0.22,
    );
    // Pedestal disc.
    final base = Rect.fromCenter(
      center: Offset(cx, size.height * 0.88),
      width: size.width * 0.5,
      height: size.height * 0.14,
    );
    Kit.glow(
      canvas,
      base.center,
      size.width * 0.34,
      AppColors.antiqueGold,
      0.3,
    );
    canvas.drawOval(base, Kit.fill(const Color(0xFF1B1440)));
    canvas.drawOval(base, Kit.stroke(AppColors.antiqueGold, 2));
    canvas.drawOval(base.deflate(10), Kit.stroke(AppColors.violetMist, 1.4));
  }

  @override
  bool shouldRepaint(_PedestalPainter old) => false;
}
