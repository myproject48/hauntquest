import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../content/definitions/item_def.dart';
import '../../content/definitions/puzzle_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/tokens.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/painting/character_portraits.dart';
import '../../core/painting/item_icons.dart';
import '../../core/painting/paint_kit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/pressable_scale.dart';
import '../inventory/inventory_screen.dart';

/// The investigator's journal: an evidence board of found clues joined by
/// thread, and a page of the people met so far.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: ManorScaffold(
        title: 'Journal',
        subtitle: 'Evidence and people',
        maxWidth: double.infinity,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TabBar(
                indicatorColor: AppColors.goldLight,
                indicatorWeight: 3,
                labelColor: AppColors.goldLight,
                unselectedLabelColor: ManorTokens.of(context).textMuted,
                labelStyle: theme.textTheme.labelLarge,
                dividerColor: ManorTokens.of(context).panelBorder
                    .withValues(alpha: 0.3),
                tabs: const [
                  Tab(text: 'EVIDENCE', height: 48),
                  Tab(text: 'PEOPLE', height: 48),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(children: [_EvidenceTab(), _PeopleTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- evidence

class _EvidenceTab extends StatelessWidget {
  const _EvidenceTab();

  /// Pairs of items that belong to the same puzzle: they get a thread.
  static Set<(String, String)> _links(List<PuzzleDef> puzzles) {
    final out = <(String, String)>{};
    for (final p in puzzles) {
      final ids = <String>{
        ...p.requiresItems,
        for (final c in p.clues)
          if (c.isItem) c.sourceId,
      }.toList()..sort();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          out.add((ids[i], ids[j]));
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final content = services.content;
    return ListenableBuilder(
      listenable: services.preview,
      builder: (context, _) {
        final owned = services.preview.inventory.toSet();
        return LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 900
                ? 5
                : (box.maxWidth >= 600 ? 4 : 3);
            final cell = math.min(box.maxWidth, 1100) / cols;
            final cardW = cell * 0.84;
            final cardH = cardW * 1.16;
            const caseH = 132.0;
            final items = content.items;
            final rows = (items.length / cols).ceil();
            final boardW = cell * cols;
            final boardH = caseH + 48 + rows * (cardH + 22);

            Offset pos(int i) {
              final r = i ~/ cols;
              final c = i % cols;
              final jx = ((i * 53) % 9 - 4).toDouble();
              final jy = ((i * 31) % 9 - 4).toDouble();
              return Offset(
                c * cell + (cell - cardW) / 2 + jx,
                caseH + 44 + r * (cardH + 22) + jy,
              );
            }

            final caseRect = Rect.fromLTWH(
              (boardW - math.min(boardW - 32, 420)) / 2,
              16,
              math.min(boardW - 32, 420),
              caseH,
            );
            final centers = <String, Offset>{
              for (final (i, item) in items.indexed)
                item.id: pos(i) + Offset(cardW / 2, 6),
            };
            final links = _links(content.puzzles);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: boardW,
                  height: boardH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            painter: _BoardPainter(
                              casePin: caseRect.bottomCenter.translate(0, -6),
                              pins: {
                                for (final e in centers.entries)
                                  if (owned.contains(e.key)) e.key: e.value,
                              },
                              links: links,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: caseRect,
                        child: FadeSlideIn(
                          child: _CaseCard(premise: content.story.premise),
                        ),
                      ),
                      for (final (i, item) in items.indexed)
                        Positioned(
                          left: pos(i).dx,
                          top: pos(i).dy,
                          width: cardW,
                          height: cardH,
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: 60 + i * 50),
                            child: Transform.rotate(
                              angle: ((i * 37) % 7 - 3) * 0.014,
                              child: _EvidenceCard(
                                item: item,
                                found: owned.contains(item.id),
                                onTap: () => context.pushMist(
                                  InventoryScreen(initialItemId: item.id),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.premise});

  final String premise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'The case. $premise',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: AppColors.paper,
            boxShadow: AppGlow.depth(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THE CASE',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.goldDeep,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  premise,
                  overflow: TextOverflow.fade,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.wood,
                    fontSize: 14,
                    height: 1.3,
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

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.item,
    required this.found,
    required this.onTap,
  });

  final ItemDef item;
  final bool found;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: found
            ? AppColors.paper
            : AppColors.midnight.withValues(alpha: 0.5),
        border: found
            ? null
            : Border.all(color: tokens.panelBorder.withValues(alpha: 0.3)),
        boxShadow: found ? AppGlow.depth() : null,
      ),
      child: ExcludeSemantics(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ItemIcon(
                  iconId: item.iconId,
                  size: 62,
                  glow: false,
                  dimmed: !found,
                ),
              ),
            ),
            Text(
              found ? item.name : 'Not found',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: found ? AppColors.wood : tokens.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );

    if (!found) {
      return Semantics(label: 'Evidence not found yet', child: card);
    }
    return PressableScale(
      onTap: onTap,
      enforceMinSize: false,
      semanticLabel: '${item.name}, evidence',
      semanticHint: 'Inspect',
      child: card,
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.casePin,
    required this.pins,
    required this.links,
  });

  final Offset casePin;
  final Map<String, Offset> pins;
  final Set<(String, String)> links;

  @override
  void paint(Canvas canvas, Size size) {
    // Dark felt board with a gold frame.
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.lg),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16204A), Color(0xFF1B1440)],
        ).createShader(Offset.zero & size),
    );
    // Felt weave.
    final weave = Kit.stroke(Colors.white.withValues(alpha: 0.025), 1);
    for (var y = 6.0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), weave);
    }
    canvas.drawRRect(
      r,
      Kit.stroke(AppColors.antiqueGold.withValues(alpha: 0.7), 3),
    );

    // Threads: faint from the case to each clue, bold between related clues.
    for (final p in pins.values) {
      _thread(
        canvas,
        casePin,
        p,
        AppColors.goldDeep.withValues(alpha: 0.55),
        1.4,
      );
    }
    for (final (a, b) in links) {
      final pa = pins[a];
      final pb = pins[b];
      if (pa != null && pb != null) {
        _thread(canvas, pa, pb, AppColors.danger.withValues(alpha: 0.85), 2.2);
      }
    }
    // Pins.
    _pin(canvas, casePin);
    for (final p in pins.values) {
      _pin(canvas, p);
    }
  }

  void _thread(Canvas c, Offset a, Offset b, Color color, double w) {
    final mid = Offset((a.dx + b.dx) / 2, math.max(a.dy, b.dy) + 14);
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy),
      Kit.stroke(color, w),
    );
  }

  void _pin(Canvas c, Offset p) {
    c.drawCircle(p.translate(1.5, 2.5), 5, Kit.fill(const Color(0x66000000)));
    c.drawCircle(p, 5, Kit.fill(AppColors.antiqueGold));
    c.drawCircle(p.translate(-1.5, -1.5), 1.8, Kit.fill(AppColors.goldLight));
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.casePin != casePin ||
      old.pins.length != pins.length ||
      old.links.length != links.length;
}

// ------------------------------------------------------------------ people

class _PeopleTab extends StatelessWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: services.preview,
      builder: (context, _) {
        final known = services.preview.knownCharacterIds;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.contentMaxWidth,
                ),
                child: Column(
                  children: [
                    for (final (i, c)
                        in services.content.story.characters.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: FadeSlideIn(
                          delay: Duration(milliseconds: 70 * i),
                          child: Semantics(
                            container: true,
                            label: known.contains(c.id)
                                ? '${c.name}, ${c.role}. ${c.voice}'
                                : 'Unknown voice. You have not met this person yet.',
                            child: ExcludeSemantics(
                              child: ManorPanel(
                                tone: known.contains(c.id)
                                    ? PanelTone.normal
                                    : PanelTone.strong,
                                child: Row(
                                  children: [
                                    CharacterPortrait(
                                      characterId: c.id,
                                      size: 84,
                                      unknown: !known.contains(c.id),
                                    ),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            known.contains(c.id)
                                                ? c.name
                                                : 'Unknown voice',
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            known.contains(c.id) ? c.role : 'You have not met this person yet.',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          if (known.contains(c.id)) ...[
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Text(
                                              c.voice,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
