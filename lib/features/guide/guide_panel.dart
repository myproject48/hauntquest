import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/game_controller.dart';
import '../../app/guide/guide_controller.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/spectral_button.dart';
import '../../domain/guide/guide_models.dart';

Future<void> showWhisperingGuide(BuildContext context, {String? puzzleId}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.midnight.withValues(alpha: .8),
      sheetAnimationStyle: MotionPolicy.reduceOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: GuidePanel(puzzleId: puzzleId),
      ),
    );

/// Read-only companion. The sole game interaction is observing immutable
/// snapshots; hint progression and optional-provider consent stay local here.
class GuidePanel extends StatefulWidget {
  const GuidePanel({super.key, this.puzzleId});
  final String? puzzleId;
  @override
  State<GuidePanel> createState() => _GuidePanelState();
}

class _GuidePanelState extends State<GuidePanel> {
  GameController? _game;
  GuideController? _guide;
  GuideIntent _intent = GuideIntent.progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.of(context);
    if (identical(_game, services.game)) return;
    _game?.removeListener(_changed);
    _guide?.dispose();
    _game = services.game;
    _guide = GuideController(services.guide)..sync(_game!.state);
    if (widget.puzzleId case final id?) {
      _guide!.selectTopic('puzzle:$id', _game!.state);
    }
    _game!.addListener(_changed);
  }

  void _changed() => _guide!.sync(_game!.state);
  @override
  void dispose() {
    _game?.removeListener(_changed);
    _guide?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide!;
    final game = _game!;
    final theme = Theme.of(context);
    final tokens = ManorTokens.of(context);
    return AnimatedBuilder(
      animation: guide,
      builder: (context, _) {
        final topics = guide.service.offline
            .topics(game.state)
            .where((t) => t.intent == _intent)
            .toList();
        final selected = topics.where((t) => t.id == guide.topicId).firstOrNull;
        final reply = guide.reply;
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: tokens.highContrast
                  ? const LinearGradient(colors: [Colors.black, Colors.black])
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF162B35),
                        AppColors.midnight,
                        Color(0xFF171A30),
                      ],
                    ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: tokens.panelBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.moonCyan.withValues(alpha: .12),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 8, 4),
                  child: Row(
                    children: [
                      const ExcludeSemantics(
                        child: CustomPaint(
                          size: Size(44, 56),
                          painter: _WhisperSigil(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'The Whispering Guide',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close guide',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.antiqueGold),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'A lantern for the clues you have found.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          guide.service.aiConfigured
                              ? 'Offline guidance is always available. Optional AI assistance can select only from guidance you are allowed to see.'
                              : 'Offline, rule-based guidance. No AI service is connected.',
                          key: const ValueKey('guide-mode'),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final intent in GuideIntent.values)
                              ChoiceChip(
                                label: Text(
                                  intent == GuideIntent.progress
                                      ? 'A hint'
                                      : 'Understand evidence',
                                ),
                                selected: _intent == intent,
                                onSelected: (_) {
                                  final first = guide.service.offline
                                      .topics(game.state)
                                      .where((t) => t.intent == intent)
                                      .firstOrNull;
                                  if (first == null) return;
                                  setState(() => _intent = intent);
                                  guide.selectTopic(first.id, game.state);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (topics.isNotEmpty)
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'guide-topic-${_intent.name}-${guide.topicId}',
                            ),
                            initialValue: selected?.id,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _intent == GuideIntent.progress
                                  ? 'Focus'
                                  : 'Discovered evidence',
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              for (final topic in topics)
                                DropdownMenuItem(
                                  value: topic.id,
                                  child: Text(
                                    topic.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (id) {
                              if (id != null) guide.selectTopic(id, game.state);
                            },
                          ),
                        const SizedBox(height: 16),
                        if (reply == null)
                          ManorPanel(
                            child: Text(
                              _intent == GuideIntent.progress
                                  ? 'Ask for a subtle nudge first. You choose when to hear more; a direct hint may spell out an answer supported by your clues.'
                                  : 'Choose evidence you have discovered. The Guide can help connect known clues, without revealing unseen conversations or outcomes.',
                            ),
                          ),
                        if (reply != null)
                          ManorPanel(
                            tone: PanelTone.discovery,
                            child: Semantics(
                              liveRegion: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${reply.level.name.toUpperCase()} • ${reply.source == GuideSource.offline ? 'OFFLINE GUIDANCE' : 'AI-ASSISTED SELECTION'}',
                                    key: const ValueKey('guide-source'),
                                    style: theme.textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    reply.text,
                                    key: const ValueKey('guide-reply'),
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  if (reply.fallback != GuideFallback.none) ...[
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Optional assistance could not be used. The offline guide is still here.',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (guide.busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Optional assistance is considering the approved guidance. Your offline hint is ready.',
                            ),
                          ),
                        SpectralButton(
                          key: const ValueKey('ask-guide'),
                          expand: true,
                          label: guide.directShown
                              ? 'All three levels shown'
                              : switch (guide.revealedLevels) {
                                  0 => 'A subtle hint',
                                  1 => 'Guide me further',
                                  _ => 'Show a direct hint',
                                },
                          icon: Icons.flare_rounded,
                          onPressed:
                              guide.busy ||
                                  guide.directShown ||
                                  selected == null
                              ? null
                              : () => guide.ask(game.state),
                        ),
                        const SizedBox(height: 16),
                        if (guide.service.aiConfigured)
                          SwitchListTile.adaptive(
                            key: const ValueKey('guide-ai-opt-in'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Use optional AI-assisted selection',
                            ),
                            subtitle: Text(
                              'Off by default. Shares only the approved hint passages with ${guide.service.provider!.displayName}, not your save or full inventory.',
                            ),
                            value: guide.useAi,
                            onChanged: guide.setUseAi,
                          ),
                        Text(
                          'The Guide explains; you decide. It cannot solve puzzles, use items, change a choice, or grant a reward.',
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
      },
    );
  }
}

class _WhisperSigil extends CustomPainter {
  const _WhisperSigil();
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    final ring = Paint()
      ..color = AppColors.antiqueGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(i * math.pi / 3);
      c.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: s.width * .75,
          height: s.width * .4,
        ),
        ring,
      );
      c.restore();
    }
    c.drawCircle(
      center,
      6,
      Paint()
        ..color = AppColors.moonCyan
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    c.drawCircle(center, 3, Paint()..color = AppColors.parchment);
  }

  @override
  bool shouldRepaint(_WhisperSigil oldDelegate) => false;
}
