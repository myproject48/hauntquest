import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/game_controller.dart';
import '../../content/definitions/puzzle_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/painting/item_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/spectral_button.dart';
import '../../domain/engine/game_engine.dart';
import '../../domain/engine/game_events.dart';
import '../../domain/puzzles/puzzle_evaluator.dart';
import '../../domain/audio/sound_cue.dart';
import '../room/room_sheets.dart' show HintLine;
import 'puzzle_controls.dart';
import 'inscription_control.dart';
import '../guide/guide_panel.dart';

/// A close-up of one puzzle. The player works the control and presses Check;
/// the game engine decides, records the attempt, and applies the rewards.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzleId});

  final String puzzleId;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  PuzzleInput? _input;
  EngineResult? _result;
  Verdict? _verdict;
  int _hintTier = 0;
  int _resetCount = 0;

  void _submit(GameController game, PuzzleDef def, PuzzleInput input) {
    final r = def.kind == PuzzleKind.useItem && input is UseItemInput
        ? game.useItem(input.itemId, def.hotspotId)
        : game.submitPuzzle(def.id, input);
    setState(() {
      _result = r;
      if (r.events.any((e) => e is PuzzleSolved)) {
        _verdict = Verdict.correct;
      } else if (r.events.any((e) => e is PuzzleAttempted)) {
        // The engine counted a wrong attempt; say how close it was.
        final v = input is UseItemInput && input.itemId != def.config['itemId']
            ? Verdict.incorrect
            : evaluatePuzzle(def, input);
        _verdict = v == Verdict.correct ? Verdict.incorrect : v;
      } else {
        _verdict = null;
      }
    });
  }

  void _reset(GameController game, PuzzleDef def) => setState(() {
    game.savePuzzleProgress(def.id, initialInputFor(def), _hintTier);
    _input = null;
    _verdict = null;
    _result = null;
    _resetCount++;
  });

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final content = services.content;
    final game = services.game;
    final def = content.puzzleById(widget.puzzleId)!;
    final room = content.roomById(def.roomId);

    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final theme = Theme.of(context);
        final access = game.puzzleAccess(def);
        final solvedEarlier =
            access == PuzzleAccess.solved && _verdict != Verdict.correct;
        final owned = game.inventory;
        final missing = [
          for (final id in def.requiresItems)
            if (!owned.contains(id)) content.itemById(id)!.name,
        ];
        final blocked =
            access == PuzzleAccess.locked ||
            access == PuzzleAccess.missingItems;
        final interactive = access == PuzzleAccess.available;
        final saved = game.state.puzzleProgress[def.id];
        final current = _input ?? saved?.input ?? initialInputFor(def);
        _hintTier = saved?.hintTier ?? 0;
        final attempts = game.state.puzzleAttempts[def.id] ?? 0;

        final key = ValueKey('${def.id}-$_resetCount');
        void changed(PuzzleInput v) {
          services.audio.play(SoundCue.interact);
          game.savePuzzleProgress(def.id, v, _hintTier);
          setState(() {
            _input = v;
            _verdict = null;
            _result = null;
          });
        }

        final Widget control = def.config['variant'] != null
            ? InscriptionControl(
                key: key,
                def: def,
                input: current,
                enabled: interactive,
                onChanged: changed,
              )
            : switch (def.kind) {
                PuzzleKind.sequence => SequenceControl(
                  initial: current,
                  key: key,
                  def: def,
                  enabled: interactive,
                  onChanged: changed,
                ),
                PuzzleKind.cipher => CipherControl(
                  initial: current,
                  key: key,
                  def: def,
                  enabled: interactive,
                  onChanged: changed,
                  onSubmit: () => _submit(game, def, _input ?? current),
                ),
                PuzzleKind.dial => DialControl(
                  initial: current,
                  key: key,
                  def: def,
                  enabled: interactive,
                  onChanged: changed,
                ),
                PuzzleKind.combine => CombineControl(
                  initial: current,
                  key: key,
                  def: def,
                  items: content.items,
                  owned: owned,
                  enabled: interactive,
                  onChanged: changed,
                ),
                PuzzleKind.useItem => UseItemControl(
                  key: key,
                  def: def,
                  item: content.itemById(def.config['itemId'] as String)!,
                  targetLabel:
                      content.hotspotById(def.hotspotId)?.label ?? 'Object',
                  owned: interactive && owned.contains(def.config['itemId']),
                  onUse: () => _submit(
                    game,
                    def,
                    UseItemInput(def.config['itemId'] as String),
                  ),
                ),
                PuzzleKind.clock => ClockControl(
                  initial: current,
                  key: key,
                  enabled: interactive,
                  onChanged: changed,
                ),
                PuzzleKind.gears => GearsControl(
                  initial: current,
                  key: key,
                  def: def,
                  enabled: interactive,
                  onChanged: changed,
                ),
              };

        final solvedNow = _verdict == Verdict.correct;

        return ManorScaffold(
          title: def.title,
          actions: [
            IconButton(
              tooltip: 'The Whispering Guide',
              icon: const Icon(Icons.flare_rounded),
              onPressed: () => showWhisperingGuide(context, puzzleId: def.id),
            ),
          ],
          subtitle: room?.name,
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              FadeSlideIn(
                child: ManorPanel(
                  child: Text(def.intro, style: theme.textTheme.bodyLarge),
                ),
              ),
              if (def.config['variant'] != null && def.clues.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ManorPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visible clues', style: theme.textTheme.labelMedium),
                      for (final clue in def.clues)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            clue.isHotspot
                                ? content
                                      .hotspotById(clue.sourceId)!
                                      .description
                                      .resolve(game.state)
                                : game.state.wasAcquired(clue.sourceId)
                                ? content
                                      .itemById(clue.sourceId)!
                                      .detail
                                      .resolve(game.state)
                                : 'Find ${content.itemById(clue.sourceId)!.name} to read this clue.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (solvedEarlier) ...[
                const SizedBox(height: AppSpacing.md),
                _SolvedPanel(def: def),
              ],
              if (blocked) ...[
                const SizedBox(height: AppSpacing.md),
                _BlockedPanel(
                  title: access == PuzzleAccess.missingItems
                      ? 'Something is missing'
                      : 'Not yet',
                  text: access == PuzzleAccess.missingItems
                      ? 'You need: ${missing.join(', ')}. You can look, but you cannot try it yet.'
                      : 'You cannot try this yet.',
                  hint: game.engine.hints.puzzle(def, game.state),
                ),
              ],
              if (!solvedEarlier) ...[
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: ManorPanel(
                    tone: PanelTone.strong,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: control,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!solvedNow)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (def.kind != PuzzleKind.useItem)
                        SpectralButton(
                          label: 'Check',
                          icon: Icons.check_rounded,
                          onPressed: interactive
                              ? () => _submit(game, def, current)
                              : null,
                        ),
                      SpectralButton(
                        label: 'Reset',
                        style: SpectralStyle.quiet,
                        onPressed: interactive ? () => _reset(game, def) : null,
                      ),
                    ],
                  ),
              ],
              AnimatedSwitcher(
                duration: MotionPolicy.reduceOf(context)
                    ? Duration.zero
                    : AppMotion.medium,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SizeTransition(
                    sizeFactor: anim,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
                child: _verdict == null
                    ? const SizedBox.shrink(key: ValueKey('none'))
                    : Padding(
                        key: ValueKey('$_verdict-$attempts'),
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: _VerdictPanel(
                          verdict: _verdict!,
                          text: _result?.message ?? '',
                          attempts: attempts,
                          result: _result,
                          game: game,
                        ),
                      ),
              ),
              if (solvedNow || solvedEarlier) ...[
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: SpectralButton(
                    label: 'Back to the room',
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
              ],
              if (!solvedNow && !solvedEarlier) ...[
                const SizedBox(height: AppSpacing.xl),
                _Hints(
                  hints: def.hints,
                  tier: _hintTier,
                  onReveal: () => game.revealPuzzleHint(def.id),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}

class _SolvedPanel extends StatelessWidget {
  const _SolvedPanel({required this.def});

  final PuzzleDef def;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ManorPanel(
      tone: PanelTone.discovery,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.ghostGreen),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solved',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.ghostGreen,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(def.successText, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedPanel extends StatelessWidget {
  const _BlockedPanel({
    required this.title,
    required this.text,
    required this.hint,
  });

  final String title;
  final String text;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ManorPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.fog),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(text, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          HintLine(text: hint),
        ],
      ),
    );
  }
}

