import 'package:flutter/material.dart';

import '../../content/definitions/item_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/item_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pressable_scale.dart';

/// A tactile item card used in inventory drawers and grids.
class InventoryCard extends StatelessWidget {
  const InventoryCard({
    super.key,
    required this.item,
    required this.selected,
    this.isCombineSource = false,
    this.combineSourceItemName,
    required this.onTap,
  });

  final ItemDef? item;
  final bool selected;

  /// True if this item was chosen as the first item in combine mode.
  final bool isCombineSource;

  /// Name of the primary item when this card is a combination target.
  final String? combineSourceItemName;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    final filled = item != null;

    final borderColor = isCombineSource
        ? AppColors.moonCyan
        : selected
            ? AppColors.goldLight
            : tokens.panelBorder.withValues(alpha: filled ? 0.6 : 0.25);

    final borderWidth = (isCombineSource || selected) ? 2.4 : 1.0;

    final card = Container(
      width: 90,
      height: 104,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: filled
            ? (selected
                ? AppColors.deepPurple.withValues(alpha: 0.85)
                : tokens.panelFill)
            : tokens.panelFill.withValues(alpha: 0.35),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isCombineSource
            ? [
                BoxShadow(
                  color: AppColors.moonCyan.withValues(alpha: 0.6),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : (selected ? AppGlow.gold(0.8) : null),
      ),
      child: filled
          ? Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ItemIcon(
                          iconId: item!.iconId,
                          size: 52,
                          glow: selected || isCombineSource,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item!.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: (selected || isCombineSource)
                            ? AppColors.goldLight
                            : tokens.textPrimary,
                        fontWeight: (selected || isCombineSource)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                if (isCombineSource)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.moonCyan,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'COMBINE',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppColors.midnight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (selected)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.goldLight,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.antiqueGold,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.panelBorder.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
            ),
    );

    if (!filled) {
      return ExcludeSemantics(child: card);
    }

    String semanticLabel = item!.name;
    if (isCombineSource) {
      semanticLabel += ', source item for combination';
    } else if (combineSourceItemName != null) {
      semanticLabel += ', tap to combine with $combineSourceItemName';
    } else if (selected) {
      semanticLabel += ', selected';
    }

    return PressableScale(
      onTap: onTap,
      enforceMinSize: false,
      semanticLabel: semanticLabel,
      semanticHint: combineSourceItemName != null ? 'Combine' : 'Select item',
      child: card,
    );
  }
}
