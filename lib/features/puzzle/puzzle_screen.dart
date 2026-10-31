import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../content/definitions/puzzle_def.dart';
import '../../core/design/manor_tokens.dart';
import '../../core/design/motion_policy.dart';
import '../../core/design/tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/manor_panel.dart';
import '../../core/widgets/manor_scaffold.dart';
import '../../core/widgets/spectral_button.dart';
import '../../domain/puzzles/puzzle_evaluator.dart';
import 'puzzle_controls.dart';

/// A close-up of one puzzle. The player works the control, presses Check, and
/// the pure evaluator says whether it is right, nearly right, or wrong.
///
/// Solving does not yet unlock anything: there is no game state to change.
/// The screen says so plainly instead of pretending.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzleId});

  final String puzzleId;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  PuzzleInput? _input;
  Verdict? _verdict;
  int _attempts = 0;
  int _hintTier = 0;
  int _resetCount = 0;

  void _submit(PuzzleDef def, PuzzleInput input) {
    setState(() {
      _verdict = evaluatePuzzle(def, input);
      _attempts++;
    });
  }

  void _reset() => setState(() {
    _input = null;
    _verdict = null;
    _resetCount++;
  });

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final content = services.content;
    final def = content.puzzleById(widget.puzzleId)!;
    final room = content.roomById(def.roomId);

    return ListenableBuilder(
      listenable: services.preview,
      builder: (context, _) {
        final preview = services.preview;
        final owned = preview.inventory;
        final missing = [
          for (final id in def.requiresItems)
            if (!owned.contains(id)) content.itemById(id)!.name,
        ];
        // Item puzzles handle their own missing-item message.
        final blocksCheck =
            missing.isNotEmpty &&
            def.kind != PuzzleKind.useItem &&
            def.kind != PuzzleKind.combine;
        final current = _input ?? initialInputFor(def);
        final theme = Theme.of(context);

        Widget control;
        final key = ValueKey('${def.id}-$_resetCount');
        switch (def.kind) {
          case PuzzleKind.sequence:
            control = SequenceControl(
              key: key,
              def: def,
              enabled: !blocksCheck,
              onChanged: (v) => setState(() => _input = v),
            );
          case PuzzleKind.cipher:
            control = CipherControl(
              key: key,
              def: def,
              enabled: !blocksCheck,
              onChanged: (v) => setState(() => _input = v),
              onSubmit: () => _submit(def, _input ?? current),
            );
          case PuzzleKind.dial:
            control = DialControl(
              key: key,
              def: def,
              enabled: !blocksCheck,
              onChanged: (v) => setState(() => _input = v),
            );
          case PuzzleKind.combine:
            control = CombineControl(
              key: key,
              def: def,
              items: content.items,
              owned: owned,
              enabled: true,
              onChanged: (v) => setState(() => _input = v),
            );
          case PuzzleKind.useItem:
            final itemId = def.config['itemId'] as String;
            control = UseItemControl(
              key: key,
              def: def,
              item: content.itemById(itemId)!,
              targetLabel:
                  content.hotspotById(def.hotspotId)?.label ?? 'Object',
              owned: owned.contains(itemId),
              onUse: () => _submit(def, UseItemInput(itemId)),
            );
          case PuzzleKind.clock:
            control = ClockControl(
              key: key,
              enabled: !blocksCheck,
              onChanged: (v) => setState(() => _input = v),
            );
          case PuzzleKind.gears:
            control = GearsControl(
              key: key,
              def: def,
              enabled: !blocksCheck,
              onChanged: (v) => setState(() => _input = v),
            );
        }

        final showCheck = def.kind != PuzzleKind.useItem;

        return ManorScaffold(
          title: def.title,
          subtitle: room?.name,
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              FadeSlideIn(
                child: ManorPanel(
                  child: Text(def.intro, style: theme.textTheme.bodyLarge),
                ),
              ),
              if (blocksCheck) ...[
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: _MissingPanel(names: missing),
                ),
              ],
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
              if (showCheck)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SpectralButton(
                      label: 'Check',
                      icon: Icons.check_rounded,
                      onPressed: blocksCheck
                          ? null
                          : () => _submit(def, current),
                      disabledReason: blocksCheck
                          ? 'You still need: ${missing.join(', ')}.'
                          : null,
                    ),
                    SpectralButton(
                      label: 'Reset',
                      style: SpectralStyle.quiet,
                      onPressed: _reset,
                    ),
                  ],
                )
              else
                Center(
                  child: SpectralButton(
                    label: 'Reset',
                    style: SpectralStyle.quiet,
                    onPressed: _reset,
                  ),
                ),
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
                        key: ValueKey('$_verdict-$_attempts'),
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: _VerdictPanel(
                          def: def,
                          verdict: _verdict!,
                          attempts: _attempts,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Hints(
                hints: def.hints,
                tier: _hintTier,
                onReveal: () => setState(() => _hintTier++),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}

class _MissingPanel extends StatelessWidget {
  const _MissingPanel({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: ManorPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.fog),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Something is missing',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'You need: ${names.join(', ')}. You can look, but you cannot try it yet.',
                    style: theme.textTheme.bodyMedium,
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

class _VerdictPanel extends StatelessWidget {
  const _VerdictPanel({
    required this.def,
    required this.verdict,
    required this.attempts,
  });

  final PuzzleDef def;
  final Verdict verdict;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title, text) = switch (verdict) {
      Verdict.correct => (
        Icons.check_circle_rounded,
        AppColors.ghostGreen,
        'That is right',
        def.successText,
      ),
      Verdict.partial => (
        Icons.tune_rounded,
        AppColors.goldLight,
        'Almost',
        def.partialText ?? 'You are close. Something is still not quite right.',
      ),
      Verdict.incorrect => (
        Icons.close_rounded,
        AppColors.danger,
        'Not yet',
        def.incorrectText,
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $text',
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
                  Text('Attempt $attempts', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(text, style: theme.textTheme.bodyLarge),
              if (verdict == Verdict.correct) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: AppColors.midnight.withValues(alpha: 0.7),
                    border: Border.all(
                      color: ManorTokens.of(context).panelBorder
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.moonCyan,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Preview: the answer is checked, but rewards such as new items and open doors are not applied yet.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
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