class _VerdictPanel extends StatelessWidget {
  const _VerdictPanel({
    required this.verdict,
    required this.text,
    required this.attempts,
    required this.result,
    required this.game,
  });

  final Verdict verdict;
  final String text;
  final int attempts;
  final EngineResult? result;
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title) = switch (verdict) {
      Verdict.correct => (
        Icons.check_circle_rounded,
        AppColors.ghostGreen,
        'That is right',
      ),
      Verdict.partial => (Icons.tune_rounded, AppColors.goldLight, 'Almost'),
      Verdict.incorrect => (Icons.close_rounded, AppColors.danger, 'Not yet'),
    };
    final items = result?.itemsAcquired ?? const <String>[];
    final exits = result?.exitsOpened ?? const <String>[];
    final rewards = [
      for (final id in items) 'Found: ${game.content.itemById(id)?.name ?? id}',
      for (final id in exits)
        'A way opens: ${game.content.exitById(id)?.label ?? id}',
    ];

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $text ${rewards.join('. ')}',
      child: ExcludeSemantics(
        child: ManorPanel(
          tone: verdict == Verdict.correct
              ? PanelTone.discovery
              : PanelTone.strong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(color: color),
                    ),
                  ),
                  if (verdict != Verdict.correct)
                    Text('Attempt $attempts', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(text, style: theme.textTheme.bodyLarge),
              for (final id in items) ...[
                const SizedBox(height: AppSpacing.md),
                _Reward(
                  icon: ItemIcon(
                    iconId: game.content.itemById(id)!.iconId,
                    size: 44,
                  ),
                  text:
                      'Added to inventory: ${game.content.itemById(id)!.name}',
                ),
              ],
              for (final id in exits) ...[
                const SizedBox(height: AppSpacing.sm),
                _Reward(
                  icon: const Icon(
                    Icons.door_front_door_rounded,
                    color: AppColors.ghostGreen,
                    size: 32,
                  ),
                  text:
                      'A way opens: ${game.content.exitById(id)?.label ?? id}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = ManorTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppColors.midnight.withValues(alpha: 0.7),
        border: Border.all(color: tokens.panelBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(width: 48, child: Center(child: icon)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Hints extends StatelessWidget {
  const _Hints({
    required this.hints,
    required this.tier,
    required this.onReveal,
  });

  final List<String> hints;
  final int tier;
  final VoidCallback onReveal;

  static const _labels = ['A nudge', 'A clue', 'The way through'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = tier >= hints.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Hints', style: theme.textTheme.labelMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < tier; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: FadeSlideIn(
              child: Semantics(
                container: true,
                label:
                    'Hint ${i + 1} of ${hints.length}, ${_labels[i]}. ${hints[i]}',
                child: ExcludeSemantics(
                  child: ManorPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_labels[i].toUpperCase()}  ${i + 1}/${hints.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.goldLight,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(hints[i], style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Center(
          child: SpectralButton(
            label: done
                ? 'All hints shown'
                : (tier == 0 ? 'I need a hint' : 'Another hint'),
            icon: Icons.lightbulb_outline_rounded,
            style: SpectralStyle.secondary,
            onPressed: done ? null : onReveal,
          ),
        ),
      ],
    );
  }
}
