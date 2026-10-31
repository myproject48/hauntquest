import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../content/definitions/item_def.dart';
import '../../content/definitions/progress_view.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/item_icons.dart';
import '../../core/painting/paint_kit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/pressable_scale.dart';

/// Number of slots shown, filled or empty.
const int _slotCount = 12;

/// Items the player carries, with a close-up inspect view for the selected one.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.initialItemId});

  /// Item to inspect first, for example when opened from the evidence board.
  final String? initialItemId;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late String? _selected = widget.initialItemId;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.preview,
      builder: (context, _) {
        final preview = services.preview;
        final ids = preview.inventory;
        final selected = ids.contains(_selected)
            ? _selected
            : (ids.isEmpty ? null : ids.first);
        final item = selected == null
            ? null
            : services.content.itemById(selected);

        final detail = item == null
            ? const _EmptyDetail()
            : _ItemDetail(
                key: ValueKey(item.id),
                item: item,
                progress: preview,
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
              final strip = _SlotGrid(
                ids: ids,
                selected: selected,
                content: services.content.items,
                onSelect: (id) => setState(() => _selected = id),
                horizontal: !wide,
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
                        width: 340,
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
                  SizedBox(height: 108, child: strip),
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
    required this.content,
    required this.onSelect,
    required this.horizontal,
  });

  final List<String> ids;
  final String? selected;
  final List<ItemDef> content;
  final ValueChanged<String> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    ItemDef find(String id) => content.firstWhere((i) => i.id == id);
    final tiles = <Widget>[
      for (var i = 0; i < _slotCount; i++)
        i < ids.length
            ? FadeSlideIn(
                delay: Duration(milliseconds: 40 * i),
                child: _Slot(
                  item: find(ids[i]),
                  selected: ids[i] == selected,
                  onTap: () => onSelect(ids[i]),
                ),
              )
            : const _Slot(item: null, selected: false, onTap: null),
    ];

    if (horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => tiles[i],
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: tiles,
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ItemDef? item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    final filled = item != null;

    final tile = Container(
      width: 84,
      height: 92,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: filled
            ? tokens.panelFill
            : tokens.panelFill.withValues(alpha: 0.4),
        border: Border.all(
          color: selected
              ? AppColors.goldLight
              : tokens.panelBorder.withValues(alpha: filled ? 0.5 : 0.2),
          width: selected ? 2.4 : 1,
        ),
        boxShadow: selected ? AppGlow.gold(0.7) : null,
      ),
      child: filled
          ? ExcludeSemantics(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ItemIcon(
                        iconId: item!.iconId,
                        size: 46,
                        glow: selected,
                      ),
                    ),
                  ),
                  Text(
                    item!.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );

    if (!filled) {
      return ExcludeSemantics(child: tile);
    }
    return PressableScale(
      onTap: onTap,
      enforceMinSize: false,
      semanticLabel: '${item!.name}${selected ? ', selected' : ''}',
      semanticHint: 'Inspect',
      child: tile,
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
  const _ItemDetail({super.key, required this.item, required this.progress});

  final ItemDef item;
  final ProgressView progress;

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
            height: 210,
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
                  child: ItemIcon(iconId: item.iconId, size: 150),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
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
          delay: const Duration(milliseconds: 180),
          child: Text(
            blurb,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FadeSlideIn(
          delay: const Duration(milliseconds: 260),
          child: ManorPanel(
            tone: PanelTone.discovery,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLOSER LOOK',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.goldLight,
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
